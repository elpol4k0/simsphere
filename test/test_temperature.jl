@testset "Temperature" begin
    config = SimConfig(width=20, height=20)
    world  = create_world(config)
    state  = SimState()

    tpd = config.ticks_per_day
    tpy = config.ticks_per_year

    low_elev  = findfirst(c -> c.elevation < 50.0,   world.cells)
    high_elev = findfirst(c -> c.elevation > 400.0,  world.cells)

    if low_elev !== nothing && high_elev !== nothing
        tick!(world, state, config)
        li, lj = Tuple(low_elev)
        hi, hj = Tuple(high_elev)
        @test world.cells[li, lj].temperature > world.cells[hi, hj].temperature
    end

    state_noon = SimState(tpd ÷ 2, 0, 0, :spring)
    world_noon = create_world(config)
    tick!(world_noon, state_noon, config)

    state_night = SimState(0, 0, 0, :spring)
    world_night = create_world(config)
    tick!(world_night, state_night, config)

    mean_noon  = sum(c.temperature for c in world_noon.cells)
    mean_night = sum(c.temperature for c in world_night.cells)
    @test mean_noon > mean_night

    state_summer = SimState(tpy ÷ 2, 0, 0, :summer)
    world_summer = create_world(config)
    tick!(world_summer, state_summer, config)

    state_winter = SimState(0, 0, 0, :winter)
    world_winter = create_world(config)
    tick!(world_winter, state_winter, config)

    mean_summer = sum(c.temperature for c in world_summer.cells)
    mean_winter = sum(c.temperature for c in world_winter.cells)
    @test mean_summer > mean_winter
end
