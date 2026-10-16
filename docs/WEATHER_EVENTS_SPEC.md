# Weather and biome events

**Schedule (owner, 2026-10-13; design doc "Weather events").** A weather starts every 15 minutes (`WeatherConfig.INTERVAL`, start to start) and lasts 3 minutes (`DURATION`); the first one starts 15 minutes after the server does. Between weathers nothing is active (`WeatherEvent = ""`). The server picks one id from `WeatherConfig.Order` with equal chance (1 in 5): `clear`, `rain`, `night`, `gold`, `aurora`. An explicit `WeatherService.SetEvent(id, at)` restarts the 15 minutes from `at`; a weather that simply expires does not move the next start. Replicated attributes `WeatherEvent` and `WeatherEndsAt` drive the client icon; only the server changes weathers and economy multipliers. The interval, the list and every number below are placeholders.

**Planned, not built (owner, 2026-10-13).** Weathers will get different chances: a bigger benefit means a lower chance to appear. Until the owner sets those weights the pick stays uniform.

| Event | Luck | Money | NPC speed | Lighting |
|---|---:|---:|---:|---|
| Clear | ×1 | ×1 | ×1 | Unchanged (baseline) |
| Rain | ×2 | ×1 | ×1 | Cool overcast afternoon |
| Night Race | ×1 | ×2 | ×1.25 | Midnight |
| Gold Rush | ×1 | ×3 | ×1 | Warm sunset |
| Aurora | ×1.5 | ×1.5 | ×1 | Dusk, green glow |

`clear` is a real pick with its own 3 minutes, but it has no `Sky`, `ClockTime`, `Brightness` or `Color` effect: Lighting and the sky stay at the baseline.

**Weather icon (owner, 2026-10-13).** `RacerProgression/WeatherIcon` replaces the old top-left `WeatherBanner`, which must not exist. It is a 44 x 44 `TextButton` in the bottom-right corner of the HUD (8 px from the right and bottom edges), always visible; on phones (viewport height <= 500) the Bag / Daily / Market stack fills that corner, so the icon keeps the 8 px bottom gap but sits 8 px left of the Market button, its right edge 140 px from the screen's right edge (owner, 2026-10-13). It shows `WeatherConfig.Events[id].Icon`; with no weather active it shows the Clear icon. Its child `Card` (a `Frame`, hidden by default, opening up and to the left so it stays on screen) shows on mouse hover and toggles on tap, with three labels: `Title` (the weather's `Name`), `Stats` (`WeatherConfig.Describe(id)`) and `Time` (`Ns left`, empty when no weather is active). `Describe` lists every multiplier that is not 1 as `LUCK x2`, `MONEY x2`, `NPC SPEED x1.25`, joined by ` • `, and returns `NO BONUS` for Clear, for `""` and for an unknown id. The icon follows the other HUD rules: it hides while the roll showcase is open and overlaps no other reachable UI at any tested viewport. Icons are text glyphs for now; image icons come later.

**Sky (owner, 2026-10-12; built 2026-10-13).** Each event also changes the sky, and the clear state restores the exact baseline values that `WeatherService.Start` saved. No uploaded skybox textures: the server sets `Lighting.Atmosphere` (Color, Density, Haze), `Terrain.Clouds` (Cover, Density, Color) and `Lighting.Sky.StarCount` from `WeatherConfig.Events[id].Sky`. A place without those instances gets them from `WeatherService.Start` with no haze (Atmosphere `Density` 0) and no clouds (`Cover` 0), so the clear sky looks as before.

| Event | Atmosphere | Clouds | Stars |
|---|---|---|---|
| Rain | grey-blue, dense, hazy | heavy cover, dark | 0 |
| Night Race | dark violet, thin | light cover | many |
| Gold Rush | deep gold, hazy | broad, thin, golden | 0 |
| Aurora | bright teal-green, hazy | medium cover, violet | many |

**Distinguishable skies (owner, 2026-10-13).** A player must be able to tell the five weathers apart by the sky alone: Clear blue, Rain grey overcast, Night Race black with stars, Gold Rush gold haze, Aurora teal-green. Checked by eye in Studio on 2026-10-13; the first Gold Rush values looked like Clear and the first Aurora values like Night Race, so both were strengthened.

Night Race locks the NPC's speed when a track starts, so an event ending mid-track never changes the opponent's deadline. Money is quoted when a pad is collected or a track is won; cashing out an already banked amount never multiplies it again. Cruise speed and car physics are unchanged.

**Displayed odds (owner, 2026-10-15).** The roll card and compact roll always show the car's catalog rarity: `HudFormat.Odds(Chance)`. Temporary luck sources still affect the server's actual roll probability, but do not rewrite the rarity label. Void Racer therefore remains "1 in 100,000" while Luck, boosts, weather or turbo effects are active. Catch-all cars keep "1 in ?". The Index and the server-wide roll announcement also keep the base odds.

The sixth `RollResult` argument remains the server-calculated luck used by the roll for compatibility and diagnostics; it is not used by the roll animation's displayed odds.

Three permanent catalog keys are available only during their matching event (Clear and Aurora have none). They reuse imported meshes and illustrated icons, with a colored racing skin. Discovery and equipment persist after the event ends.

| ID | Event | Odds | Speed gain multi | Mesh |
|---|---|---:|---:|---|
| `rain_runner` | Rain | 1 in 500 | ×6 | `street_racer` |
| `midnight_kart` | Night Race | 1 in 2,500 | ×8 | `go_kart` |
| `golden_racer` | Gold Rush | 1 in 5,000 | ×10 | `rocket_car` |

The seven original catalog cars retain their IDs, odds, multipliers and models. Event-ineligible cars are filtered before sampling random numbers. Unknown saved IDs remain preserved.

The `weather` harness scenario verifies exact expiry, multipliers, actual roll thresholds, payouts, NPC start speeds and event-only eligibility. Automatic scheduling is suspended while `CarTestRunning` is true; explicit event fixtures still work. Results 2026-10-13 (live Studio): harness `weather` 216/216 inside `[CARTEST] END pass=35 fail=0`; `ui_weather` green for `weather_rain`, `weather_night`, `weather_gold`, `weather_clear` and `weather_rain_roll`; each sky was looked at live and the clear sky came back to the exact baseline values. The full `/compat-check` has not run on this code.
