export RecipeInflation, filter_state!, vortexassim

struct RecipeInflation <: InflationType
    "Parameters"
    p::Array{Float64,1}
end

# Filtering function to bound the strength of the vortices and sources
function filter_state!(x, config::VortexConfig)
	@inbounds for j=1:config.Nv
		# Ensure that vortices stay above the x axis
		x[3*j-1] = clamp(x[3*j-1], 1e-2, Inf)
		# Ensure that the circulation remains positive
    	x[3*j] = clamp(x[3*j], 0.0, Inf)
	end
    return x
end

# This function apply additive inflation to the state components only,
# not the measurements, X is an Array{Float64,2} or a view of it
function (ϵ::RecipeInflation)(X, Ny, Nx, config::VortexConfig)
	ϵX, ϵΓ = ϵ.p
	Nv = config.Nv
	@assert Nx == 3*Nv
	for col in eachcol(X)
		if config.Nv > 0
			for i in 1:Nv
				col[Ny + 3*(i-1) + 1: Ny + 3*(i-1) + 2] .+= ϵX*randn(2)
				col[Ny + 3*i] += ϵΓ*randn()
			end
		end
	end
end

function (ϵ::RecipeInflation)(x::AbstractVector{Float64}, config::VortexConfig)
	ϵX, ϵΓ = ϵ.p
	Nv = config.Nv
	Nx = size(x, 1)

	@assert Nx == 3*Nv
	for i=1:Nv
		x[3*(i-1) + 1:3*(i-1) + 2] .+= ϵX*randn(2)
		x[3*(i-1) + 3] += ϵΓ*randn()
	end
end

# Create a function to perform the sequential assimilation for any sequential filter SeqFilter
function vortexassim(algo::SeqFilter, X, tspan::Tuple{S,S}, config::VortexConfig, data::SyntheticData; P::Parallel = serial) where {S<:Real}

	# Define the additive Inflation
	ϵX = config.ϵX
	ϵΓ = config.ϵΓ
	β = config.β
	ϵY = config.ϵY

	Ny = size(config.ss,1)

	ϵx = RecipeInflation([ϵX; ϵΓ])
	ϵmul = MultiplicativeInflation(β)
	# Set different times
	Δtobs = algo.Δtobs
	Δtdyn = algo.Δtdyn
	t0, tf = tspan
	step = ceil(Int, Δtobs/Δtdyn)

	n0 = ceil(Int64, t0/Δtobs) + 1
	J = (tf-t0)/Δtobs
	Acycle = n0:n0+J-1

	# Array dimensions
	Nypx, Ne = size(X)
	Nx = Nypx - Ny
	ystar = zeros(Ny)

	cachevels = allocate_velocity(state_to_lagrange(X[Ny+1:Ny+Nx,1], config))

	h(x, t) = measure_state(x, t, config)
	press_itp = CubicSplineInterpolation((LinRange(real(config.ss[1]), real(config.ss[end]), length(config.ss)),
	                                   t0:data.Δt:tf), data.yt, extrapolation_bc =  Line())

	yt(t) = press_itp(real.(config.ss), t)
	Xf = Array{Float64,2}[]
	push!(Xf, copy(state(X, Ny, Nx)))

	Xa = Array{Float64,2}[]
	push!(Xa, copy(state(X, Ny, Nx)))

	# Run particle filter
	@showprogress for i=1:length(Acycle)
	   # Forecast step
	   @inbounds for j=1:step
		   tj = t0+(i-1)*Δtobs+(j-1)*Δtdyn
		   X, _ = vortex(X, tj, Ny, Nx, cachevels, config)
	   end

	   push!(Xf, deepcopy(state(X, Ny, Nx)))

	   # Get real measurement
	   ystar .= yt(t0+i*Δtobs)

	   # Perform state inflation
	   ϵmul(X, Ny+1, Ny+Nx)
	   ϵx(X, Ny, Nx, config)

	   # Filter state
	   if algo.isfiltered == true
		   @inbounds for i=1:Ne
			   x = view(X, Ny+1:Ny+Nx, i)
			   x .= filter_state!(x, config)
		   end
	   end

	   observe(h, X, t0+i*Δtobs, Ny, Nx; P = P)

	   ϵ = algo.ϵy.σ*randn(Ny, Ne) .+ algo.ϵy.m

	   Xpert = (1/sqrt(Ne-1))*(X[Ny+1:Ny+Nx,:] .- mean(X[Ny+1:Ny+Nx,:]; dims = 2)[:,1])
	   HXpert = (1/sqrt(Ne-1))*(X[1:Ny,:] .- mean(X[1:Ny,:]; dims = 2)[:,1])
	   ϵpert = (1/sqrt(Ne-1))*(ϵ .- mean(ϵ; dims = 2)[:,1])
	   # Kenkf = Xpert*HXpert'*inv(HXpert*HXpert'+ϵpert*ϵpert')

	   b = (HXpert*HXpert' + ϵpert*ϵpert')\(ystar .- (X[1:Ny,:] + ϵ))
	   view(X,Ny+1:Ny+Nx,:) .+= (Xpert*HXpert')*b

	   # @show cumsum(svd((Xpert*HXpert')*inv((HXpert*HXpert' + ϵpert*ϵpert'))).S)./sum(svd((Xpert*HXpert')*inv((HXpert*HXpert' + ϵpert*ϵpert'))).S)

	   # X = algo(X, ystar, t0+i*Δtobs)

	   # Filter state
	   if algo.isfiltered == true
		   @inbounds for i=1:Ne
			   x = view(X, Ny+1:Ny+Nx, i)
			   x .= filter_state!(x, config)
		   end
	   end

	   push!(Xa, deepcopy(state(X, Ny, Nx)))
	end

	return Xf, Xa
end
