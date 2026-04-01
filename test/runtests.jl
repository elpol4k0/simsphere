using Test

include("../src/Simsphere.jl")
using .Simsphere
using .Simsphere.SimLoop: world_stats
using .Simsphere.Events: EventLog, trigger_event!, tick_events!, active_summary
using .Simsphere.Export: TimeSeriesBuffer, record_tick!, flush_timeseries!, export_snapshot
using DataFrames
import CSV

include("test_types.jl")
include("test_temperature.jl")
include("test_water.jl")
include("test_vegetation.jl")
include("test_animals.jl")
include("test_events.jl")
include("test_export.jl")
