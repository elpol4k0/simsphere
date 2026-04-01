module Renderer

using GLMakie
using Statistics: mean
using ..Types
using ..WorldModule
using ..SimLoop
using ..Animals
using ..Events
using ..Scenarios
using ..Export

import ..Events: trigger_event!, active_summary
import ..Animals: random_good_pos

export launch_visualization!

const BG      = RGBf(0.07, 0.07, 0.10)
const BG_AXIS = RGBf(0.04, 0.04, 0.06)
const C_TEXT  = RGBf(0.85, 0.85, 0.90)
const C_DIM   = RGBf(0.50, 0.50, 0.56)
const C_ACCENT= RGBf(0.36, 0.56, 0.78)
const C_BTN   = RGBf(0.16, 0.16, 0.24)
const C_BTN_P = RGBf(0.20, 0.34, 0.52)
const C_GRID  = RGBf(0.14, 0.14, 0.20)
const C_SEC   = RGBf(0.55, 0.65, 0.82)

function make_axis(fig, pos; title="", xlabel="", ylabel="")
    Axis(fig[pos...],
         title            = title,  titlecolor=C_TEXT,  titlesize=12,
         backgroundcolor  = BG_AXIS,
         xlabel=xlabel, ylabel=ylabel,
         xlabelcolor=C_DIM,  ylabelcolor=C_DIM,
         xlabelsize=9,       ylabelsize=9,
         xticklabelcolor=C_DIM, yticklabelcolor=C_DIM,
         xticklabelsize=8,   yticklabelsize=8,
         xtickcolor=C_DIM,   ytickcolor=C_DIM,
         xgridcolor=C_GRID,  ygridcolor=C_GRID,
         spinewidth=0.6,
         topspinecolor=C_GRID, bottomspinecolor=C_DIM,
         leftspinecolor=C_DIM, rightspinecolor=C_GRID)
end

function sec(parent, pos, text)
    Label(parent[pos...], text, fontsize=12, color=C_SEC, halign=:left, font=:bold)
end

function cbtn(parent, pos, text; primary=false)
    Button(parent[pos...], label=text,
           buttoncolor = primary ? C_BTN_P : C_BTN,
           labelcolor  = C_TEXT, fontsize=11)
end

function extract_layer!(out::Matrix{Float64}, world::World, field::Symbol)
    @inbounds for i in 1:world.height, j in 1:world.width
        out[i, j] = getfield(world.cells[i, j], field)
    end
end

function launch_visualization!(world::World, state::SimState, config::SimConfig,
                               model::AgentModel,
                               log::EventLog        = EventLog(),
                               buf::TimeSeriesBuffer = TimeSeriesBuffer())
    GLMakie.activate!()

    h, w = world.height, world.width

    buf_temp    = zeros(Float64, h, w)
    buf_water   = zeros(Float64, h, w)
    buf_biomass = zeros(Float64, h, w)
    buf_flood   = zeros(Float64, h, w)
    buf_nuts    = zeros(Float64, h, w)
    buf_elev    = zeros(Float64, h, w)

    extract_layer!(buf_temp,    world, :temperature)
    extract_layer!(buf_water,   world, :water)
    extract_layer!(buf_biomass, world, :biomass)
    extract_layer!(buf_flood,   world, :flood_depth)
    extract_layer!(buf_nuts,    world, :nutrients)
    extract_layer!(buf_elev,    world, :elevation)

    obs_temp    = Observable(copy(buf_temp))
    obs_water   = Observable(copy(buf_water))
    obs_biomass = Observable(copy(buf_biomass))
    obs_flood   = Observable(copy(buf_flood))
    obs_nuts    = Observable(copy(buf_nuts))

    obs_status  = Observable("tick 0  |  year 0  |  spring  |  T: -- °C  |  flooded: 0 cells")
    obs_pop     = Observable("Herbivores: 0   |   Carnivores: 0")
    obs_events  = Observable("—  no active events")

    # Time-series: simple growing vectors, trimmed to max_ts points
    max_ts = 800
    ts_x      = Float32[]
    ts_bio    = Float32[]
    ts_wat    = Float32[]
    ts_tnorm  = Float32[]
    ts_nuts   = Float32[]
    ts_herbs  = Float32[]
    ts_carns  = Float32[]

    obs_bio    = Observable(Point2f[])
    obs_wat    = Observable(Point2f[])
    obs_tnorm  = Observable(Point2f[])
    obs_nuts_ts = Observable(Point2f[])
    obs_herbs  = Observable(Point2f[])
    obs_carns  = Observable(Point2f[])

    # ── Figure  ──────────────────────────────────────────────────────────────────
    # Layout: col 1 = 1/3 (menu), col 2-3 = 2/3 (viz split equally)
    fig = Figure(size=(1860, 1040), backgroundcolor=BG)

    ctrl = fig[1:6, 1] = GridLayout()

    # Title bar (right side)
    Label(fig[1, 2:3], "SIMSPHERE  —  Coupled Ecosystem Simulator",
          fontsize=15, color=C_TEXT, font=:bold, halign=:left)

    # ── 4 spatial maps (2 × 2)  ──────────────────────────────────────────────────
    ax_temp  = make_axis(fig, (2, 2);
                         title  = "Surface Temperature",
                         xlabel = "x (grid column)",
                         ylabel = "y (grid row)")
    ax_wat   = make_axis(fig, (2, 3);
                         title  = "Soil Moisture  (0 = completely dry  →  1 = fully saturated)",
                         xlabel = "x (grid column)",
                         ylabel = "y (grid row)")
    ax_bio   = make_axis(fig, (3, 2);
                         title  = "Vegetation Cover  (0 = bare ground  →  1 = full canopy)",
                         xlabel = "x (grid column)",
                         ylabel = "y (grid row)")
    ax_fauna = make_axis(fig, (3, 3);
                         title  = "Animal Distribution  —  terrain background",
                         xlabel = "x (grid column)",
                         ylabel = "y (grid row)")

    for ax in (ax_temp, ax_wat, ax_bio, ax_fauna)
        hidedecorations!(ax, ticks=false, ticklabels=false, label=false)
    end

    # Temperature: Reverse(:RdBu) = blue (cold) → white (0 °C) → red (hot)
    hm_t = heatmap!(ax_temp, obs_temp,
                    colormap=Reverse(:RdBu), colorrange=(-20.0, 45.0))
    Colorbar(fig[2, 2][1, 2], hm_t,
             label="°C  —  blue = cold  ·  red = hot",
             labelcolor=C_DIM, tickcolor=C_DIM, ticklabelcolor=C_DIM,
             labelsize=9, ticklabelsize=8, width=12)

    # Soil moisture: white (dry) → deep blue (saturated) + orange flood overlay
    hm_w = heatmap!(ax_wat, obs_water,
                    colormap=:Blues_9, colorrange=(0.0, 1.0))
    # Flood overlay: transparent → vivid orange-red when flood_depth > 0
    heatmap!(ax_wat, obs_flood, colormap=cgrad([:transparent, :orangered]),
             colorrange=(0.001, 0.4))
    Colorbar(fig[2, 3][1, 2], hm_w,
             label="m³/m³  (0=dry · 1=sat.)  orange=flooded",
             labelcolor=C_DIM, tickcolor=C_DIM, ticklabelcolor=C_DIM,
             labelsize=9, ticklabelsize=8, width=12)

    # Vegetation: cream (bare) → dark green (full canopy)
    # Nutrients overlay: transparent → amber (rich soil)
    hm_b = heatmap!(ax_bio, obs_biomass,
                    colormap=:Greens_9, colorrange=(0.0, 1.0))
    heatmap!(ax_bio, obs_nuts, colormap=cgrad([:transparent, :darkorange]),
             colorrange=(0.1, 1.0))
    Colorbar(fig[3, 2][1, 2], hm_b,
             label="biomass (green)  +  soil nutrients (amber)",
             labelcolor=C_DIM, tickcolor=C_DIM, ticklabelcolor=C_DIM,
             labelsize=9, ticklabelsize=8, width=12)

    # Fauna map: static gray terrain + large vivid animal dots
    # (elevation does not change — pass the matrix directly, no Observable needed)
    heatmap!(ax_fauna, buf_elev, colormap=:grays, colorrange=(0.0, 1.0))

    herb_pos = Observable(Point2f[])
    carn_pos = Observable(Point2f[])

    # Herbivores: bright yellow-gold circles (large, clearly visible)
    scatter!(ax_fauna, herb_pos,
             color=RGBAf(0.96, 0.90, 0.18, 0.92), markersize=10,
             marker=:circle,    label="Herbivores  (grazers, prey)")
    # Carnivores: vivid orange-red upward triangles (larger)
    scatter!(ax_fauna, carn_pos,
             color=RGBAf(1.00, 0.22, 0.06, 1.00), markersize=15,
             marker=:utriangle, label="Carnivores  (predators)")

    axislegend(ax_fauna, position=:lt,
               backgroundcolor=RGBAf(0.03, 0.03, 0.05, 0.92),
               labelcolor=C_TEXT, framecolor=C_GRID, labelsize=11)

    # ── Time-series charts ────────────────────────────────────────────────────────
    ax_ts = make_axis(fig, (4, 2);
                      title   = "Abiotic State over Time  (all values normalized 0 – 1)",
                      xlabel  = "Simulation tick",
                      ylabel  = "Normalized mean  (0 – 1)")

    lines!(ax_ts, obs_bio,   color=RGBf(0.28, 0.72, 0.36), linewidth=2.0,
           label="Vegetation biomass  (0=bare · 1=full)")
    lines!(ax_ts, obs_wat,   color=RGBf(0.28, 0.52, 0.92), linewidth=2.0,
           label="Soil moisture  (0=dry · 1=saturated)")
    lines!(ax_ts, obs_nuts_ts, color=RGBf(0.82, 0.60, 0.12), linewidth=1.8,
           label="Soil nutrients  (0=depleted · 1=rich)")
    lines!(ax_ts, obs_tnorm, color=RGBf(0.92, 0.40, 0.28), linewidth=1.5,
           linestyle=:dash,  label="Temperature  (norm. −20 to 45 °C)")
    axislegend(ax_ts, position=:lt,
               backgroundcolor=RGBAf(0.03, 0.03, 0.05, 0.92),
               labelcolor=C_TEXT, framecolor=C_GRID, labelsize=10)

    ax_pop = make_axis(fig, (4, 3);
                       title   = "Animal Population  —  live agent counts",
                       xlabel  = "Simulation tick",
                       ylabel  = "Number of live agents")

    lines!(ax_pop, obs_herbs, color=RGBf(0.92, 0.88, 0.28), linewidth=2.5,
           label="Herbivores  (prey)")
    lines!(ax_pop, obs_carns, color=RGBf(1.00, 0.30, 0.14), linewidth=2.5,
           label="Carnivores  (predators)")
    axislegend(ax_pop, position=:lt,
               backgroundcolor=RGBAf(0.03, 0.03, 0.05, 0.92),
               labelcolor=C_TEXT, framecolor=C_GRID, labelsize=10)

    # Status bar
    Label(fig[5, 2:3], obs_status, color=C_DIM, fontsize=10, halign=:left)

    # Column widths: 1/3 menu, 1/3 viz-left, 1/3 viz-right
    colsize!(fig.layout, 1, Relative(0.42))
    colsize!(fig.layout, 2, Relative(0.29))
    colsize!(fig.layout, 3, Relative(0.29))
    rowsize!(fig.layout, 1, Fixed(34))
    rowsize!(fig.layout, 5, Fixed(26))
    rowgap!(fig.layout, 6)
    colgap!(fig.layout, 8)

    # ── Controls panel (left 1/3, spans all rows) ────────────────────────────────
    crow = 1

    Label(ctrl[crow, 1:2], "SIMSPHERE", fontsize=22, color=C_TEXT, font=:bold, halign=:left)
    crow += 1
    Label(ctrl[crow, 1:2], "Ecosystem Simulation", fontsize=12, color=C_DIM, halign=:left)
    crow += 1
    Label(ctrl[crow, 1:2], obs_pop, fontsize=13, color=C_TEXT, halign=:left)
    crow += 1

    sec(ctrl, (crow, 1:2), "PARAMETERS")
    crow += 1

    function make_sl(parent, r, lbl, rng, val, unit="")
        Label(parent[r, 1], lbl, color=C_TEXT, halign=:left, fontsize=12)
        sl = Slider(parent[r, 2], range=rng, startvalue=val,
                    color_active=C_ACCENT, color_active_dimmed=C_BTN)
        disp = isempty(unit) ?
            @lift("$(round($(sl.value), sigdigits=3))") :
            @lift("$(round($(sl.value), sigdigits=3))  $unit")
        Label(parent[r+1, 1:2], disp, color=C_DIM, halign=:left, fontsize=10)
        sl
    end

    sl_rain     = make_sl(ctrl, crow, "Rain probability",   0.001:0.001:0.1,   config.rain_probability,  "/tick")
    crow += 2
    sl_rain_int = make_sl(ctrl, crow, "Rain intensity",     0.1:0.05:5.0,      config.rain_intensity,    "× base")
    crow += 2
    sl_evap     = make_sl(ctrl, crow, "Evaporation rate",   0.001:0.001:0.05,  config.evaporation_rate,  "/tick")
    crow += 2
    sl_wind     = make_sl(ctrl, crow, "Wind speed",         0.0:0.05:1.0,      config.wind_speed,        "(0–1)")
    crow += 2
    sl_growth   = make_sl(ctrl, crow, "Vegetation growth",  0.01:0.01:0.3,     config.growth_rate)
    crow += 2
    sl_temp     = make_sl(ctrl, crow, "Base temperature",   -15.0:0.5:40.0,    config.base_temp,         "°C")
    crow += 2
    sl_speed    = make_sl(ctrl, crow, "Simulation speed",   1:1:150,            config.ticks_per_frame,   "ticks/frame")
    crow += 2

    on(sl_rain.value)     do v; config.rain_probability = v; end
    on(sl_rain_int.value) do v; config.rain_intensity   = v; end
    on(sl_evap.value)     do v; config.evaporation_rate = v; end
    on(sl_wind.value)     do v; config.wind_speed       = v; end
    on(sl_growth.value)   do v; config.growth_rate      = v; end
    on(sl_temp.value)     do v; config.base_temp        = v; end

    paused = Observable(false)
    btn_pause = Button(ctrl[crow, 1:2],
                       label       = @lift($paused ? "Resume" : "Pause"),
                       buttoncolor = C_BTN, labelcolor=C_TEXT, fontsize=13)
    on(btn_pause.clicks) do _; paused[] = !paused[]; end
    crow += 1

    sec(ctrl, (crow, 1:2), "CLIMATE SCENARIO")
    crow += 1
    btn_drought = cbtn(ctrl, (crow, 1), "Drought")
    btn_iceage  = cbtn(ctrl, (crow, 2), "Ice Age")
    crow += 1
    btn_tropic  = cbtn(ctrl, (crow, 1), "Tropics")
    btn_reset   = cbtn(ctrl, (crow, 2), "Reset / Default")
    crow += 1

    on(btn_drought.clicks) do _
        config.base_temp = 28.0; config.rain_probability = 0.003; config.evaporation_rate = 0.02
        set_close_to!(sl_temp, 28.0); set_close_to!(sl_rain, 0.003); set_close_to!(sl_evap, 0.02)
    end
    on(btn_iceage.clicks) do _
        config.base_temp = -8.0; config.rain_probability = 0.015; config.evaporation_rate = 0.003
        set_close_to!(sl_temp, -8.0); set_close_to!(sl_rain, 0.015)
    end
    on(btn_tropic.clicks) do _
        config.base_temp = 28.0; config.rain_probability = 0.07; config.evaporation_rate = 0.01
        set_close_to!(sl_temp, 28.0); set_close_to!(sl_rain, 0.07)
    end
    on(btn_reset.clicks) do _
        config.base_temp = 15.0; config.rain_probability = 0.02
        config.evaporation_rate = 0.005; config.growth_rate = 0.05
        set_close_to!(sl_temp, 15.0); set_close_to!(sl_rain, 0.02)
        set_close_to!(sl_evap, 0.005); set_close_to!(sl_growth, 0.05)
    end

    sec(ctrl, (crow, 1:2), "FAUNA INJECTION")
    crow += 1

    Label(ctrl[crow, 1], "Inject n agents", color=C_TEXT, halign=:left, fontsize=12)
    sl_add = Slider(ctrl[crow, 2], range=1:1:200, startvalue=10,
                    color_active=C_ACCENT, color_active_dimmed=C_BTN)
    crow += 1
    Label(ctrl[crow, 1:2], @lift("$($(sl_add.value)) agents per click"),
          color=C_DIM, halign=:left, fontsize=10)
    crow += 1

    btn_add_herb = cbtn(ctrl, (crow, 1), "+ Herbivores")
    btn_add_carn = cbtn(ctrl, (crow, 2), "+ Carnivores")
    crow += 1

    on(btn_add_herb.clicks) do _
        for _ in 1:sl_add.value[]
            model.next_id += 1
            push!(model.agents, AnimalAgent(model.next_id, HERBIVORE,
                                            random_good_pos(world, HERBIVORE)))
        end
    end
    on(btn_add_carn.clicks) do _
        for _ in 1:sl_add.value[]
            model.next_id += 1
            push!(model.agents, AnimalAgent(model.next_id, CARNIVORE,
                                            random_good_pos(world, CARNIVORE)))
        end
    end

    sec(ctrl, (crow, 1:2), "EXTREME EVENTS")
    crow += 1
    btn_hw   = cbtn(ctrl, (crow, 1), "Heatwave")
    btn_fr   = cbtn(ctrl, (crow, 2), "Frost")
    crow += 1
    btn_dr   = cbtn(ctrl, (crow, 1), "Drought")
    btn_st   = cbtn(ctrl, (crow, 2), "Storm")
    crow += 1
    btn_fire = cbtn(ctrl, (crow, 1), "Wildfire")
    btn_fld  = cbtn(ctrl, (crow, 2), "Flash Flood")
    crow += 1
    btn_dh   = cbtn(ctrl, (crow, 1), "Disease H")
    btn_dc   = cbtn(ctrl, (crow, 2), "Disease C")
    crow += 1

    on(btn_hw.clicks)   do _; trigger_event!(log, world, state, :heatwave;  intensity=0.8, duration=24*7);  end
    on(btn_fr.clicks)   do _; trigger_event!(log, world, state, :frost;     intensity=0.8, duration=24*5);  end
    on(btn_dr.clicks)   do _; trigger_event!(log, world, state, :drought;   intensity=0.9, duration=24*14); end
    on(btn_st.clicks)   do _; trigger_event!(log, world, state, :storm;     intensity=1.0, duration=24*3);  end
    on(btn_fire.clicks) do _; trigger_event!(log, world, state, :wildfire;  intensity=0.9, duration=24*5);  end
    on(btn_fld.clicks)  do _; trigger_event!(log, world, state, :flood;     intensity=0.9, duration=24*3);  end
    on(btn_dh.clicks)   do _; trigger_event!(log, world, state, :disease_h; intensity=0.7, duration=24*30); end
    on(btn_dc.clicks)   do _; trigger_event!(log, world, state, :disease_c; intensity=0.7, duration=24*30); end

    Label(ctrl[crow, 1:2], obs_events, color=C_DIM, fontsize=10, halign=:left)
    crow += 1

    sec(ctrl, (crow, 1:2), "EXPORT")
    crow += 1
    btn_exp_ts   = cbtn(ctrl, (crow, 1), "Time series CSV")
    btn_exp_snap = cbtn(ctrl, (crow, 2), "Snapshot CSV")
    crow += 1

    on(btn_exp_ts.clicks) do _
        mkpath("data/output")
        p = "data/output/timeseries_$(state.tick).csv"
        flush_timeseries!(buf, p); println("Exported: $p")
    end
    on(btn_exp_snap.clicks) do _
        mkpath("data/output")
        p = "data/output/snapshot_$(state.tick).csv"
        export_snapshot(world, state, p); println("Exported: $p")
    end

    rowgap!(ctrl, 6)
    colgap!(ctrl, 10)

    display(fig)

    frame_counter = Ref(0)

    # ── Timer  ───────────────────────────────────────────────────────────────────
    # 15 fps — keeps GPU comfortable; simulation speed is controlled by sl_speed
    timer = Timer(0.0; interval=1/15) do _
        paused[] && return

        n = max(1, sl_speed.value[])
        for _ in 1:n
            tick!(world, state, config)
            step_animals!(model, state)
            tick_events!(log, world, config, state)
        end

        record_tick!(buf, world, state, model, log)

        # ── Heatmaps: extract directly into observable values (zero allocation) ──
        extract_layer!(buf_temp,        world, :temperature)
        extract_layer!(obs_water.val,   world, :water)
        extract_layer!(obs_biomass.val, world, :biomass)
        extract_layer!(obs_flood.val,   world, :flood_depth)
        extract_layer!(obs_nuts.val,    world, :nutrients)
        obs_temp.val .= buf_temp   # keep buf_temp for mean() below
        notify(obs_temp)
        notify(obs_water)
        notify(obs_biomass)
        notify(obs_flood)
        notify(obs_nuts)

        # ── Animal scatter ────────────────────────────────────────────────────────
        h_pts = Point2f[]
        c_pts = Point2f[]
        for a in model.agents
            a.alive || continue
            pt = Point2f(Float32(a.pos[2]), Float32(a.pos[1]))
            a.species == HERBIVORE ? push!(h_pts, pt) : push!(c_pts, pt)
        end
        herb_pos[] = h_pts
        carn_pos[] = c_pts

        # ── Time-series (push + trim) ─────────────────────────────────────────────
        stats  = SimLoop.world_stats(world)
        t_mean = mean(buf_temp)
        t_norm = Float32(clamp((t_mean - (-20.0)) / 65.0, 0.0, 1.0))

        push!(ts_x,     Float32(state.tick))
        push!(ts_bio,   Float32(stats.mean_biomass))
        push!(ts_wat,   Float32(stats.mean_water))
        push!(ts_nuts,  Float32(stats.mean_nutrients))
        push!(ts_tnorm, t_norm)
        push!(ts_herbs, Float32(model.n_herbivores))
        push!(ts_carns, Float32(model.n_carnivores))

        while length(ts_x) > max_ts
            popfirst!(ts_x);    popfirst!(ts_bio);   popfirst!(ts_wat)
            popfirst!(ts_nuts); popfirst!(ts_tnorm); popfirst!(ts_herbs)
            popfirst!(ts_carns)
        end

        obs_bio[]    = Point2f.(ts_x, ts_bio)
        obs_wat[]    = Point2f.(ts_x, ts_wat)
        obs_nuts_ts[]= Point2f.(ts_x, ts_nuts)
        obs_tnorm[]  = Point2f.(ts_x, ts_tnorm)
        obs_herbs[]  = Point2f.(ts_x, ts_herbs)
        obs_carns[]  = Point2f.(ts_x, ts_carns)

        # ── Axis limits: reset every 30 frames, not every frame ──────────────────
        frame_counter[] += 1
        if frame_counter[] % 30 == 0
            reset_limits!(ax_ts)
            reset_limits!(ax_pop)
        end

        # ── Labels ───────────────────────────────────────────────────────────────
        obs_status[] = "tick $(state.tick)  |  yr $(state.year)  |  $(state.season)  |  T: $(round(t_mean,digits=1)) °C  |  flooded: $(stats.n_flooded) cells  |  H=$(model.n_herbivores)  C=$(model.n_carnivores)"
        obs_pop[]    = "Herbivores: $(model.n_herbivores)   |   Carnivores: $(model.n_carnivores)"

        active = active_summary(log)
        obs_events[] = isempty(active) ? "—  no active events" : join(active, "  |  ")
    end

    return fig, timer
end

end
