# Rendering (lighting baseline, world materials, level of detail)

Owner decision, 2026-10-26. Design doc entry: `GAME_DESIGN_REQUIREMENTS.md`, "Owner rendering pass". Purely visual:
nothing here changes physics, payouts, NPC speed or race results. Every number below is a placeholder (tunable).

## 1. Lighting baseline
- `Shared/LightingConfig` holds the values; `Server/Main` applies them (`LightingConfig.Apply`) BEFORE
  `WeatherService.Start`, so the weather baseline it snapshots is this one and every event restores it.
- Lighting: `Brightness` 2.8, `Ambient` (40, 42, 52), `OutdoorAmbient` (112, 118, 136), `ShadowSoftness` 0.12,
  `EnvironmentDiffuseScale` 1, `EnvironmentSpecularScale` 1, `ExposureCompensation` 0, `ClockTime` 14.5.
- Post effects (made if missing, named as below): `Grade` ColorCorrection (Saturation 0.18, Contrast 0.15,
  Brightness 0.01, TintColor (255, 250, 244)); `Bloom` (Intensity 0.7, Size 28, Threshold 1.4, so Neon glows
  and white paint does not); `SunRays` (Intensity 0.06, Spread 0.6).
- Atmosphere: Density 0.28, Offset 0.2, Haze 0.3, Glare 0.1, Color (190, 206, 232), Decay (110, 120, 140).
- `Lighting.Technology` cannot be set by scripts: the place file uses `Future` (set once by hand in Studio).
- Biomes still never change global Lighting; the RollShowcase / UpgradeTree blurs are untouched.

## 2. World materials
- Track roads use `Asphalt`, walls `Concrete`, loop and hill supports keep their colour with `Concrete`.
  Colours are unchanged (biome themes). Lines, checkers, pads and every `Neon` part stay as they are.
- The spawn-area floor is `Concrete` (owner 2026-10-30, replaces "stays `SmoothPlastic`"; `SPAWN_AND_ROLLS_SPEC.md`
  section 1b).

## 3. Level of detail
- Car skins: small detail groups cast no shadow (`CAR_REDESIGN_SPEC.md` section 8).
- NPC cars (client-only): no part casts a shadow except `Body` and the wheels.
- Biome props: unchanged rule, props with `Size.Magnitude` <= 30 cast no shadow (`BiomeDressing`).
- `Workspace.StreamingEnabled` stays on.
