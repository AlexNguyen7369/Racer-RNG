# Weather and biome events

Server events begin every 10–20 minutes and last 3 minutes. The server selects Rain, Night Race, or Gold Rush. Replicated attributes `WeatherEvent` and `WeatherEndsAt` drive the client banner; only the server changes events and economy multipliers.

| Event | Luck | Money | NPC speed | Lighting |
|---|---:|---:|---:|---|
| Rain | ×2 | ×1 | ×1 | Cool overcast afternoon |
| Night Race | ×1 | ×2 | ×1.25 | Midnight |
| Gold Rush | ×1 | ×3 | ×1 | Warm sunset |

**Sky (owner, 2026-10-12; not built yet).** Each event also changes the sky, and the clear state restores the exact baseline values that `WeatherService.Start` saved. No uploaded skybox textures: the server sets `Lighting.Atmosphere` (Color, Density, Haze), `Terrain.Clouds` (Cover, Density, Color) and `Lighting.Sky.StarCount` from `WeatherConfig.Events[id].Sky`.

| Event | Atmosphere | Clouds | Stars |
|---|---|---|---|
| Rain | grey-blue, dense, hazy | heavy cover, dark | 0 |
| Night Race | dark violet, thin | light cover | many |
| Gold Rush | warm gold, light haze | thin, golden | 0 |

Night Race locks the NPC's speed when a track starts, so an event ending mid-track never changes the opponent's deadline. Money is quoted when a pad is collected or a track is won; cashing out an already banked amount never multiplies it again. Cruise speed and car physics are unchanged.

Three permanent catalog keys are available only during their matching event. They reuse imported meshes and illustrated icons, with a colored racing skin. Discovery and equipment persist after the event ends.

| ID | Event | Odds | Speed gain multi | Mesh |
|---|---|---:|---:|---|
| `rain_runner` | Rain | 1 in 500 | ×6 | `street_racer` |
| `midnight_kart` | Night Race | 1 in 2,500 | ×8 | `go_kart` |
| `golden_racer` | Gold Rush | 1 in 5,000 | ×10 | `rocket_car` |

The seven original catalog cars retain their IDs, odds, multipliers and models. Event-ineligible cars are filtered before sampling random numbers. Unknown saved IDs remain preserved.

The `weather` harness scenario verifies exact expiry, multipliers, actual roll thresholds, payouts, NPC start speeds and event-only eligibility. Automatic scheduling is suspended while `CarTestRunning` is true; explicit event fixtures still work. Full compatibility verification remains pending until the final files are synced to Studio.
