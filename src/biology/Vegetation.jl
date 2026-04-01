module Vegetation

using ..Types
using ..WorldModule

export update_vegetation!

@inline function water_stress(water::Float64, threshold::Float64)::Float64
    water < threshold && return 0.0
    return min(1.0, (water - threshold) / 0.25)
end

@inline function temp_tolerance(temp::Float64, t_opt::Float64, t_sigma::Float64)::Float64
    return exp(-((temp - t_opt)^2) / (2.0 * t_sigma^2))
end

@inline function nutrient_factor(nutrients::Float64)::Float64
    # Growth scales with soil fertility: minimum 30% even on depleted soils
    return 0.30 + 0.70 * nutrients
end

function update_vegetation!(world::World, state::SimState, config::SimConfig)
    h, w = world.height, world.width
    bdelta = world.biomass_delta
    ndelta = world.nutrient_delta
    fill!(bdelta, 0.0)
    fill!(ndelta, 0.0)

    r   = config.growth_rate
    K   = config.carrying_capacity
    dr  = config.death_rate
    dec = config.decomp_rate

    # Wind-enhanced seed dispersal radius (1 extra cell at wind_speed > 0.5)
    seed_radius = config.wind_speed > 0.5 ? 2 : 1

    @inbounds for i in 1:h, j in 1:w
        cell = world.cells[i, j]
        B    = cell.biomass

        ws  = water_stress(cell.water, config.water_threshold)
        tt  = temp_tolerance(cell.temperature, config.temp_opt, config.temp_sigma)
        nf  = nutrient_factor(cell.nutrients)

        # Flood stress: prolonged flooding suffocates roots
        flood_stress = cell.flood_depth > 0.0 ?
            min(1.0, cell.flood_depth * 2.0) : 0.0
        effective_ws = ws * (1.0 - 0.8 * flood_stress)

        if B > 0.0
            growth = r * B * (1.0 - B / K) * effective_ws * tt * nf
            death  = dr * B * (1.0 - effective_ws * tt)

            bdelta[i, j] += growth - death

            # Nutrients consumed by growing plants
            ndelta[i, j] -= growth * 0.08

            # Decomposition: dying biomass becomes soil nutrients
            ndelta[i, j] += death * dec

            # Seed dispersal boosted by wind
            if B > config.colonization_threshold
                seed = 0.005 * (B - config.colonization_threshold) *
                       (1.0 + 0.5 * config.wind_speed)
                for di in -seed_radius:seed_radius, dj in -seed_radius:seed_radius
                    (di == 0 && dj == 0) && continue
                    ni = clamp(i + di, 1, h)
                    nj = clamp(j + dj, 1, w)
                    nc = world.cells[ni, nj]
                    bdelta[ni, nj] += seed * water_stress(nc.water, config.water_threshold)
                end
            end
        else
            # Bare soil: slower colonization from nutrients already present
            if cell.nutrients > 0.3 && cell.water > config.water_threshold * 2
                bdelta[i, j] += 0.0002 * cell.nutrients
            end
        end

        # Nutrient diffusion from neighboring cells
        for (ni, nj) in ((i-1,j),(i+1,j),(i,j-1),(i,j+1))
            (ni < 1 || ni > h || nj < 1 || nj > w) && continue
            diff = (world.cells[ni,nj].nutrients - cell.nutrients) * config.nutrient_diffusion
            ndelta[i, j] += diff
        end

        # Rain deposits trace nutrients (atmospheric deposition)
        if rand() < config.rain_probability * 0.5
            ndelta[i, j] += 0.002
        end

        # Nutrient leaching by rain/water movement
        ndelta[i, j] -= cell.nutrients * config.nutrient_leach_rate * cell.water
    end

    @inbounds for i in 1:h, j in 1:w
        cell = world.cells[i, j]

        cell.biomass   = clamp(cell.biomass   + bdelta[i, j], 0.0, K)
        cell.nutrients = clamp(cell.nutrients + ndelta[i, j], 0.0, 1.0)

        # Frost kills vegetation below -10 °C
        if cell.temperature < -10.0
            frost_stress = (-10.0 - cell.temperature) / 30.0
            cell.biomass   *= (1.0 - 0.003 * frost_stress)
            # Frost-killed biomass partially returns to soil as organic matter
            cell.nutrients  = min(1.0, cell.nutrients + 0.001 * frost_stress)
        end

        # Flood damage: prolonged flooding rots roots
        if cell.flood_depth > 0.05
            damage = config.flood_veg_damage * min(1.0, cell.flood_depth * 3.0)
            lost   = cell.biomass * damage
            cell.biomass   = max(0.0, cell.biomass - lost)
            cell.nutrients = min(1.0, cell.nutrients + lost * 0.3)
        end
    end
end

end
