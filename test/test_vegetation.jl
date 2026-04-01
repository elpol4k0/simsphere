@testset "Vegetation" begin
    config = SimConfig(width=10, height=10,
                       rain_probability=0.5, base_temp=18.0)
    world  = create_world(config)
    state  = SimState()

    for i in 1:world.height, j in 1:world.width
        world.cells[i, j].biomass = 0.1
        world.cells[i, j].water   = 0.5
    end

    biomass_before = sum(c.biomass for c in world.cells)
    for _ in 1:100
        tick!(world, state, config)
    end
    biomass_after = sum(c.biomass for c in world.cells)
    @test biomass_after > biomass_before

    for i in 1:world.height, j in 1:world.width
        @test 0.0 <= world.cells[i, j].biomass <= config.carrying_capacity
    end

    config_dry = SimConfig(width=10, height=10,
                           rain_probability=0.0, evaporation_rate=0.1)
    world_dry  = create_world(config_dry)
    state_dry  = SimState()
    for i in 1:world_dry.height, j in 1:world_dry.width
        world_dry.cells[i, j].biomass = 0.5
        world_dry.cells[i, j].water   = 0.0
    end
    for _ in 1:200
        tick!(world_dry, state_dry, config_dry)
    end
    mean_biomass = sum(c.biomass for c in world_dry.cells) / (10*10)
    @test mean_biomass < 0.3
end
