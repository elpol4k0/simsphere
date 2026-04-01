@testset "Export" begin

    config = SimConfig(width=10, height=10)
    world  = create_world(config)
    state  = SimState()
    model  = create_animal_model(world, config; n_herbivores=5, n_carnivores=2)
    log    = EventLog()

    buf = TimeSeriesBuffer()
    for _ in 1:10
        tick!(world, state, config)
        step_animals!(model, state)
    end
    record_tick!(buf, world, state, model, log)

    @test length(buf.ticks) == 1
    @test length(buf.mean_biomass) == 1
    @test isfinite(buf.mean_temp[1])

    tmp_ts = tempname() * ".csv"
    flush_timeseries!(buf, tmp_ts)
    @test isfile(tmp_ts)
    df_ts = CSV.read(tmp_ts, DataFrames.DataFrame)
    @test nrow(df_ts) == 1
    @test "mean_biomass" in names(df_ts)
    rm(tmp_ts)

    tmp_snap = tempname() * ".csv"
    export_snapshot(world, state, tmp_snap)
    @test isfile(tmp_snap)
    df_snap = CSV.read(tmp_snap, DataFrames.DataFrame)
    @test nrow(df_snap) == 10 * 10
    @test "biomass" in names(df_snap)
    rm(tmp_snap)
end
