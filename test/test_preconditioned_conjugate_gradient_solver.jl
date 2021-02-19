using Statistics

@kernel function ∇²!(grid, f, ∇²f)
    i, j, k = @index(Global, NTuple)
    @inbounds ∇²f[i, j, k] = ∇²(i, j, k, grid, f)
end

@kernel function divergence!(grid, u, v, w, div)
    i, j, k = @index(Global, NTuple)
    @inbounds div[i, j, k] = divᶜᶜᶜ(i, j, k, grid, u, v, w)
end

function run_pcg_solver_tests(arch)
    Lx, Ly, Lz = 4e6, 6e6, 1
    Nx, Ny, Nz = 100, 150, 1
    grid = RegularCartesianGrid(size=(Nx, Ny, Nz), extent=(Lx, Ly, Lz))

    function Amatrix_function!(result, x, arch, grid, bcs)
        event = launch!(arch, grid, :xyz, ∇²!, grid, x, result, dependencies=Event(device(arch)))
        wait(device(arch), event)
        fill_halo_regions!(result, bcs, arch, grid)
        return nothing
    end

    # Fields for flow, divergence of flow, RHS, and potential to make non-divergent, ϕ
    velocities = VelocityFields(arch, grid)
    RHS        = CenterField(arch, grid)
    ϕ          = CenterField(arch, grid)

    # Set divergent flow and calculate divergence
    u, v, w  = velocities

    imid = Int(floor(grid.Nx / 2)) + 1
    jmid = Int(floor(grid.Ny / 2)) + 1
    CUDA.@allowscalar u.data[imid, jmid, 1] = 1

    fill_halo_regions!(u.data, u.boundary_conditions, arch, grid)

    event = launch!(arch, grid, :xyz, divergence!, grid, u.data, v.data, w.data, RHS.data,
                    dependencies=Event(device(arch)))
    wait(device(arch), event)

    fill_halo_regions!(RHS.data, RHS.boundary_conditions, arch, grid)

    pcg_params = (
        PCmatrix_function = nothing,
        Amatrix_function = Amatrix_function!,
        Template_field = RHS,
        maxit = 1000, # grid.Nx * grid.Ny,
        tol = 1.e-13
    )

    pcg_solver = PreconditionedConjugateGradientSolver(arch = arch, parameters = pcg_params)

    # Set initial guess and solve
    ϕ.data.parent .= 0
    @time solve_poisson_equation!(pcg_solver, RHS.data, ϕ.data)

    # Compute ∇² of solution
    result = similar(ϕ.data)

    event = launch!(arch, grid, :xyz, ∇²!, grid, ϕ.data, result, dependencies=Event(device(arch)))
    wait(device(arch), event)

    fill_halo_regions!(result, ϕ.boundary_conditions, arch, grid)

    CUDA.@allowscalar begin
        @test abs(minimum(result[1:Nx, 1:Ny, 1] .- RHS.data[1:Nx, 1:Ny, 1])) < 1e-12
        @test abs(maximum(result[1:Nx, 1:Ny, 1] .- RHS.data[1:Nx, 1:Ny, 1])) < 1e-12
        @test std(result[1:Nx, 1:Ny, 1] .- RHS.data[1:Nx, 1:Ny, 1]) < 1e-14
    end

    return nothing
end

@testset "Conjugate gradient solvers" begin
    for arch in archs
        @info "Testing conjugate gradient solvers [$(typeof(arch))]..."
        run_pcg_solver_tests(arch)
    end
end