--!nonstrict
-- Duels, player vs player (docs/DUEL_SPEC.md section 2). No stake: a duel moves no Money.
local DuelConfig = {}

DuelConfig.REQUEST_COOLDOWN = 10 -- seconds between two requests of the same player
DuelConfig.PICK_TIMEOUT = 15 -- seconds the challenger has to pick a track
DuelConfig.INVITE_TIMEOUT = 15 -- seconds the challenged player has to answer; no answer is a decline
DuelConfig.COUNTDOWN = 3 -- seconds both cars are held once both players are seated
DuelConfig.RACE_TIMEOUT = 180 -- seconds after the release; nobody finished by then is a draw
DuelConfig.PROMPT_DISTANCE = 10 -- studs: the "Duel" prompt on an on-foot character
DuelConfig.REMOTE_INTERVAL = 0.25 -- seconds between two client messages of one player

return DuelConfig
