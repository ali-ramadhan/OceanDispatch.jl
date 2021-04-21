@testset "Field broadcasting" begin
    @info "  Testing broadcasting with fields..."

    for arch in archs
        grid = RegularRectilinearGrid(size=(1, 1, 1), extent=(1, 1, 1))
        a, b, c = [CenterField(arch, grid) for i = 1:3]

        Nx, Ny, Nz = size(a)

        a .= 1
        @test all(a .== 1) 

        b .= 2

        c .= a .+ b
        @test all(c .== 3)

        c .= a .+ b .+ 1
        @test all(c .== 4)

        # Halo regions
        @test c[1, 1, 0] == 4
        @test c[1, 1, Nz+1] == 4

        # Broadcasting with interpolation
        three_point_grid = RegularRectilinearGrid(size=(1, 1, 3), extent=(1, 1, 1))

        a2 = CenterField(arch, three_point_grid)
        b2 = ZFaceField(arch, three_point_grid)
        b2 .= 1
        fill_halo_regions!(b2, arch)

        @test b2.data[1, 1, 1] == 0
        @test b2.data[1, 1, 2] == 1
        @test b2.data[1, 1, 3] == 1
        @test b2.data[1, 1, 4] == 0

        a2 .= b2
        @test a2.data[1, 1, 1] = 0.5
        @test a2.data[1, 1, 2] = 1.0
        @test a2.data[1, 1, 3] = 0.5

        r, p, q = [ReducedField(Center, Center, Nothing, arch, grid, dims=3) for i = 1:3]

        r .= 2 
        @test all(r .== 2) 

        p .= 3 
        q .= r .* p .+ 1
        @test all(q .== 7) 
    end
end
