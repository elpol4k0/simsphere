module SetupGUI

using GLMakie
using ..Types

export show_setup_gui

const BG      = RGBf(0.07, 0.07, 0.10)
const C_TEXT  = RGBf(0.85, 0.85, 0.90)
const C_DIM   = RGBf(0.50, 0.50, 0.56)
const C_ACCENT= RGBf(0.36, 0.56, 0.78)
const C_BTN   = RGBf(0.16, 0.16, 0.24)
const C_BTN_P = RGBf(0.14, 0.32, 0.18)
const C_SEC   = RGBf(0.55, 0.65, 0.82)
const C_VAL   = RGBf(0.65, 0.82, 0.95)

function show_setup_gui()::NamedTuple
    GLMakie.activate!()

    result = Ref{NamedTuple}()
    done   = Channel{Bool}(1)

    fig = Figure(size=(740, 1040), backgroundcolor=BG)

    row = 0

    # ── Header ───────────────────────────────────────────────────────────────────
    row += 1
    Label(fig[row, 1:3], "SIMSPHERE",
          fontsize=30, color=C_TEXT, font=:bold, halign=:left)
    row += 1
    Label(fig[row, 1:3], "Ecosystem Simulation — Configuration",
          fontsize=13, color=C_DIM, halign=:left)

    # ── Helpers ───────────────────────────────────────────────────────────────────
    # Section header: full-width label, blue-gray, bold
    function section(r, text)
        Label(fig[r, 1:3], text,
              fontsize=11, color=C_SEC, halign=:left, font=:bold)
    end

    # Parameter row: [name col1] [slider col2] [value col3]
    function param(r, name, rng, start; fmt=v->"$(round(v, sigdigits=3))", unit="")
        Label(fig[r, 1], name, color=C_TEXT, halign=:left, fontsize=12)
        sl = Slider(fig[r, 2], range=rng, startvalue=start,
                    color_active=C_ACCENT, color_active_dimmed=C_BTN)
        disp = isempty(unit) ?
            @lift(fmt($(sl.value))) :
            @lift("$(fmt($(sl.value)))  $unit")
        Label(fig[r, 3], disp, color=C_VAL, halign=:right, fontsize=12)
        sl
    end

    # ── WORLD ────────────────────────────────────────────────────────────────────
    row += 1; section(row, "WORLD")
    row += 1
    sl_size = param(row, "Grid size", 20:10:200, 100;
                    fmt=v->"$(Int(v)) × $(Int(v))", unit="cells")

    # ── CLIMATE ──────────────────────────────────────────────────────────────────
    row += 1; section(row, "CLIMATE")
    row += 1
    sl_temp     = param(row, "Base temperature",     -15.0:1.0:40.0,  15.0; unit="°C")
    row += 1
    sl_daily    = param(row, "Diurnal amplitude",     0.0:0.5:20.0,    8.0; unit="°C day/night swing")
    row += 1
    sl_seasonal = param(row, "Seasonal amplitude",    0.0:1.0:30.0,   15.0; unit="°C summer/winter swing")

    # ── HYDROLOGY ────────────────────────────────────────────────────────────────
    row += 1; section(row, "HYDROLOGY")
    row += 1
    sl_rain = param(row, "Rain probability",  0.001:0.001:0.1,  0.02;
                    fmt=v->"$(round(v * 100, digits=1))%", unit="per cell/tick")
    row += 1
    sl_rain_int = param(row, "Rain intensity", 0.1:0.05:5.0,    1.0;
                        unit="× base amount  (1=normal · 3=monsoon)")
    row += 1
    sl_evap = param(row, "Evaporation rate",  0.001:0.001:0.05, 0.005;
                    unit="per tick")
    row += 1
    sl_wind = param(row, "Wind speed",        0.0:0.05:1.0,     0.3;
                    unit="(0=calm · 1=gale)")

    # ── VEGETATION ───────────────────────────────────────────────────────────────
    row += 1; section(row, "VEGETATION")
    row += 1
    sl_growth = param(row, "Growth rate  r",      0.01:0.01:0.30,  0.05)
    row += 1
    sl_topt   = param(row, "Optimal temperature", 0.0:1.0:35.0,   18.0; unit="°C")

    # ── FAUNA ────────────────────────────────────────────────────────────────────
    row += 1; section(row, "FAUNA")
    row += 1
    sl_herb = param(row, "Herbivore agents", 0:5:300, 50;
                    fmt=v->"$(Int(v))", unit="agents")
    row += 1
    sl_carn = param(row, "Carnivore agents", 0:1:80,  12;
                    fmt=v->"$(Int(v))", unit="agents")

    # ── SIMULATION ───────────────────────────────────────────────────────────────
    row += 1; section(row, "SIMULATION")
    row += 1
    sl_speed = param(row, "Ticks per frame", 1:1:100, 24;
                     fmt=v->"$(Int(v))x", unit="speed multiplier")

    # ── SCENARIO PRESETS ─────────────────────────────────────────────────────────
    row += 1; section(row, "SCENARIO PRESET")
    row += 1
    btn_default = Button(fig[row, 1], label="Default",
                         buttoncolor=C_BTN, labelcolor=C_TEXT, fontsize=12)
    btn_drought = Button(fig[row, 2], label="Drought",
                         buttoncolor=C_BTN, labelcolor=C_TEXT, fontsize=12)
    btn_iceage  = Button(fig[row, 3], label="Ice Age",
                         buttoncolor=C_BTN, labelcolor=C_TEXT, fontsize=12)
    row += 1
    btn_tropic  = Button(fig[row, 1], label="Tropics",
                         buttoncolor=C_BTN, labelcolor=C_TEXT, fontsize=12)
    btn_cc      = Button(fig[row, 2], label="Climate Change",
                         buttoncolor=C_BTN, labelcolor=C_TEXT, fontsize=12)

    on(btn_default.clicks) do _
        set_close_to!(sl_temp, 15.0);  set_close_to!(sl_rain,     0.02)
        set_close_to!(sl_evap, 0.005); set_close_to!(sl_growth,   0.05)
        set_close_to!(sl_seasonal, 15.0); set_close_to!(sl_daily, 8.0)
    end
    on(btn_drought.clicks) do _
        set_close_to!(sl_temp, 28.0);  set_close_to!(sl_rain,   0.003)
        set_close_to!(sl_evap, 0.02);  set_close_to!(sl_growth, 0.03)
        set_close_to!(sl_seasonal, 10.0)
    end
    on(btn_iceage.clicks) do _
        set_close_to!(sl_temp, -8.0);   set_close_to!(sl_seasonal, 25.0)
        set_close_to!(sl_rain, 0.015);  set_close_to!(sl_growth,   0.02)
        set_close_to!(sl_evap, 0.003)
    end
    on(btn_tropic.clicks) do _
        set_close_to!(sl_temp, 28.0);  set_close_to!(sl_rain,     0.07)
        set_close_to!(sl_evap, 0.01);  set_close_to!(sl_growth,   0.12)
        set_close_to!(sl_seasonal, 5.0)
    end
    on(btn_cc.clicks) do _
        set_close_to!(sl_temp, 18.0);  set_close_to!(sl_rain,     0.016)
        set_close_to!(sl_evap, 0.008); set_close_to!(sl_growth,   0.04)
        set_close_to!(sl_seasonal, 18.0)
    end

    # ── Live summary ─────────────────────────────────────────────────────────────
    row += 1
    Label(fig[row, 1:3],
          @lift(begin
              s = Int($(sl_size.value))
              t = $(sl_temp.value)
              p = round($(sl_rain.value) * 100, digits=1)
              h = Int($(sl_herb.value))
              c = Int($(sl_carn.value))
              "$(s)×$(s)  |  T=$(t) °C  |  Rain=$(p)%  |  H=$(h)  C=$(c)"
          end),
          color=C_DIM, fontsize=10, halign=:left)

    # ── Run / Cancel ─────────────────────────────────────────────────────────────
    row += 1
    btn_run    = Button(fig[row, 1:2], label="Run Simulation",
                        buttoncolor=C_BTN_P, labelcolor=C_TEXT, fontsize=15)
    btn_cancel = Button(fig[row, 3], label="Cancel",
                        buttoncolor=C_BTN, labelcolor=C_DIM, fontsize=13)

    # Column widths: name (38%) | slider (40%) | value (22%)
    colsize!(fig.layout, 1, Relative(0.38))
    colsize!(fig.layout, 2, Relative(0.40))
    colsize!(fig.layout, 3, Relative(0.22))

    # Base row gap + extra gap before each section header
    rowgap!(fig.layout, 5)
    for r in [3, 5, 9, 12, 15, 18, 20]
        rowgap!(fig.layout, r, 14)
    end
    colgap!(fig.layout, 10)

    on(btn_run.clicks) do _
        s = Int(sl_size.value[])
        cfg = SimConfig(
            width                   = s,
            height                  = s,
            base_temp               = Float64(sl_temp.value[]),
            temp_amplitude_daily    = Float64(sl_daily.value[]),
            temp_amplitude_seasonal = Float64(sl_seasonal.value[]),
            rain_probability        = sl_rain.value[],
            rain_intensity          = sl_rain_int.value[],
            evaporation_rate        = sl_evap.value[],
            wind_speed              = sl_wind.value[],
            growth_rate             = sl_growth.value[],
            temp_opt                = Float64(sl_topt.value[]),
            ticks_per_frame         = Int(sl_speed.value[]),
        )
        result[] = (
            config       = cfg,
            n_herbivores = Int(sl_herb.value[]),
            n_carnivores = Int(sl_carn.value[]),
            cancelled    = false,
        )
        put!(done, true)
    end
    on(btn_cancel.clicks) do _
        result[] = (config=SimConfig(), n_herbivores=0, n_carnivores=0, cancelled=true)
        put!(done, true)
    end

    display(fig)
    take!(done)
    GLMakie.closeall()

    return result[]
end

end
