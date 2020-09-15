using SymPy
using Oceananigans.Advection: eno_coefficients, optimal_weno_weights, β

function print_eno_interpolant(k, r)
    cs = eno_coefficients(k, r)

    ssign(n) = n >= 0 ? "+" : "-"
    ssubscript(n) = n == 0 ? "i"  : "i" * ssign(n) * string(abs(n))

    print("u(i+1//2) = ")
    for (j, c) in enumerate(cs)
        c_s = ssign(c) * " " * string(abs(c))
        ss_s = ssubscript(j-r-1)
        print(c_s * " u(" * ss_s * ") ")
    end
    print("\n")
end

function print_eno_interpolants(k)
    for r in -1:k-1
        print_eno_interpolant(k, r)
    end
    Γ = optimal_weno_weights(k)
    println("Optimal weights γᵣ: $Γ")
end

@testset "WENO reconstruction" begin
    @info "Testing WENO reconstruction..."
    
    @testset "ENO reconstruction weights" begin

        @testset "WENO-3" begin
            @info "WENO-3 coefficients [Compare with Table 2.1 of Shu (1998)]:"
            print_eno_interpolants(2)

            @test eno_coefficients(2, -1) == [ 3//2, -1//2]
            @test eno_coefficients(2,  0) == [ 1//2,  1//2]
            @test eno_coefficients(2,  1) == [-1//2,  3//2]     
        end

        @testset "WENO-5" begin
            @info "WENO-5 coefficients [Compare with Table 2.1 of Shu (1998) and equation (2.15) from Shu (2009)]:"
            print_eno_interpolants(3)

            @test eno_coefficients(3, -1) == [11//6, -7//6,  1//3]
            @test eno_coefficients(3,  0) == [ 1//3,  5//6, -1//6]
            @test eno_coefficients(3,  1) == [-1//6,  5//6,  1//3]
            @test eno_coefficients(3,  2) == [ 1//3, -7//6, 11//6]
        end

        @testset "WENO-7" begin
            @info "WENO-7 coefficients [Compare with Table 2.1 of Shu (1998)]:"
            print_eno_interpolants(4)

            @test eno_coefficients(4, -1) == [25//12, -23//12,  13//12, -1//4 ]
            @test eno_coefficients(4,  0) == [ 1//4,   13//12,  -5//12,  1//12]
            @test eno_coefficients(4,  1) == [-1//12,   7//12,   7//12, -1//12]
            @test eno_coefficients(4,  2) == [ 1//12,  -5//12,  13//12,  1//4 ]
            @test eno_coefficients(4,  3) == [-1//4,   13//12, -23//12, 25//12]
        end

        @testset "WENO-9" begin
            @info "WENO-9 coefficients [Compare with Table 2.1 of Shu (1998) and equation (2.14) of Shu (2009)]:"
            print_eno_interpolants(5)

            @test eno_coefficients(5, -1) == [ 137//60, -163//60, 137//60,  -21//20,   1//5 ]
            @test eno_coefficients(5,  0) == [   1//5,    77//60, -43//60,   17//60,  -1//20]
            @test eno_coefficients(5,  1) == [  -1//20,    9//20,  47//60,  -13//60,   1//30]
            @test eno_coefficients(5,  2) == [   1//30,  -13//60,  47//60,    9//20,  -1//20]
            @test eno_coefficients(5,  3) == [  -1//20,   17//60, -43//60,   77//60,   1//5 ]
            @test eno_coefficients(5,  4) == [   1//5,   -21//20, 137//60, -163//60, 137//60]
        end
    end

    @testset "WENO optimal weights" begin
        @testset "WENO-3" begin
            # Compare with Table II of Jiang & Shu (1996).
            @test optimal_weno_weights(2) == [1//3, 2//3]
        end
        
        @testset "WENO-5" begin
            # Compare with equation (2.15) of Shu (2009).
            @test optimal_weno_weights(3) == [1//10, 3//5, 3//10]
        end

        @testset "WENO-7" begin end

        @testset "WENO-9" begin
            @test optimal_weno_weights(5) == [1//126, 10//63, 10//21, 20//63, 5//126]
        end
    end

    @testset "WENO smoothness indicators" begin
        @testset "WENO-5" begin
            ϕ = @vars ϕᵢ₋₂  ϕᵢ₋₁ ϕᵢ ϕᵢ₊₁ ϕᵢ₊₂
            
            β₀_correct = 13//12 * (ϕᵢ₋₂ - 2ϕᵢ₋₁ + ϕᵢ  )^2 + 1//4 * ( ϕᵢ₋₂ - 4ϕᵢ₋₁ + 3ϕᵢ  )^2 |> expand
            β₁_correct = 13//12 * (ϕᵢ₋₁ - 2ϕᵢ   + ϕᵢ₊₁)^2 + 1//4 * ( ϕᵢ₋₁         -  ϕᵢ₊₁)^2 |> expand
            β₂_correct = 13//12 * (ϕᵢ   - 2ϕᵢ₊₁ + ϕᵢ₊₂)^2 + 1//4 * (3ϕᵢ   - 4ϕᵢ₊₁ +  ϕᵢ₊₂)^2 |> expand

            ϕ₀ = ϕ[1:3]
            ϕ₁ = ϕ[2:4]
            ϕ₂ = ϕ[3:5]

            @test β(2, 0, reverse(ϕ₀)) |> expand == β₀_correct
            @test β(2, 1, reverse(ϕ₁)) |> expand == β₁_correct
            @test β(2, 2, reverse(ϕ₂)) |> expand == β₂_correct
        end
    end
end
