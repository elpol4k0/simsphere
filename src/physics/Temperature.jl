module Temperature

using ..Types

export update_temperature!

const TWO_PI = 2.0 * π

function update_temperature!(world::World, state::SimState, config::SimConfig)
    tick = state.tick
    tpd  = config.ticks_per_day
    tpy  = config.ticks_per_year

    daily_phase    = TWO_PI * (tick % tpd) / tpd - π/2
    daily_offset   = config.temp_amplitude_daily * sin(daily_phase)

    seasonal_phase  = TWO_PI * (tick % tpy) / tpy - π/2
    seasonal_offset = config.temp_amplitude_seasonal * sin(seasonal_phase)

    base = config.base_temp + daily_offset + seasonal_offset

    @inbounds for i in 1:world.height, j in 1:world.width
        cell = world.cells[i, j]
        lapse = -(cell.elevation / 1000.0) * config.lapse_rate
        cell.temperature = base + lapse
    end
end

function current_season(tick::Int, tpy::Int)::Symbol
    frac = (tick % tpy) / tpy
    if frac < 0.25
        return :spring
    elseif frac < 0.5
        return :summer
    elseif frac < 0.75
        return :autumn
    else
        return :winter
    end
end

end
