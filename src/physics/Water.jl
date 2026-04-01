module Water

using ..Types
using ..WorldModule

export update_water!

function update_water!(world::World, state::SimState, config::SimConfig)
    h, w = world.height, world.width
    delta = world.water_delta
    fill!(delta, 0.0)

    wind_evap_boost = 1.0 + 0.6 * config.wind_speed

    @inbounds for i in 1:h, j in 1:w
        cell = world.cells[i, j]

        # Evaporation: temperature-dependent + wind boost
        evap_factor = wind_evap_boost * (1.0 + 0.02 * max(0.0, cell.temperature - 20.0))
        # Flooded cells evaporate faster from the flood surface
        evap_source = cell.water + cell.flood_depth * 0.5
        evap = config.evaporation_rate * evap_factor * evap_source
        delta[i, j] -= evap

        # Downhill water flow (gravity-driven)
        elev_c = cell.elevation
        w_c    = cell.water
        @inline function try_flow(ni::Int, nj::Int)
            ncell = world.cells[ni, nj]
            elev_diff = elev_c - ncell.elevation
            if elev_diff > 0.0
                flow = config.water_diffusion * w_c * min(1.0, elev_diff / 100.0)
                delta[i,  j]  -= flow
                delta[ni, nj] += flow
            end
        end
        i > 1            && try_flow(i-1, j)
        i < world.height && try_flow(i+1, j)
        j > 1            && try_flow(i, j-1)
        j < world.width  && try_flow(i, j+1)
    end

    rain_per_event = config.rain_amount * config.rain_intensity

    @inbounds for i in 1:h, j in 1:w
        cell = world.cells[i, j]

        rain = 0.0
        if rand() < config.rain_probability
            rain = rain_per_event * (0.5 + rand())
        end

        new_water = cell.water + delta[i, j] + rain

        # Flooding: water above flood_threshold overflows into flood_depth
        if new_water > config.flood_threshold
            cell.flood_depth = min(2.0, cell.flood_depth + (new_water - config.flood_threshold))
            cell.water = config.flood_threshold
        else
            cell.water = clamp(new_water, 0.0, config.flood_threshold)
        end

        # Flood drains over time (percolation + runoff)
        if cell.flood_depth > 0.0
            drain = config.flood_drain_rate * cell.flood_depth
            cell.flood_depth = max(0.0, cell.flood_depth - drain)
        end
    end
end

end
