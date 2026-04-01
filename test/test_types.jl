@testset "Types" begin
    config = SimConfig()
    world  = create_world(config)

    @test world.width  == config.width
    @test world.height == config.height
    @test size(world.cells) == (config.height, config.width)

    for i in 1:world.height, j in 1:world.width
        c = world.cells[i, j]
        @test isfinite(c.temperature)
        @test isfinite(c.water)
        @test isfinite(c.biomass)
        @test isfinite(c.elevation)
        @test c.elevation >= 0.0
        @test 0.0 <= c.water   <= 1.0
        @test 0.0 <= c.biomass <= 1.0
    end

    state = SimState()
    @test state.tick == 0
    @test state.season == :spring
end
