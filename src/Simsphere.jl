module Simsphere

include("core/Types.jl")
include("core/World.jl")
include("physics/Temperature.jl")
include("physics/Water.jl")
include("biology/Vegetation.jl")
include("biology/Animals.jl")
include("events/Events.jl")
include("scenarios/Scenarios.jl")
include("core/SimLoop.jl")
include("io/Export.jl")
include("visualization/SetupGUI.jl")
include("visualization/Renderer.jl")

using .Types
using .WorldModule
using .SimLoop
using .Animals
using .Events
using .Scenarios
using .Export
using .SetupGUI
using .Renderer

export SimConfig, SimState, World, Cell
export create_world, tick!, run_simulation!, launch_visualization!
export show_setup_gui
export AgentModel, create_animal_model, step_animals!
export EventLog, trigger_event!, tick_events!, active_summary
export apply_scenario!, load_config, SCENARIOS
export TimeSeriesBuffer, record_tick!, flush_timeseries!, export_snapshot

const world_stats = SimLoop.world_stats
export world_stats

end
