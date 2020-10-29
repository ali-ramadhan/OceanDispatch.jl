using Oceananigans.Fields: AbstractField
using Oceananigans.Operators: Δx, Δy

#####
##### The turbulence closure proposed by Leith
#####

"""
    TwoDimensionalLeith{FT} <: AbstractLeith{FT}

Parameters for the 2D Leith turbulence closure.
"""
struct TwoDimensionalLeith{FT, CR, GM} <: AbstractLeith{FT}
         C :: FT
    C_Redi :: CR
      C_GM :: GM

    function TwoDimensionalLeith{FT}(C, C_Redi, C_GM) where FT
        C_Redi = convert_diffusivity(FT, C_Redi)
        C_GM = convert_diffusivity(FT, C_GM)
        return new{FT, typeof(C_Redi), typeof(C_GM)}(C, C_Redi, C_GM)
    end
end

"""
    TwoDimensionalLeith([FT=Float64;] C=0.3, C_Redi=1, C_GM=1)

Return a `TwoDimensionalLeith` type associated with the turbulence closure proposed by
Leith (1965) and Fox-Kemper & Menemenlis (2008) which has an eddy viscosity of the form

    `νₑ = (C * Δᶠ)³ * √(ζ² + (∇h ∂z w)²)`

and an eddy diffusivity of the form...

where `Δᶠ` is the filter width, `ζ² = (∂x v - ∂y u)²` is the squared vertical vorticity,
and `C` is a model constant.

Keyword arguments
=================
    - `C`      : Model constant
    - `C_Redi` : Coefficient for down-gradient tracer diffusivity for each tracer.
                 Either a constant applied to every tracer, or a `NamedTuple` with fields
                 for each tracer individually.
    - `C_GM`   : Coefficient for down-gradient tracer diffusivity for each tracer.
                 Either a constant applied to every tracer, or a `NamedTuple` with fields
                 for each tracer individually.

References
==========
Leith, C. E. (1968). "Diffusion Approximation for Two‐Dimensional Turbulence", The Physics of
    Fluids 11, 671. doi: 10.1063/1.1691968

Fox‐Kemper, B., & D. Menemenlis (2008), "Can large eddy simulation techniques improve mesoscale rich
    ocean models?", in Ocean Modeling in an Eddying Regime, Geophys. Monogr. Ser., vol. 177, pp. 319–337.
    doi: 10.1029/177GM19

Pearson, B. et al. (2017) , "Evaluation of scale-aware subgrid mesoscale eddy models in a global eddy
    rich model", Ocean Modelling 115, 42-58. doi: 10.1016/j.ocemod.2017.05.007
"""
TwoDimensionalLeith(FT=Float64; C=0.3, C_Redi=1, C_GM=1) = TwoDimensionalLeith{FT}(C, C_Redi, C_GM)

function with_tracers(tracers, closure::TwoDimensionalLeith{FT}) where FT
    C_Redi = tracer_diffusivities(tracers, closure.C_Redi)
    C_GM = tracer_diffusivities(tracers, closure.C_GM)
    return TwoDimensionalLeith{FT}(closure.C, C_Redi, C_GM)
end

@inline function abs²_∇h_ζ(i, j, k, grid, U)
    vxx = ℑyᵃᶜᵃ(i, j, k, grid, ∂²xᶜᵃᵃ, U.v)
    uyy = ℑxᶜᵃᵃ(i, j, k, grid, ∂²yᵃᶜᵃ, U.u)
    uxy = ℑyᵃᶜᵃ(i, j, k, grid, ∂xᶜᵃᵃ, ∂yᵃᶠᵃ, U.u)
    vxy = ℑxᶜᵃᵃ(i, j, k, grid, ∂xᶠᵃᵃ, ∂yᵃᶜᵃ, U.v)

    return (vxx - uxy)^2 + (vxy - uyy)^2
end

const ArrayOrField = Union{AbstractArray, AbstractField}

@inline ψ²(i, j, k, grid, ψ::Function, args...) = ψ(i, j, k, grid, args...)^2
@inline ψ²(i, j, k, grid, ψ::ArrayOrField, args...) = ψ[i, j, k]^2

@inline function abs²_∇h_wz(i, j, k, grid, w)
    wxz² = ℑxᶜᵃᵃ(i, j, k, grid, ψ², ∂xᶠᵃᵃ, ∂zᵃᵃᶜ, w)
    wyz² = ℑyᵃᶜᵃ(i, j, k, grid, ψ², ∂yᵃᶠᵃ, ∂zᵃᵃᶜ, w)
    return wxz² + wyz²
end

@inline νᶜᶜᶜ(i, j, k, grid, clo::TwoDimensionalLeith{FT}, buoyancy, U, C) where FT =
    (clo.C * Δᶠ(i, j, k, grid, clo))^3 * sqrt(  abs²_∇h_ζ(i, j, k, grid, U)
                                              + abs²_∇h_wz(i, j, k, grid, U.w))

#####
##### Abstract Smagorinsky functionality
#####

# Components of the Redi rotation tensor

@inline function Redi_tensor_xz_fcc(i, j, k, grid::AbstractGrid{FT}, buoyancy, C) where FT
    bx = ∂x_b(i, j, k, grid, buoyancy, C)
    bz = ℑxzᶠᵃᶜ(i, j, k, grid, ∂z_b, buoyancy, C)
    return ifelse(bx == 0 && bz == 0, zero(FT), - bx / bz)
end

@inline function Redi_tensor_xz_ccf(i, j, k, grid::AbstractGrid{FT}, buoyancy, C) where FT
    bx = ℑxzᶜᵃᶠ(i, j, k, grid, ∂x_b, buoyancy, C)
    bz = ∂z_b(i, j, k, grid, buoyancy, C)
    return ifelse(bx == 0 && bz == 0, zero(FT), - bx / bz)
end

@inline function Redi_tensor_yz_cfc(i, j, k, grid::AbstractGrid{FT}, buoyancy, C) where FT
    by = ∂y_b(i, j, k, grid, buoyancy, C)
    bz = ℑyzᵃᶠᶜ(i, j, k, grid, ∂z_b, buoyancy, C)
    return ifelse(by == 0 && bz == 0, zero(FT), - by / bz)
end

@inline function Redi_tensor_yz_ccf(i, j, k, grid::AbstractGrid{FT}, buoyancy, C) where FT
    by = ℑyzᵃᶜᶠ(i, j, k, grid, ∂y_b, buoyancy, C)
    bz = ∂z_b(i, j, k, grid, buoyancy, C)
    return ifelse(by == 0 && bz == 0, zero(FT), - by / bz)
end

@inline function Redi_tensor_zz_ccf(i, j, k, grid::AbstractGrid{FT}, buoyancy, C) where FT
    bx = ℑxzᶜᵃᶠ(i, j, k, grid, ∂x_b, buoyancy, C)
    by = ℑyzᵃᶜᶠ(i, j, k, grid, ∂y_b, buoyancy, C)
    bz = ∂z_b(i, j, k, grid, buoyancy, C)
    return ifelse(by == 0 && bx == 0 && bz == 0, zero(FT), (bx^2 + by^2) / bz^2)
end

# Diffusive fluxes for Leith diffusivities

"""
    K₁ⱼ_∂ⱼ_c(i, j, k, grid, c, tracer, closure, νₑ)

Return `K₁₁ ∂x c + K₁₃ ∂z c` for a Leith diffusivity.
"""
@inline function K₁ⱼ_∂ⱼ_c(i, j, k, grid, closure::AbstractLeith,
                          c, ::Val{tracer_index}, νₑ, C, buoyancy) where tracer_index

    @inbounds C_Redi = closure.C_Redi[tracer_index]
    @inbounds C_GM = closure.C_GM[tracer_index]

    νₑⁱʲᵏ = ℑxᶠᵃᵃ(i, j, k, grid, νₑ)

    ∂x_c = ∂xᶠᵃᵃ(i, j, k, grid, c)
    ∂z_c = ℑxzᶠᵃᶜ(i, j, k, grid, ∂zᵃᵃᶠ, c)

    R₁₃ = Redi_tensor_xz_fcc(i, j, k, grid, buoyancy, C)

    return νₑⁱʲᵏ * (                 C_Redi * ∂x_c
                    + (C_Redi - C_GM) * R₁₃ * ∂z_c)
end

"""
    K₂ⱼ_∂ⱼ_c(i, j, k, grid, c, tracer, closure, νₑ)

Return `K₂₂ ∂y c + K₂₃ ∂z c` for a Leith diffusivity.
"""
@inline function K₂ⱼ_∂ⱼ_c(i, j, k, grid, closure::AbstractLeith,
                          c, ::Val{tracer_index}, νₑ, C, buoyancy) where tracer_index

    @inbounds C_Redi = closure.C_Redi[tracer_index]
    @inbounds C_GM = closure.C_GM[tracer_index]

    νₑⁱʲᵏ = ℑyᵃᶠᵃ(i, j, k, grid, νₑ)

    ∂y_c = ∂yᵃᶠᵃ(i, j, k, grid, c)
    ∂z_c = ℑyzᵃᶠᶜ(i, j, k, grid, ∂zᵃᵃᶠ, c)

    R₂₃ = Redi_tensor_yz_cfc(i, j, k, grid, buoyancy, C)
    return νₑⁱʲᵏ * (                  C_Redi * ∂y_c
                     + (C_Redi - C_GM) * R₂₃ * ∂z_c)
end

"""
    K₃ⱼ_∂ⱼ_c(i, j, k, grid, c, tracer, closure, νₑ)

Return `K₃₁ ∂x c + K₃₂ ∂y c + K₃₃ ∂z c` for a Leith diffusivity.
"""
@inline function K₃ⱼ_∂ⱼ_c(i, j, k, grid, closure::AbstractLeith,
                          c, ::Val{tracer_index}, νₑ, C, buoyancy) where tracer_index

    @inbounds C_Redi = closure.C_Redi[tracer_index]
    @inbounds C_GM = closure.C_GM[tracer_index]

    νₑⁱʲᵏ = ℑzᵃᵃᶠ(i, j, k, grid, νₑ)

    ∂x_c = ℑxzᶜᵃᶠ(i, j, k, grid, ∂xᶠᵃᵃ, c)
    ∂y_c = ℑyzᵃᶜᶠ(i, j, k, grid, ∂yᵃᶠᵃ, c)
    ∂z_c = ∂zᵃᵃᶠ(i, j, k, grid, c)

    R₃₁ = Redi_tensor_xz_ccf(i, j, k, grid, buoyancy, C)
    R₃₂ = Redi_tensor_yz_ccf(i, j, k, grid, buoyancy, C)
    R₃₃ = Redi_tensor_zz_ccf(i, j, k, grid, buoyancy, C)

    return νₑⁱʲᵏ * (
          (C_Redi + C_GM) * R₃₁ * ∂x_c
        + (C_Redi + C_GM) * R₃₂ * ∂y_c
                 + C_Redi * R₃₃ * ∂z_c)
end

"""
    ∇_κ_∇c(i, j, k, grid, clock, c, closure, diffusivities)

Return the diffusive flux divergence `∇ ⋅ (κ ∇ c)` for the turbulence
`closure`, where `c` is an array of scalar data located at cell centers.
"""
@inline ∇_κ_∇c(i, j, k, grid, clock, closure::AbstractLeith, c, tracer_index,
               diffusivities, C, buoyancy) = (
      ∂xᶜᵃᵃ(i, j, k, grid, K₁ⱼ_∂ⱼ_c, closure, c, tracer_index, diffusivities.νₑ, C, buoyancy)
    + ∂yᵃᶜᵃ(i, j, k, grid, K₂ⱼ_∂ⱼ_c, closure, c, tracer_index, diffusivities.νₑ, C, buoyancy)
    + ∂zᵃᵃᶜ(i, j, k, grid, K₃ⱼ_∂ⱼ_c, closure, c, tracer_index, diffusivities.νₑ, C, buoyancy)
)

function calculate_diffusivities!(K, arch, grid, closure::AbstractLeith, buoyancy, U, C)
    event = launch!(arch, grid, :xyz, calculate_nonlinear_viscosity!, K.νₑ, grid, closure, buoyancy, U, C,
                    dependencies=Event(device(arch)))

    wait(device(arch), event)

    return nothing
end

"Return the filter width for a Leith Diffusivity on a Regular Cartesian grid."
@inline Δᶠ(i, j, k, grid::RegularCartesianGrid, ::AbstractLeith) = sqrt(Δx(i, j, k, grid) * Δy(i, j, k, grid))
