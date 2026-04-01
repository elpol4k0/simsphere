module WorldModule

using ..Types

export create_world, neighbors, biome_classify

function create_world(config::SimConfig)::World
    w, h = config.width, config.height

    elevation = zeros(Float64, h, w)
    for i in 1:h, j in 1:w
        ni = (i - 1) / (h - 1)
        nj = (j - 1) / (w - 1)
        elevation[i, j] = (
            800.0 * (1 - abs(2*ni - 1)) * (1 - abs(2*nj - 1))
            + 400.0 * cos(2π * ni * 2.0) * cos(2π * nj * 1.5)
            + 200.0 * cos(4π * ni + 0.7) * cos(3π * nj + 1.1)
            + 50.0  * (2*rand() - 1)
        )
        elevation[i, j] = max(0.0, elevation[i, j])
    end

    for _ in 1:2
        smooth = copy(elevation)
        for i in 2:h-1, j in 2:w-1
            smooth[i,j] = mean9(elevation, i, j)
        end
        elevation = smooth
    end

    cells = Matrix{Cell}(undef, h, w)
    for i in 1:h, j in 1:w
        elev_norm      = elevation[i, j] / 1000.0
        init_water     = clamp(0.3 * rand() + 0.1 - 0.15 * elev_norm, 0.05, 0.95)
        init_biomass   = clamp(0.2 * rand() + 0.05 * init_water, 0.0, 0.8)
        init_nutrients = clamp(config.base_nutrients * (0.6 + 0.8 * rand()), 0.0, 1.0)

        cells[i, j] = Cell(
            config.base_temp,
            init_water,
            init_biomass,
            elevation[i, j],
            init_nutrients,
            0.0,
        )
    end

    World(cells, w, h,
          zeros(Float64, h, w),
          zeros(Float64, h, w),
          zeros(Float64, h, w))
end

@inline function mean9(m, i, j)
    (m[i-1,j-1] + m[i-1,j] + m[i-1,j+1] +
     m[i,  j-1] + m[i,  j] + m[i,  j+1] +
     m[i+1,j-1] + m[i+1,j] + m[i+1,j+1]) / 9.0
end

function neighbors(world::World, i::Int, j::Int)
    result = Tuple{Int,Int}[]
    i > 1            && push!(result, (i-1, j))
    i < world.height && push!(result, (i+1, j))
    j > 1            && push!(result, (i, j-1))
    j < world.width  && push!(result, (i, j+1))
    result
end

function biome_classify(cell::Cell)::Symbol
    t = cell.temperature
    w = cell.water
    b = cell.biomass
    cell.flood_depth > 0.1 && return :flooded
    t < 2.0              && return :tundra
    w < 0.1 && b < 0.1  && return :desert
    b > 0.6              && return :forest
    b > 0.2              && return :grassland
    w > 0.5              && return :wetland
    return :shrubland
end

end
