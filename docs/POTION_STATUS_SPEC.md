# Potion status HUD

**Status: BUILT 2026-10-15.** The server remains authoritative for potion activation and expiry. This spec covers
only the client status display.

`RacerProgression/PotionStatus` is a horizontal status row at the bottom right, immediately left of
`RacerProgression/WeatherIcon`. It is hidden when no potion is active and while the roll showcase is open. On phones
it remains left of the weather icon's phone-safe position, which is already left of the Bag/Daily/Market stack.

There is at most one icon for each `BoostConfig.Order` category (`Luck`, `Money`, `Speed`). If multiple tiers in a
category are active, the icon represents the active item with the greatest `Multiplier`, matching the server's
effective multiplier. Each icon uses the existing text-glyph visual language and shows a countdown in seconds.

The countdown is `ceil(BoostUntil_<id> - workspace:GetServerTimeNow())`, clamped at zero. Expired items disappear on
the next status refresh. No client value grants or extends a potion.
