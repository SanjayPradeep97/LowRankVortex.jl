export pressure, dpdzv, dpdΓv


# A few helper routines
strength(v::Union{PotentialFlow.Points.Point,PotentialFlow.Blobs.Blob}) = v.S
strength(v::Vector{T}) where {T<:PotentialFlow.Points.Point} = map(vj -> strength(vj),v)

# Define the functions that comprise the pressure and its gradients
const EPSILON_DEFAULT = 0.01

abstract type ImageType end
abstract type Cylinder <: ImageType end
abstract type FlatWall <: ImageType end
abstract type NoWall <: ImageType end

const EPSILON_DEFAULT = 0.01

Fvd(z,zv;ϵ=EPSILON_DEFAULT,kwargs...) = complexpotential(z,Vortex.Blob(zv,1.0,ϵ))
_Fvi(z,zv,::Type{NoWall}) = complex(0.0)
_Fvi(z,zv,::Type{Cylinder}) = -0.5im/π*(-log(z-1/conj(zv)) + log(z))
Fvi(z,zv;walltype=NoWall) = _Fvi(z,zv,walltype)
Fv(z,zv;ϵ=EPSILON_DEFAULT,walltype=NoWall) = Fvd(z,zv) + _Fvi(z,zv,walltype)
wvd(z,zv;ϵ=EPSILON_DEFAULT,kwargs...) = -0.5im/π*conj(z-zv)/(abs2(z-zv)+ϵ^2)
_wvi(z,zv,::Type{NoWall}) = complex(0.0)
_wvi(z,zv,::Type{Cylinder}) = -0.5im/π*(-1/(z-1/conj(zv)) + 1/z)
wvi(z,zv;walltype=NoWall,kwargs...) = _wvi(z,zv,walltype)
wv(z,zv;ϵ=EPSILON_DEFAULT,walltype=NoWall) = wvd(z,zv;ϵ=ϵ) + _wvi(z,zv,walltype)

dwvddz(z,zv;ϵ=EPSILON_DEFAULT,kwargs...) = 0.5im*conj(z-zv)^2/π/(abs2(z-zv) + ϵ^2)^2
dwvddzstar(z,zv;ϵ=EPSILON_DEFAULT,kwargs...) = -0.5im*ϵ^2/π/(abs2(z-zv) + ϵ^2)^2
_dwvidz(z,zv,::Type{NoWall}) = complex(0.0)
_dwvidz(z,zv,::Type{Cylinder}) = -0.5im/π*(1/(z-1/conj(zv))^2-1/z^2)
dwvidz(z,zv;walltype=NoWall,kwargs...) = _dwvidz(z,zv,walltype)
dwvdz(z,zv;ϵ=EPSILON_DEFAULT,walltype=NoWall) = dwvddz(z,zv;ϵ=ϵ) + _dwvidz(z,zv,walltype)

dwvddzv(z,zv;ϵ=EPSILON_DEFAULT,kwargs...) = -dwvddz(z,zv;ϵ=ϵ)
dwvddzvstar(z,zv;ϵ=EPSILON_DEFAULT,kwargs...) = -dwvddzstar(z,zv;ϵ=ϵ)
_dwvidzvstar(z,zv,::Type{NoWall}) = complex(0.0)
_dwvidzvstar(z,zv,::Type{Cylinder}) = -0.5im/π/conj(zv)^2/(z-1/conj(zv))^2
dwvidzvstar(z,zv;walltype=NoWall,kwargs...) = _dwvidzvstar(z,zv,walltype)
dwvdzvstar(z,zv;ϵ=EPSILON_DEFAULT,walltype=NoWall) = dwvddzvstar(z,zv;ϵ=ϵ) + _dwvidzvstar(z,zv,walltype)

dFddzv(z,zv;ϵ=EPSILON_DEFAULT,kwargs...) = -wvd(z,zv;ϵ=ϵ)
_dFidzvstar(z,zv,::Type{NoWall}) = complex(0.0)
_dFidzvstar(z,zv,::Type{Cylinder}) = 0.5im/π/conj(zv)^2/(z-1/conj(zv))
dFidzvstar(z,zv;walltype=NoWall,kwargs...) = _dFidzvstar(z,zv,walltype)
dFdzv(z,zv;ϵ=EPSILON_DEFAULT,walltype=NoWall) = dFddzv(z,zv;ϵ=ϵ) + conj(_dFidzvstar(z,zv,walltype))

d2Fddzv2(z,zv;ϵ=EPSILON_DEFAULT,kwargs...) = dwvddz(z,zv;ϵ=ϵ)
d2Fddzvdvzstar(z,zv;ϵ=EPSILON_DEFAULT,kwargs...) = dwvddzstar(z,zv;ϵ=ϵ)
_d2Fidzvstar2(z,zv,::Type{NoWall}) = complex(0.0)
_d2Fidzvstar2(z,zv,::Type{Cylinder}) = -0.5im/π/conj(zv)^3/(z-1/conj(zv))*(2 + 1/conj(zv)/(z-1/conj(zv)))
d2Fidzvstar2(z,zv;walltype=NoWall,kwargs...) = _d2Fidzvstar2(z,zv,walltype)
d2Fdzv2(z,zv;ϵ=EPSILON_DEFAULT,walltype=NoWall) = d2Fddzv2(z,zv;ϵ=ϵ) + conj(_d2Fidzvstar2(z,zv,walltype))


P(z,zv;kwargs...) = abs2(wv(z,zv;kwargs...)) + 2real(dFdzv(z,zv;kwargs...)*conj(wvi(zv,zv;kwargs...)))
Π(z,zvj,zvk;kwargs...) = real(wv(z,zvj;kwargs...)*conj(wv(z,zvk;kwargs...))) +
                           real(dFdzv(z,zvj;kwargs...)*conj(wv(zvj,zvk;kwargs...))) +
                           real(dFdzv(z,zvk;kwargs...)*conj(wv(zvk,zvj;kwargs...)))

dPdzv(z,zv;kwargs...) = (dwvddzv(z,zv;kwargs...)*conj(wv(z,zv;kwargs...)) + wv(z,zv;kwargs...)*conj(dwvdzvstar(z,zv;kwargs...))) +
                        (d2Fdzv2(z,zv;kwargs...)*conj(wvi(zv,zv;kwargs...)) + conj(d2Fddzvdvzstar(z,zv;kwargs...))*wvi(zv,zv;kwargs...) + dFdzv(z,zv;kwargs...)*conj(dwvidzvstar(zv,zv;kwargs...))) +
                        (conj(dFdzv(z,zv;kwargs...))*dwvidz(zv,zv;kwargs...))

dΠdzvl(z,zvl,zvk;kwargs...) = 0.5*(dwvddzv(z,zvl;kwargs...)*conj(wv(z,zvk;kwargs...)) + conj(dwvddzvstar(z,zvl;kwargs...)+dwvidzvstar(z,zvl;kwargs...))*wv(z,zvk;kwargs...)) +
                               0.5*(d2Fdzv2(z,zvl;kwargs...)*conj(wv(zvl,zvk;kwargs...)) + dFdzv(z,zvl;kwargs...)*conj(dwvddzstar(zvl,zvk;kwargs...)) + conj(d2Fddzvdvzstar(z,zvl;kwargs...))*wv(zvl,zvk;kwargs...)  + conj(dFdzv(z,zvl;kwargs...))*dwvdz(zvl,zvk;kwargs...)) +
                               0.5*(dFdzv(z,zvk;kwargs...)*conj(dwvdzvstar(zvk,zvl;kwargs...)) + conj(dFdzv(z,zvk;kwargs...))*dwvddzv(zvk,zvl;kwargs...))

for f in [:F,:w]

   vd = Symbol(f,"vd")
   vi = Symbol(f,"vi")

   @eval function $f(z,v::Vector{T};kwargs...) where {T<:Union{PotentialFlow.Points.Point,PotentialFlow.Blobs.Blob}}
       out = complex(0)
       for vj in v
           zj = Elements.position(vj)
           # out += strength(vj)*($vd(z,zj;kwargs...) + $vi(z,zj;kwargs...))
           out += strength(vj)*($vd(z,zj;kwargs...) + $vi(z,zj))
       end
       return out
   end

   @eval $f(z::AbstractArray,v::Vector{T};kwargs...) where {T<:Union{PotentialFlow.Points.Point,PotentialFlow.Blobs.Blob}} = map(zj -> $f(zj,v;kwargs...),z)
end


### Define the pressure and its gradients

# Note that $\mathrm{d}p/\mathrm{d}z^* = (\mathrm{d}p/\mathrm{d}z)^*$.
# To obtain the gradient of pressure with respect to the $x$ or $y$ position of vortex $l$, use
# $$\frac{\partial p}{\partial x_l} = \frac{\mathrm{d}p}{\mathrm{d}z_l} + \frac{\mathrm{d}p}{\mathrm{d}z^*_l} = 2 \mathrm{Re} \frac{\mathrm{d}p}{\mathrm{d}z_l}$$
# and
# $$\frac{\partial p}{\partial y_l} = \mathrm{i}\frac{\mathrm{d}p}{\mathrm{d}z_l} - \mathrm{i} \frac{\mathrm{d}p}{\mathrm{d}z^*_l} = -2 \mathrm{Im} \frac{\mathrm{d}p}{\mathrm{d}z_l}$$


function pressure(z,v::Vector{T};kwargs...) where {T<:Union{PotentialFlow.Points.Point,PotentialFlow.Blobs.Blob}}
        out = 0.0
        for (j,vj) in enumerate(v)
            zj,Γj  = Elements.position(vj), strength(vj)
            out -= 0.5*Γj^2*P(z,zj;kwargs...)
            for vk in v[1:j-1]
                zk,Γk  = Elements.position(vk), strength(vk)
                out -= Γj*Γk*Π(z,zj,zk;kwargs...)
            end
        end
        return out
end

# Change of pressure with respect to change of strength of vortex l (specified by its index)
function dpdΓv(z,l::Integer,v::Vector{T};kwargs...) where {T<:Union{PotentialFlow.Points.Point,PotentialFlow.Blobs.Blob}}
        zl,Γl  = Elements.position(v[l]), strength(v[l])
        out = -Γl*P(z,zl;kwargs...)
        for (k,vk) in enumerate(v)
            k == l && continue
            zk,Γk  = Elements.position(vk), strength(vk)
            out -= Γk*Π(z,zl,zk;kwargs...)
        end
        return out
end

# Change of pressure with respect to change of position of vortex l (specified by its index)
function dpdzv(z,l::Integer,v::Vector{T};kwargs...) where {T<:Union{PotentialFlow.Points.Point,PotentialFlow.Blobs.Blob}}
        zl,Γl  = Elements.position(v[l]), strength(v[l])
        out = -0.5*Γl*dPdzv(z,zl;kwargs...)
        for (k,vk) in enumerate(v)
            k == l && continue
            zk,Γk  = Elements.position(vk), strength(vk)
            out -= Γk*dΠdzvl(z,zl,zk;kwargs...)
        end
        return Γl*out
end

pressure(z::AbstractArray,v::Vector{T};kwargs...) where {T<:Union{PotentialFlow.Points.Point,PotentialFlow.Blobs.Blob}} = map(zj -> pressure(zj,v;kwargs...),z)
dpdzv(z::AbstractArray,l::Integer,v::Vector{T};kwargs...) where {T<:Union{PotentialFlow.Points.Point,PotentialFlow.Blobs.Blob}} = map(zj -> dpdzv(zj,l,v;kwargs...),z)
dpdΓv(z::AbstractArray,l::Integer,v::Vector{T};kwargs...) where {T<:Union{PotentialFlow.Points.Point,PotentialFlow.Blobs.Blob}} = map(zj -> dpdΓv(zj,l,v;kwargs...),z)
