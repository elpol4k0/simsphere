module Types

export Cell, World, SimConfig, SimState

mutable struct Cell
    temperature::Float64
    water::Float64
    biomass::Float64
    elevation::Float64
    nutrients::Float64    # soil fertility / nitrogen  (0 = depleted, 1 = rich)
    flood_depth::Float64  # excess water above saturation (0 = no flood, >0 = flooded)
end

struct World
    cells::Matrix{Cell}
    width::Int
    height::Int
    water_delta::Matrix{Float64}
    biomass_delta::Matrix{Float64}
    nutrient_delta::Matrix{Float64}
end

Base.@kwdef mutable struct SimConfig
    width::Int  = 100
    height::Int = 100

    # Climate
    base_temp::Float64               = 15.0
    temp_amplitude_daily::Float64    = 8.0
    temp_amplitude_seasonal::Float64 = 15.0
    lapse_rate::Float64              = 6.5

    # Hydrology
    rain_probability::Float64  = 0.02
    rain_amount::Float64       = 0.3    # base water per rain event
    rain_intensity::Float64    = 1.0    # multiplier (1=normal, 3=heavy monsoon)
    evaporation_rate::Float64  = 0.005
    water_diffusion::Float64   = 0.01
    wind_speed::Float64        = 0.3    # 0–1, boosts evaporation and seed dispersal

    # Flooding
    flood_threshold::Float64   = 0.85   # water level where flooding begins
    flood_drain_rate::Float64  = 0.04   # flood drains this fraction per tick
    flood_veg_damage::Float64  = 0.015  # vegetation damage per tick while flooded

    # Vegetation
    growth_rate::Float64            = 0.05
    carrying_capacity::Float64      = 1.0
    water_threshold::Float64        = 0.05
    temp_opt::Float64               = 18.0
    temp_sigma::Float64             = 12.0
    death_rate::Float64             = 0.01
    colonization_threshold::Float64 = 0.6

    # Soil & Nutrients
    base_nutrients::Float64    = 0.5    # initial soil fertility
    decomp_rate::Float64       = 0.008  # dead biomass → nutrients per tick
    nutrient_diffusion::Float64= 0.003  # nutrient flow between cells
    nutrient_leach_rate::Float64= 0.001 # nutrients lost to drainage per tick

    # Fauna disease factors (set by Events, read by Animals)
    disease_herb_factor::Float64 = 0.0
    disease_carn_factor::Float64 = 0.0

    # Simulation timing
    ticks_per_day::Int   = 24
    ticks_per_year::Int  = 8760
    ticks_per_frame::Int = 12

    max_herbivores::Int = 300
    max_carnivores::Int = 80
end

mutable struct SimState
    tick::Int
    day::Int
    year::Int
    season::Symbol
end

SimState() = SimState(0, 0, 0, :spring)

end
