using CUDA: has_cuda
using OrderedCollections: OrderedDict

using Oceananigans: AbstractModel, AbstractOutputWriter, AbstractDiagnostic

using Oceananigans.Architectures: AbstractArchitecture
using Oceananigans.Advection: CenteredSecondOrder
using Oceananigans.BoundaryConditions: regularize_field_boundary_conditions
using Oceananigans.Fields: Field, tracernames, VelocityFields, TracerFields
using Oceananigans.Grids: with_halo
using Oceananigans.TimeSteppers: Clock, TimeStepper
using Oceananigans.Utils: inflate_halo_size, tupleit


mutable struct ShallowWaterModel{G, A<:AbstractArchitecture, T, V, R, U, H, C, TS} <: AbstractModel{TS}
    
                 grid :: G         # Grid of physical points on which `Model` is solved
         architecture :: A         # Computer `Architecture` on which `Model` is run
                clock :: Clock{T}  # Tracks iteration number and simulation time of `Model`
            advection :: V         # Advection scheme for velocities _and_ tracers
             coriolis :: R         # Set of parameters for the background rotation rate of `Model`
           transports :: U         # Container for the transports with fields `uh`, and `vh`
              heights :: H         # Container for height
              tracers :: C         # Container for tracer fields
          timestepper :: TS        # Object containing timestepper fields and parameters
end

function ShallowWaterModel(;
                           grid,
  architecture::AbstractArchitecture = CPU(),
                          float_type = Float64,
                               clock = Clock{float_type}(0, 0, 1),
                           advection = CenteredSecondOrder(),
                            coriolis = nothing,
                          transports = nothing,
                            heights  = nothing,
                             tracers = (:C,),
                 boundary_conditions = NamedTuple(),
                         timestepper = :RungeKutta3
    )

    tracers = tupleit(tracers) # supports tracers=:c keyword argument (for example)
    
    embedded_boundary_conditions = merge(extract_boundary_conditions(transports),
                                         extract_boundary_conditions(heights),
                                         extract_boundary_conditions(tracers))
    
    boundary_conditions = regularize_field_boundary_conditions(boundary_conditions, grid, nothing)
    
    transports = VelocityFields(transports,  architecture, grid, boundary_conditions)
    heights    = TracerFields(heights,       architecture, grid, boundary_conditions)
    tracers    = TracerFields(tracers,       architecture, grid, boundary_conditions)
    
    #timestepper = TimeStepper(timestepper, architecture, grid, tracernames(tracers))
    
    return ShallowWaterModel(grid, architecture, clock, advection, coriolis, transports, heights, tracers, timestepper)

end

extract_boundary_conditions(::Nothing) = NamedTuple()
extract_boundary_conditions(::Tuple) = NamedTuple()

function extract_boundary_conditions(field_tuple::NamedTuple)
    names = propertynames(field_tuple)
    bcs = Tuple(extract_boundary_conditions(field) for field in field_tuple)
    return NamedTuple{names}(bcs)
end

extract_boundary_conditions(field::Field) = field.boundary_conditions