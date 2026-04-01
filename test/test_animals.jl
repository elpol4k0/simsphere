@testset "Animals" begin
    config = SimConfig(width=40, height=40)
    world  = create_world(config)
    state  = SimState()
    model  = create_animal_model(world, config; n_herbivores=20, n_carnivores=5)

    @test length(model.agents) == 25
    @test model.n_herbivores == 20
    @test model.n_carnivores == 5

    for a in model.agents
        @test a.pos[1] in 1:world.height
        @test a.pos[2] in 1:world.width
        @test 0.0 <= a.energy <= 1.0
        @test a.alive
    end

    for _ in 1:500
        tick!(world, state, config)
        step_animals!(model, state)
    end

    @test model.births >= 0
    @test model.deaths >= 0
    @test model.n_herbivores + model.n_carnivores == count(a -> a.alive, model.agents)

    for a in model.agents
        a.alive || continue
        @test a.pos[1] in 1:world.height
        @test a.pos[2] in 1:world.width
        @test 0.0 <= a.energy <= 1.0
        @test 0.0 <= a.hunger <= 1.0
        @test 0.0 <= a.thirst <= 1.0
    end
end
