# Weather and biome events

Server events begin every 10–20 minutes and last 3 minutes. The server selects Rain, Night Race, or Gold Rush. Replicated attributes `WeatherEvent` and `WeatherEndsAt` drive the client banner; only the server changes events and economy multipliers.

| Event | Luck | Money | NPC speed | Lighting |
|---|---:|---:|---:|---|
| Rain | ×2 | ×1 | ×1 | Cool overcast afternoon |
| Night Race | ×1 | ×2 | ×1.25 | Midnight |
| Gold Rush | ×1 | ×3 | ×1 | Warm sunset |

**Sky (owner, 2026-10-12; built 2026-10-13).** Each event also changes the sky, and the clear state restores the exact baseline values that `WeatherService.Start` saved. No uploaded skybox textures: the server sets `Lighting.Atmosphere` (Color, Density, Haze), `Terrain.Clouds` (Cover, Density, Color) and `Lighting.Sky.StarCount` from `WeatherConfig.Events[id].Sky`. A place without those instances gets them from `WeatherService.Start` with no haze (Atmosphere `Density` 0) and no clouds (`Cover` 0), so the clear sky looks as before.

| Event | Atmosphere | Clouds | Stars |
|---|---|---|---|
| Rain | grey-blue, dense, hazy | heavy cover, dark | 0 |
| Night Race | dark violet, thin | light cover | many |
| Gold Rush | warm gold, light haze | thin, golden | 0 |

Night Race locks the NPC's speed when a track starts, so an event ending mid-track never changes the opponent's deadline. Money is quoted when a pad is collected or a track is won; cashing out an already banked amount never multiplies it again. Cruise speed and car physics are unchanged.

**Displayed odds (owner, 2026-10-13; design doc "Weather events").** While an event (or any other luck source) is active, the roll card and the compact roll show the odds of that roll, not the car's base odds: `1 in max(1, round(Chance / luck))`. `luck` is the server's `GachaService.Luck(player)` for that roll (stat points, upgrades, rebirth, boosts, weather, workshop), sent as the 6th `RollResult` argument. It excludes the turbo multi, which the TURBO badge shows. A 1 in 500 car shows "1 in 250" during Rain at luck 1. Catch-all cars keep "1 in ?". The Index and the server-wide roll announcement keep the base odds.

Three permanent catalog keys are available only during their matching event. They reuse imported meshes and illustrated icons, with a colored racing skin. Discovery and equipment persist after the event ends.

| ID | Event | Odds | Speed gain multi | Mesh |
|---|---|---:|---:|---|
| `rain_runner` | Rain | 1 in 500 | ×6 | `street_racer` |
| `midnight_kart` | Night Race | 1 in 2,500 | ×8 | `go_kart` |
| `golden_racer` | Gold Rush | 1 in 5,000 | ×10 | `rocket_car` |

The seven original catalog cars retain their IDs, odds, multipliers and models. Event-ineligible cars are filtered before sampling random numbers. Unknown saved IDs remain preserved.

The `weather` harness scenario verifies exact expiry, multipliers, actual roll thresholds, payouts, NPC start speeds and event-only eligibility. Automatic scheduling is suspended while `CarTestRunning` is true; explicit event fixtures still work. Results 2026-10-13 (live Studio): harness `weather` 216/216 inside `[CARTEST] END pass=35 fail=0`; `ui_weather` green for `weather_rain`, `weather_night`, `weather_gold`, `weather_clear` and `weather_rain_roll`; each sky was looked at live and the clear sky came back to the exact baseline values. The full `/compat-check` has not run on this code.
