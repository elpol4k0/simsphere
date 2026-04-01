@testset "Water" begin
    config = SimConfig(width=20, height=20, rain_probability=0.0)
    world  = create_world(config)
    state  = SimState()

    total_before = sum(c.water for c in world.cells)
    for _ in 1:50
        tick!(world, state, config)
    end
    total_after = sum(c.water for c in world.cells)
    @test total_after < total_before

    for i in 1:world.height, j in 1:world.width
        c = world.cells[i, j]
        @test 0.0 <= c.water <= 1.0
    end

    config2 = SimConfig(width=20, height=20, rain_probability=1.0, rain_amount=0.5)
    world2  = create_world(config2)
    state2  = SimState()
    for i in 1:world2.height, j in 1:world2.width
        world2.cells[i, j].water = 0.0
    end
    tick!(world2, state2, config2)
    @test any(c.water > 0.0 for c in world2.cells)
end
