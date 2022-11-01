import Base: *, +, -, \, size, length, getindex, eltype,similar

import Statistics: cov, mean, std, var

import LinearAlgebra: norm

export create_ensemble, ensemble_perturb, whiten,
        additive_inflation!, multiplicative_inflation!



# basic operations on ensembles
size(X::EnsembleMatrix) = size(X.X)
length(X::EnsembleMatrix) = length(X.X)
getindex(X::EnsembleMatrix,i) = getindex(X.X,i)
getindex(X::EnsembleMatrix,I...) = getindex(X.X,I...)
eltype(X::EnsembleMatrix) = eltype(X.X)





"""
    create_ensemble(Ne,μx,Σx) -> BasicEnsembleMatrix

Create a matrix of size Nx x Ne, where Ne is the ensemble size and Nx is the dimension of the vector.
A vector of the mean and a matrix of the variance are provided for the Gaussian distribution
from which the ensemble is to be drawn.
"""
function create_ensemble(Ne::Int,μx::AbstractVector{T},Σx::Union{AbstractMatrix{T},UniformScaling{T}}) where {T<:Number}
    Nx = length(μx)
    distx = MvNormal(μx,Σx)

    X = rand(distx,Ne)
    return BasicEnsembleMatrix(X)
end

for op in (:+, :-, :*)
    @eval function $op(p1::T,p2::T) where {T <: EnsembleMatrix}
       Base.broadcast($op,p1,p2)
    end
    @eval function $op(p1::Number,p2::EnsembleMatrix)
       Base.broadcast($op,p1,p2)
    end
    @eval function $op(p1::EnsembleMatrix,p2::Number)
       Base.broadcast($op,p1,p2)
    end
end

for op in (:+, :-)
  #@eval ($op)(X::BasicEnsembleMatrix,a::AbstractVector) = BasicEnsembleMatrix($op(X.X,a))
  #@eval ($op)(a::AbstractVector,X::BasicEnsembleMatrix) = BasicEnsembleMatrix($op(a,X.X))
  @eval ($op)(X::BasicEnsembleMatrix,a::AbstractVector) = Base.broadcast($op,X,a)
  @eval ($op)(a::AbstractVector,X::BasicEnsembleMatrix) = Base.broadcast($op,a,X)
end

for op in (:*, :\)
  for t in (:Diagonal, :UniformScaling, :Matrix, :Adjoint)
    @eval ($op)(A::$t,X::BasicEnsembleMatrix) = BasicEnsembleMatrix($op(A,X.X))
  end
end

mean(X::EnsembleMatrix) = _ensemble_mean(X.X)
std(X::EnsembleMatrix) = _ensemble_std(X.X)
cov(X::EnsembleMatrix) = _ensemble_cov(X.X)
cov(X::EnsembleMatrix{Nx,Ne},Y::EnsembleMatrix{Ny,Ne}) where {Nx,Ny,Ne} = _ensemble_cov(X.X,Y.X)
ensemble_perturb(X::EnsembleMatrix{Nx}) where {Nx} = BasicEnsembleMatrix(_ensemble_perturb(X.X))

_ensemble_mean(X::AbstractMatrix) = vec(mean(X,dims=2))
_ensemble_perturb(X::AbstractMatrix) = X .- _ensemble_mean(X)
_ensemble_std(X::AbstractMatrix) = vec(std(X,dims=2))
_ensemble_cov(X::AbstractMatrix) = cov(X,dims=2,corrected=true)
_ensemble_cov(X::AbstractMatrix,Y::AbstractMatrix) = cov(X,Y,dims=2,corrected=true)

"""
    whiten(X::BasicEnsembleMatrix,Σx)

Remove the mean from the ensemble data in `X` and left-multiply each member by ``Σ_x^{-1/2}``
"""
whiten(X::BasicEnsembleMatrix,Σx::Union{UniformScaling,AbstractMatrix}) = inv(sqrt(Σx))*ensemble_perturb(X)


"""
    norm(X::BasicEnsembleMatrix,Σx)

Calculate the norm ``||x||_{\\Sigma^{-1}_x} = \\sqrt{x^T {\\Sigma^{-1}_x} x}``
as an estimate of the expected value over the ensemble in `X`
"""
function norm(X::BasicEnsembleMatrix,Σx::Union{UniformScaling,AbstractMatrix})
  out = 0.0
  for x in eachcol(X)
    out += norm(vec(x),Σx)^2
  end
  return sqrt(out/size(X,2))
end

"""
    norm(x::AbstractVector,Σx)

Calculate the norm ``||x||_{\\Sigma^{-1}_x} = \\sqrt{x^T {\\Sigma^{-1}_x} x}``
"""
norm(x::AbstractVector,Σx::Union{UniformScaling,AbstractMatrix}) = norm(inv(sqrt(Σx))*x)


"""
    additive_inflation!(X::BasicEnsembleMatrix,Σx)

Add to `X` (in place) random noise drawn from a Gaussian distribution with
zero mean and variance given by `Σx`.
"""
function additive_inflation!(X::BasicEnsembleMatrix{Nx,Ne},Σx::Union{UniformScaling,AbstractMatrix}) where {Nx,Ne}
    X .+= create_ensemble(Ne,zeros(Float64,Nx),Σx)
    return X
end

"""
    multiplicative_inflation!(X::BasicEnsembleMatrix,β)

Carry out the operation ``\\bar{x} + \\beta(x^j - \\bar{x})`` for every ensemble
member in `X` (in place).
"""
function multiplicative_inflation!(X::BasicEnsembleMatrix{Nx,Ne},β) where {Nx,Ne}
    X .= mean(X) + β*ensemble_perturb(X)
    return X
end



"""
    YXEnsembleMatrix{Ny,Nx,Ne}

A type which holds two types of data ensembles of size `Ny x Ne` x `Nx x Ne`,
where `Ny` and `Nx` are the dimensions of the data vectors and `Ne` the size of the
ensemble.
"""
struct YXEnsembleMatrix{Ny,Nx,Ne,T,XT} <: EnsembleMatrix{Nx,Ne,T}
    X :: XT
    YXEnsembleMatrix(Y::YT,X::XT) where {YT<:AbstractMatrix,XT<:AbstractMatrix} =
        new{size(Y,1),size(X,1),size(Y,2),eltype(X),XT}(vcat(Y,X))
end

similar(X::YXEnsembleMatrix,element_type=eltype(X),dims=size(X)) = YXEnsembleMatrix(Array{element_type}(undef, dims...))

function Base.show(io::IO,m::MIME"text/plain",X::YXEnsembleMatrix{Ny,Nx,Ne}) where {Ny,Nx,Ne}
    println(io,"Combined Y/X ensemble with $Ne members of $Ny (y) and $Nx (x)-dimensional data")
    show(io,m,X.X)
end

Base.vcat(Y::BasicEnsembleMatrix{Ny,Ne},X::BasicEnsembleMatrix{Nx,Ne}) where {Ny,Nx,Ne} =
    YXEnsembleMatrix(Y.X,X.X)


# BROADCASTING STUFF
# This enables fused in-place broadcasting of all ensemble matrices
Base.BroadcastStyle(::Type{<:EnsembleMatrix}) = Broadcast.ArrayStyle{EnsembleMatrix}()

function Base.similar(bc::Broadcast.Broadcasted{Broadcast.ArrayStyle{EnsembleMatrix}},::Type{T}) where {T}
    similar(unpack(bc),element_type=T)
end

function Base.similar(bc::Broadcast.Broadcasted{Broadcast.ArrayStyle{EnsembleMatrix}})
    similar(unpack(bc))
end

function Base.copyto!(dest::T,bc::Broadcast.Broadcasted{Broadcast.ArrayStyle{EnsembleMatrix}}) where {T <: EnsembleMatrix}
    copyto!(dest.X,unpack_data(bc, nothing))
    dest
end

unpack(bc::Base.Broadcast.Broadcasted) = unpack(bc.args)
unpack(args::Tuple) = unpack(unpack(args[1]), Base.tail(args))
unpack(x) = x
unpack(::Tuple{}) = nothing
unpack(a::EnsembleMatrix, rest) = a
unpack(::Any, rest) = unpack(rest)

@inline unpack_data(bc::Broadcast.Broadcasted, i) = Broadcast.Broadcasted(bc.f, unpack_data_args(i, bc.args))
unpack_data(x,::Any) = x
unpack_data(x::EnsembleMatrix, ::Nothing) = x.X

@inline unpack_data_args(i, args::Tuple) = (unpack_data(args[1], i), unpack_data_args(i, Base.tail(args))...)
unpack_data_args(i, args::Tuple{Any}) = (unpack_data(args[1], i),)
unpack_data_args(::Any, args::Tuple{}) = ()
