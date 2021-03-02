# # Solid body rotation of a meridional sector on the sphere
#
# This script implements the "Global Steady State Nonlinear Zonal Geostrophic Flow"
# validation experiment from
#
# > Williamson et al., "A Standard Test Set for Numerical Approximations to the Shallow
#   Water Equations in Spherical Geometry", Journal of Computational Physics, 1992.
#
# The problem is posed in spherical strip between 60ᵒS and 60ᵒN latitude on a sphere with
# unit radius.
#
# # Dependencies
#
# The validation experiment depends on Oceananigans, JLD2, Printf, and GLMakie for visualization

using Oceananigans
using Oceananigans.Grids

using Oceananigans.Coriolis:
    HydrostaticSphericalCoriolis,
    VectorInvariantEnergyConserving,
    VectorInvariantEnstrophyConserving

using Oceananigans.Models.HydrostaticFreeSurfaceModels:
    HydrostaticFreeSurfaceModel,
    VectorInvariant,
    ExplicitFreeSurface

using Oceananigans.Utils: prettytime, hours
using Oceananigans.OutputWriters: JLD2OutputWriter, TimeInterval, IterationInterval

using JLD2
using Printf
using GLMakie

include("hydrostatic_prescribed_velocity_fields.jl")

# # The geostrophic flow
#
# ```math
# u = U \cos ϕ
# v = 0
# η = - g^{-1} \left (R Ω U + \frac{U^2}{2} \right ) \sin^2 ϕ
# ```
#
# is a steady nonlinear flow on a sphere of radius ``R`` with gravitational
# acceleration ``g``, corresponding to solid body rotation
# in the same direction as the "background" rotation rate ``\Omega``.
# The velocity ``U`` determines the magnitude of the additional rotation.

const U = 0.1

solid_body_rotation(λ, ϕ) = U * cosd(ϕ)
solid_body_geostrophic_height(λ, ϕ, R, Ω, g) = (R * Ω * U + U^2 / 2) * sind(ϕ)^2 / g

# In addition to the solid body rotation solution, we paint a Gaussian tracer patch
# on the spherical strip to visualize the rotation.

northern_boundary = 80 # degrees
Ω = 1 # rad / s
g = 1 # m s⁻²

function run_solid_body_tracer_advection(;
                                         architecture = CPU(),
                                         Nx = 360,
                                         Ny = 8,
                                         super_rotations = 4
                                        )

    # A spherical domain
    grid = RegularLatitudeLongitudeGrid(size = (Nx, Ny, 1),
                                        radius = 1,
                                        latitude = (-northern_boundary, northern_boundary),
                                        longitude = (-180, 180),
                                        z = (-1, 0))

    uᵢ(λ, ϕ, z) = solid_body_rotation(λ, ϕ)

    model = HydrostaticFreeSurfaceModel(grid = grid,
                                        architecture = architecture,
                                        tracers = (:c, :d, :e),
                                        velocities = PrescribedVelocityFields(grid, u=uᵢ),
                                        coriolis = nothing,
                                        buoyancy = nothing,
                                        closure = nothing)

    # Tracer patch for visualization
    Gaussian(λ, ϕ, L) = exp(-(λ^2 + ϕ^2) / 2L^2)

    # Tracer patch parameters
    L = 24 # degree
    ϕ₀ = 0 # degrees

    cᵢ(λ, ϕ, z) = Gaussian(λ, 0, L)
    dᵢ(λ, ϕ, z) = Gaussian(0, ϕ - ϕ₀, L)
    eᵢ(λ, ϕ, z) = Gaussian(λ, ϕ - ϕ₀, L)

    set!(model, c=cᵢ, d=dᵢ, e=eᵢ)

    gravity_wave_speed = sqrt(g * grid.Lz) # hydrostatic (shallow water) gravity wave speed

    # Time-scale for gravity wave propagation across the smallest grid cell
    wave_propagation_time_scale = min(grid.radius * cosd(maximum(abs, grid.ϕᵃᶜᵃ)) * deg2rad(grid.Δλ),
                                      grid.radius * deg2rad(grid.Δϕ)) / gravity_wave_speed

    super_rotation_period = 2π * grid.radius / U

    simulation = Simulation(model,
                            Δt = 0.1wave_propagation_time_scale,
                            stop_time = super_rotations * super_rotation_period,
                            iteration_interval = 100,
                            progress = s -> @info "Time = $(s.model.clock.time) / $(s.stop_time)")
                                                             
    output_fields = model.tracers

    output_prefix = "solid_body_tracer_advection_Nx$(grid.Nx)"

    simulation.output_writers[:fields] = JLD2OutputWriter(model, output_fields,
                                                          schedule = TimeInterval(super_rotation_period / 20),
                                                          prefix = output_prefix,
                                                          force = true)

    run!(simulation)

    return simulation.output_writers[:fields].filepath
end

function visualize_solid_body_tracer_advection(filepath)

    @show output_prefix = basename(filepath)[1:end-5]

    file = jldopen(filepath)

    iterations = parse.(Int, keys(file["timeseries/t"]))

    Nx = file["grid/Nx"]
    Ny = file["grid/Ny"]

    grid = RegularLatitudeLongitudeGrid(size = (Nx, Ny, 1),
                                        radius = 1,
                                        latitude = (-northern_boundary, northern_boundary),
                                        longitude = (-180, 180),
                                        z = (-1, 0))

    super_rotation_period = 2π * grid.radius / U

    λ = xnodes(Face, grid)
    ϕ = ynodes(Center, grid)
    
    λ = repeat(reshape(λ, Nx, 1), 1, Ny)
    ϕ = repeat(reshape(ϕ, 1, Ny), Nx, 1)

    λ_azimuthal = λ .+ 180  # Convert to λ ∈ [0°, 360°]
    ϕ_azimuthal = 90 .- ϕ   # Convert to ϕ ∈ [0°, 180°] (0° at north pole)

    iter = Node(0)

    plot_title = @lift @sprintf("Tracer advection by geostrophic solid body rotation: rotations = %.3f",
                                file["timeseries/t/" * string($iter)] / super_rotation_period)

    c = @lift file["timeseries/c/" * string($iter)][:, :, 1]
    d = @lift file["timeseries/d/" * string($iter)][:, :, 1]
    e = @lift file["timeseries/e/" * string($iter)][:, :, 1]

    # Plot on the unit sphere to align with the spherical wireframe.
    x = @. cosd(λ_azimuthal) * sind(ϕ_azimuthal)
    y = @. sind(λ_azimuthal) * sind(ϕ_azimuthal)
    z = @. cosd(ϕ_azimuthal)

    fig = Figure(resolution = (1080, 1080))

    titles = ["c", "d", "e"]

    for (n, var) in enumerate((c, d, e))
        ax = fig[n, 1] = Axis(fig, xlabel = "λ", ylabel = "ϕ", title = titles[n])
        heatmap!(ax, var)
    end

    supertitle = fig[0, :] = Label(fig, plot_title, textsize=30)

    record(fig, output_prefix * ".mp4", iterations, framerate=30) do i
        @info "Animating iteration $i/$(iterations[end])..."
        iter[] = i
    end

    return nothing
end

filepath = run_solid_body_tracer_advection(Nx=180, Ny=30, super_rotations=2)
visualize_solid_body_tracer_advection(filepath)