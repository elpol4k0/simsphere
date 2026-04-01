module Scenarios

using TOML
using ..Types
using ..Events

export apply_scenario!, load_config, SCENARIOS

const SCENARIOS = Dict{Symbol, NamedTuple}(
    :normal => (
        base_temp               = 15.0,
        temp_amplitude_daily    = 8.0,
        temp_amplitude_seasonal = 15.0,
        rain_probability        = 0.02,
        evaporation_rate        = 0.005,
        growth_rate             = 0.05,
    ),
    :drought => (
        base_temp               = 28.0,
        temp_amplitude_daily    = 12.0,
        temp_amplitude_seasonal = 10.0,
        rain_probability        = 0.003,
        evaporation_rate        = 0.02,
        growth_rate             = 0.03,
    ),
    :ice_age => (
        base_temp               = -8.0,
        temp_amplitude_daily    = 5.0,
        temp_amplitude_seasonal = 25.0,
        rain_probability        = 0.015,
        evaporation_rate        = 0.003,
        growth_rate             = 0.02,
    ),
    :tropics => (
        base_temp               = 28.0,
        temp_amplitude_daily    = 4.0,
        temp_amplitude_seasonal = 5.0,
        rain_probability        = 0.07,
        evaporation_rate        = 0.01,
        growth_rate             = 0.12,
    ),
    :climate_change => (
        base_temp               = 18.0,
        temp_amplitude_daily    = 9.0,
        temp_amplitude_seasonal = 18.0,
        rain_probability        = 0.016,
        evaporation_rate        = 0.008,
        growth_rate             = 0.04,
    ),
)

function apply_scenario!(config::SimConfig, scenario::Symbol)
    haskey(SCENARIOS, scenario) || error("Unknown scenario: $scenario")
    s = SCENARIOS[scenario]
    config.base_temp               = s.base_temp
    config.temp_amplitude_daily    = s.temp_amplitude_daily
    config.temp_amplitude_seasonal = s.temp_amplitude_seasonal
    config.rain_probability        = s.rain_probability
    config.evaporation_rate        = s.evaporation_rate
    config.growth_rate             = s.growth_rate
end

function load_config(path::String)::Tuple{SimConfig, Int, Int}
    isfile(path) || error("Config file not found: $path")
    t = TOML.parsefile(path)

    g  = get(t, "grid",       Dict())
    cl = get(t, "climate",    Dict())
    wa = get(t, "water",      Dict())
    ve = get(t, "vegetation", Dict())
    si = get(t, "simulation", Dict())
    an = get(t, "animals",    Dict())

    cfg = SimConfig(
        width                   = get(g,  "width",                   100),
        height                  = get(g,  "height",                  100),
        base_temp               = get(cl, "base_temp",               15.0),
        temp_amplitude_daily    = get(cl, "temp_amplitude_daily",    8.0),
        temp_amplitude_seasonal = get(cl, "temp_amplitude_seasonal", 15.0),
        lapse_rate              = get(cl, "lapse_rate",              6.5),
        rain_probability        = get(wa, "rain_probability",        0.02),
        rain_amount             = get(wa, "rain_amount",             0.3),
        evaporation_rate        = get(wa, "evaporation_rate",        0.005),
        water_diffusion         = get(wa, "water_diffusion",         0.01),
        growth_rate             = get(ve, "growth_rate",             0.05),
        carrying_capacity       = get(ve, "carrying_capacity",       1.0),
        water_threshold         = get(ve, "water_threshold",         0.05),
        temp_opt                = get(ve, "temp_opt",                18.0),
        temp_sigma              = get(ve, "temp_sigma",              12.0),
        death_rate              = get(ve, "death_rate",              0.01),
        colonization_threshold  = get(ve, "colonization_threshold",  0.6),
        ticks_per_day           = get(si, "ticks_per_day",           24),
        ticks_per_year          = get(si, "ticks_per_year",          8760),
        ticks_per_frame         = get(si, "ticks_per_frame",         12),
    )

    n_herbivores = get(an, "n_herbivores", 60)
    n_carnivores = get(an, "n_carnivores", 15)

    return cfg, n_herbivores, n_carnivores
end

end
