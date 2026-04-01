module Export

using CSV
using DataFrames
using ..Types
using ..SimLoop: world_stats
using ..Animals
using ..Events

export TimeSeriesBuffer, record_tick!, flush_timeseries!, export_snapshot

mutable struct TimeSeriesBuffer
    ticks::Vector{Int}
    mean_temp::Vector{Float64}
    mean_water::Vector{Float64}
    mean_biomass::Vector{Float64}
    mean_nutrients::Vector{Float64}
    n_flooded::Vector{Int}
    n_herbivores::Vector{Int}
    n_carnivores::Vector{Int}
    event_log::Vector{NamedTuple}
end

TimeSeriesBuffer() = TimeSeriesBuffer(
    Int[], Float64[], Float64[], Float64[], Float64[], Int[], Int[], Int[], NamedTuple[]
)

function record_tick!(buf::TimeSeriesBuffer, world::World, state::SimState,
                      model::AgentModel, log::EventLog)
    stats = world_stats(world)
    push!(buf.ticks,          state.tick)
    push!(buf.mean_temp,      stats.mean_temp)
    push!(buf.mean_water,     stats.mean_water)
    push!(buf.mean_biomass,   stats.mean_biomass)
    push!(buf.mean_nutrients, stats.mean_nutrients)
    push!(buf.n_flooded,      stats.n_flooded)
    push!(buf.n_herbivores,   model.n_herbivores)
    push!(buf.n_carnivores,   model.n_carnivores)
    append!(buf.event_log, log.history)
    empty!(log.history)
end

function flush_timeseries!(buf::TimeSeriesBuffer, path::String)
    df = DataFrame(
        tick           = buf.ticks,
        mean_temp      = buf.mean_temp,
        mean_water     = buf.mean_water,
        mean_biomass   = buf.mean_biomass,
        mean_nutrients = buf.mean_nutrients,
        n_flooded      = buf.n_flooded,
        n_herbivores   = buf.n_herbivores,
        n_carnivores   = buf.n_carnivores,
    )
    CSV.write(path, df)

    if !isempty(buf.event_log)
        ev_path = replace(path, ".csv" => "_events.csv")
        ev_df   = DataFrame(buf.event_log)
        CSV.write(ev_path, ev_df)
    end
end

function export_snapshot(world::World, state::SimState, path::String)
    h, w = world.height, world.width
    rows = Vector{NamedTuple}(undef, h * w)
    idx = 1
    for i in 1:h, j in 1:w
        c = world.cells[i, j]
        rows[idx] = (
            row         = i,
            col         = j,
            temperature = c.temperature,
            water       = c.water,
            biomass     = c.biomass,
            elevation   = c.elevation,
            nutrients   = c.nutrients,
            flood_depth = c.flood_depth,
            tick        = state.tick,
        )
        idx += 1
    end
    CSV.write(path, DataFrame(rows))
end

end
