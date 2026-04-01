using GLMakie

include("src/Simsphere.jl")
using .Simsphere

println("SIMSPHERE")

if !isempty(ARGS) && isfile(ARGS[1])
    println("Lade Config: $(ARGS[1])")
    config, n_herb, n_carn = load_config(ARGS[1])
    setup = (config=config, n_herbivores=n_herb, n_carnivores=n_carn, cancelled=false)
else
    println("Setup-Fenster wird geoeffnet...")
    setup = show_setup_gui()
end

if setup.cancelled
    println("Simulation abgebrochen.")
    exit(0)
end

config = setup.config
println("Konfiguration:")
println("  Grid:       $(config.width) x $(config.height)")
println("  Temperatur: $(config.base_temp) C")
println("  Regen:      $(config.rain_probability)")
println("  Herbivoren: $(setup.n_herbivores)")
println("  Karnivoren: $(setup.n_carnivores)")

println("Welt wird generiert...")
world = create_world(config)
state = SimState()
log   = EventLog()
buf   = TimeSeriesBuffer()

model = create_animal_model(world, config;
                            n_herbivores = setup.n_herbivores,
                            n_carnivores = setup.n_carnivores)

println("Agenten: $(length(model.agents))")
println("Simulation laeuft.")

fig, timer = launch_visualization!(world, state, config, model, log, buf)

wait(fig.scene)
close(timer)

println("Simulation beendet:")
println("  Ticks:      $(state.tick)")
println("  Jahre:      $(state.year)")
println("  Geburten:   $(model.births)")
println("  Tode:       $(model.deaths)")
println("  Herbivoren: $(model.n_herbivores)")
println("  Karnivoren: $(model.n_carnivores)")

if state.tick > 0
    mkpath("data/output")
    out = "data/output/final_timeseries.csv"
    flush_timeseries!(buf, out)
    println("Zeitreihe gespeichert: $out")
end
