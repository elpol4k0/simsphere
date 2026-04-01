@testset "Events" begin
    config = SimConfig(width=20, height=20)
    world  = create_world(config)
    state  = SimState()
    log    = EventLog()

    temp_before = sum(c.temperature for c in world.cells)
    trigger_event!(log, world, state, :heatwave; intensity=1.0, duration=10)
    temp_after = sum(c.temperature for c in world.cells)
    @test temp_after > temp_before

    water_before = sum(c.water for c in world.cells)
    trigger_event!(log, world, state, :storm; intensity=1.0, duration=5)
    water_after = sum(c.water for c in world.cells)
    @test water_after > water_before

    trigger_event!(log, world, state, :drought; intensity=1.0, duration=5)
    @test !isempty(log.history)

    @test length(active_summary(log)) == length(log.active)

    for _ in 1:20
        tick_events!(log, world, config, state)
        state.tick += 1
    end

    for c in world.cells
        @test isfinite(c.temperature)
        @test 0.0 <= c.water <= 1.0
    end
end
