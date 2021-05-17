using Oceananigans.BoundaryConditions: fill_halo_regions!
using Oceananigans.ImmersedBoundaries: mask_immersed_field!

import Oceananigans.TimeSteppers: update_state!

"""
    update_state!(model::ShallowWaterModel)

Fill halo regions for `model.solution` and `model.tracers`.
"""
function update_state!(model::ShallowWaterModel)

    # Mask immersed fields
    masking_events = Tuple(mask_immersed_field!(field, model.immersed_boundary)
                           for field in merge(model.auxiliary_fields, merge(model.solution, model.tracers)))

    wait(device(model.architecture), MultiEvent(masking_events))

    # Fill halos for velocities and tracers
    fill_halo_regions!(merge(model.solution, model.tracers),
                       model.architecture,
                       model.clock,
                       fields(model))

    return nothing
end

