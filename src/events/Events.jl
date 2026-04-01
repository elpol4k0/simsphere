module Events

using ..Types

export ExtremeEvent, EventLog, apply_event!, tick_events!, trigger_event!, active_summary, log_entry

struct ExtremeEvent
    type::Symbol
    intensity::Float64
    duration_ticks::Int
    region::Union{Nothing, Tuple{Int,Int,Int,Int}}
end

mutable struct ActiveEvent
    event::ExtremeEvent
    ticks_remaining::Int
end

mutable struct EventLog
    active::Vector{ActiveEvent}
    history::Vector{NamedTuple}
    base_rates::Dict{Symbol, Float64}
end

function EventLog(; rates::Dict{Symbol,Float64} = default_rates())
    EventLog(ActiveEvent[], NamedTuple[], rates)
end

function default_rates()
    Dict(
        :heatwave  => 1.0 / (3  * 8760),
        :frost     => 1.0 / (4  * 8760),
        :drought   => 1.0 / (5  * 8760),
        :storm     => 1.0 / (2  * 8760),
        :wildfire  => 1.0 / (10 * 8760),
        :flood     => 1.0 / (4  * 8760),
        :disease_h => 1.0 / (7  * 8760),
        :disease_c => 1.0 / (9  * 8760),
    )
end

function log_entry(log::EventLog, tick::Int, type::Symbol, intensity::Float64)
    push!(log.history, (tick=tick, type=type, intensity=intensity))
end

function apply_event!(world::World, config::SimConfig, ev::ExtremeEvent)
    h, w = world.height, world.width

    i1, i2, j1, j2 = if ev.region === nothing
        1, h, 1, w
    else
        ev.region[1], ev.region[2], ev.region[3], ev.region[4]
    end
    i1 = clamp(i1, 1, h); i2 = clamp(i2, 1, h)
    j1 = clamp(j1, 1, w); j2 = clamp(j2, 1, w)

    @inbounds for i in i1:i2, j in j1:j2
        cell = world.cells[i, j]

        if ev.type == :heatwave
            cell.temperature += ev.intensity * 15.0

        elseif ev.type == :frost
            cell.temperature -= ev.intensity * 20.0
            if cell.temperature < 0.0
                cell.biomass *= max(0.0, 1.0 - 0.01 * ev.intensity)
            end

        elseif ev.type == :drought
            cell.water = max(0.0, cell.water - ev.intensity * 0.02)

        elseif ev.type == :storm
            # Heavy rain: pushes water up, may cause flooding
            cell.water = min(1.5, cell.water + ev.intensity * 0.3)
            if cell.water > config.flood_threshold
                cell.flood_depth = min(2.0,
                    cell.flood_depth + (cell.water - config.flood_threshold))
                cell.water = config.flood_threshold
            end

        elseif ev.type == :wildfire
            # Fire burns biomass, releases heat and nutrients
            if cell.biomass > 0.1 && rand() < ev.intensity * 0.4
                burned = cell.biomass * ev.intensity * 0.12
                cell.biomass    = max(0.0, cell.biomass - burned)
                cell.nutrients  = min(1.0, cell.nutrients + burned * 0.5)
                cell.temperature += ev.intensity * 4.0
                # Fire dries out the cell
                cell.water = max(0.0, cell.water - 0.02 * ev.intensity)
            end

        elseif ev.type == :flood
            # Flash flood event: forces rapid water accumulation
            added = ev.intensity * 0.08
            new_w = cell.water + added
            if new_w > config.flood_threshold
                cell.flood_depth = min(2.0,
                    cell.flood_depth + (new_w - config.flood_threshold))
                cell.water = config.flood_threshold
            else
                cell.water = new_w
            end

        elseif ev.type == :disease_h
            # Disease affects herbivores via config flag — handled in Animals.jl
            # (no direct cell modification needed)

        elseif ev.type == :disease_c
            # Disease affects carnivores via config flag — handled in Animals.jl
        end
    end
end

function tick_events!(log::EventLog, world::World, config::SimConfig, state::SimState)
    # Spontaneous events (Poisson process)
    for (type, rate) in log.base_rates
        if rand() < rate
            intensity = 0.3 + 0.7 * rand()
            duration  = rand(24:24*14)
            ev = ExtremeEvent(type, intensity, duration, nothing)
            push!(log.active, ActiveEvent(ev, duration))
            log_entry(log, state.tick, type, intensity)
        end
    end

    # Reset disease factors — will be re-derived from active events below
    config.disease_herb_factor = 0.0
    config.disease_carn_factor = 0.0

    for ae in log.active
        apply_event!(world, config, ae.event)
        ae.ticks_remaining -= 1

        # Accumulate disease pressure from all active disease events
        if ae.event.type == :disease_h
            config.disease_herb_factor += ae.event.intensity * 0.0025
        elseif ae.event.type == :disease_c
            config.disease_carn_factor += ae.event.intensity * 0.0025
        end
    end

    filter!(ae -> ae.ticks_remaining > 0, log.active)
end

function trigger_event!(log::EventLog, world::World, state::SimState,
                        type::Symbol; intensity::Float64 = 0.8,
                        duration::Int = 24*7,
                        region = nothing)
    ev = ExtremeEvent(type, intensity, duration, region)
    push!(log.active, ActiveEvent(ev, duration))
    log_entry(log, state.tick, type, intensity)
end

function active_summary(log::EventLog)::Vector{String}
    [string(ae.event.type, " (", ae.ticks_remaining, "t)") for ae in log.active]
end

end
