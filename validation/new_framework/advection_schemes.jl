using Oceananigans.Advection

advective_flux(i, j, k, grid, ::UpwindBiasedFirstOrder,    U, c) =                 c[i-1]
advective_flux(i, j, k, grid, ::CenteredSecondOrder,       U, c) = (   c[i]   +    c[i-1]) / 2
advective_flux(i, j, k, grid, ::UpwindBiasedThirdOrder,    U, c) = ( 2*c[i]   +  5*c[i-1]    -  c[i-2]) / 6   
advective_flux(i, j, k, grid, ::CenteredFourthOrder,       U, c) = ( 7(c[i]   +    c[i-1] )  - (c[i+1] +    c[i-2]) ) / 12
advective_flux(i, j, k, grid, ::UpwindBiasedFifthOrder,    U, c) = (-3*c[i+1] + 27*c[i]    + 47*c[i-1] - 13*c[i-2] + 2*c[i-3] ) / 60
advective_flux(i, j, k, grid, ::CenteredSixthOrder,        U, c) = (37(c[i] +      c[i-1] ) - 8(c[i+1]    + c[i-2]) + (c[i+2] + c[i-3]) ) / 60

rate_of_convergence(::UpwindBiasedFirstOrder) = 1
rate_of_convergence(::CenteredSecondOrder)    = 2
rate_of_convergence(::UpwindBiasedThirdOrder) = 3
rate_of_convergence(::CenteredFourthOrder)    = 4
rate_of_convergence(::UpwindBiasedFifthOrder) = 5
rate_of_convergence(::CenteredSixthOrder)     = 6

labels(::UpwindBiasedFirstOrder) = "Upwind1ˢᵗ"
labels(::CenteredSecondOrder)    = "Center2ⁿᵈ"
labels(::UpwindBiasedThirdOrder) = "Upwind3ʳᵈ"
labels(::CenteredFourthOrder)    = "Center4ᵗʰ"
labels(::UpwindBiasedFifthOrder) = "Upwind5ᵗʰ"
labels(::CenteredSixthOrder)     = "Center6ᵗʰ"

shapes(::UpwindBiasedFirstOrder) = :circle
shapes(::CenteredSecondOrder)    = :diamond
shapes(::UpwindBiasedThirdOrder) = :dtriangle
shapes(::CenteredFourthOrder)    = :rect
shapes(::UpwindBiasedFifthOrder) = :star5
shapes(::CenteredSixthOrder)     = :star6

colors(::UpwindBiasedFirstOrder) = :blue
colors(::CenteredSecondOrder)    = :green
colors(::UpwindBiasedThirdOrder) = :red
colors(::CenteredFourthOrder)    = :cyan
colors(::UpwindBiasedFifthOrder) = :magenta
colors(::CenteredSixthOrder)     = :purple



