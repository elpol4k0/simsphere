module SimLoop

using ..Types
using ..Temperature
using ..Water
using ..Vegetation

export tick!, run_simulation!

function tick!(world::World, state::SimState, config::SimConfig)
    update_temperature!(world, state, config)
    update_water!(world, state, config)
    update_vegetation!(world, state, config)

    state.tick  += 1
    state.day    = state.tick ÷ config.ticks_per_day
    state.year   = state.tick ÷ config.ticks_per_year
    state.season = _season(state.tick, config.ticks_per_year)
end

function run_simulation!(world::World, state::SimState, config::SimConfig;
                         n_ticks::Int = config.ticks_per_year,
                         callback = nothing,
                         callback_interval::Int = config.ticks_per_frame)
    for i in 1:n_ticks
        tick!(world, state, config)
        if callback !== nothing && i % callback_interval == 0
            callback(world, state)
        end
    end
end

function _season(tick::Int, tpy::Int)::Symbol
    frac = (tick % tpy) / tpy
    frac < 0.25 && return :spring
    frac < 0.50 && return :summer
    frac < 0.75 && return :autumn
    return :winter
end

function world_stats(world::World)
    n          = world.height * world.width
    mean_t     = sum(c.temperature for c in world.cells) / n
    mean_w     = sum(c.water       for c in world.cells) / n
    mean_b     = sum(c.biomass     for c in world.cells) / n
    mean_n     = sum(c.nutrients   for c in world.cells) / n
    n_flooded  = count(c -> c.flood_depth > 0.05,       world.cells)
    return (mean_temp=mean_t, mean_water=mean_w, mean_biomass=mean_b,
            mean_nutrients=mean_n, n_flooded=n_flooded)
end

end
