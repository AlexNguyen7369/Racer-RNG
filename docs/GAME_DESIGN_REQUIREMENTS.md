Idle Vehicle Simulator — Game Design Requirements




  Idle Vehicle Simulator — Game Design
  Requirements
    Sep 22, 2026         · ​@Someone


  Overview
  Idle Vehicle Simulator is a Roblox idle game where everything feeds one number: Speed.
  Players earn it by idling in their workshop, racing NPCs for money, rolling for faster cars,
  and rebirthing for bigger multipliers.

  Design pillars

       Speed is the score. Every system either raises Speed gain or is unlocked by it.
       Progress while idle. The workshop and auto-rolling keep paying out while the player is
       AFK.
       Push your luck. Race outcomes are deterministic speed comparisons; a win pays the current track immediately.
       Resets that feel huge. Each rebirth wipes Money and Speed but makes the next run
       dramatically faster.

     flowchart LR
       W[Workshop - AFK] -->|Speed/sec| S((Speed))
       S --> R[Race NPC ladder]
       R -->|cash out| M[Money]
       M --> U[Fuel, auras, spoilers,<br/>workshop upgrades]
       U -->|multipliers| S
       S -->|XP| L[Level]
       L -->|milestone| RB[Rebirth]
       RB -->|multis + stat points| S
       G[Auto-roll cars] -->|car multi| S


  The loop: idle for Speed, race to turn Speed into Money, spend Money on multipliers, then
  rebirth once you hit a level milestone.


  Glossary
  Plain-language definitions for every term used below.




                                                                                           Page 1 of 14


Idle Vehicle Simulator — Game Design Requirements




     Term                                     What it means

     Speed                                    The main progression number. Think of it as the
                                              player's score.

     Speed gain                               How much Speed the player earns each second.

     Multiplier (multi)                       A number gains get multiplied by. 2x doubles, 10x
                                              makes it ten times bigger.

     Base car                                 The car the player has equipped. Its multi boosts
                                              Base speed.

     Mechanical Workshop                      The player's personal area at their base. Standing in
                                              it earns Speed passively.

     NPC                                      A computer-controlled racer with a fixed speed.

     Luck                                     Raises the odds of rolling rarer cars. 1x is normal
                                              odds.

     Auto-roll                                The game rolls for a new car on a timer, no input
                                              needed.

     Jett Fuel                                A power that gives every Nth auto-roll a big luck
                                              boost.

     Rebirth                                  Resetting Money and Speed in exchange for
                                              permanent multipliers and Rebirth Points.

     Rebirth Points                           Points spent on four permanent stats.

     Server Luck                              A temporary luck boost for everyone in the server,
                                              bought with Robux.

     Gamepass                                 A one-time Robux purchase the player owns
                                              forever.

     Developer product                        A Robux purchase that can be bought again and
                                              again (boosts, consumables).




  Core stat model
  Historical proposal: every source is a multiplier, and Speed gain per second is all of them
  multiplied together. The current owner rule below narrows this to permanent Speed Gain upgrades
  and rebirths; equipped car models and temporary cruise boosts never affect Speed gain.
  Owner exception, 2026-10-22 (Workshop Showcase): the three cars a player shows in their
  workshop add a Showcase multi to WORKSHOP Speed gain only (docs/WORKSHOP_SPEC.md "Showcase").
  The equipped car still never affects any Speed gain.


                                                                                                      Page 2 of 14


Idle Vehicle Simulator — Game Design Requirements




     \text{Speed gain per second} = B \times C \times F \times A \times P \times W
     \times R \times S \times G



     Symbol           Multiplier            Comes from                     Starts at     On rebirth

     B                Base rate             Fixed game constant            1 Speed/sec   Unchanged

     C                Car                   Equipped car from the gacha    1x (starter   Kept (proposed)
                                                                           car)

     F                Fuel                  Bought with Money              1x            Open question

     A                Aura                  Bought with Money              1x            Open question

     P                Spoiler               Bought with Money              1x            Open question

     W                Workshop              Money upgrades +               1x            Passes kept; money
                                            Gold/Diamond/Void passes.                    upgrades open
                                            Only applies inside the
                                            workshop

     R                Rebirth               Automatic bonus each rebirth   1x            Grows

     S                Speed                 Rebirth Points spent on Base   1x            Kept
                      stat                  Speed Multi

     G                Gamepass              2x Speed pass chain            1x            Kept


  Owner decision, 2026-10-13 (Speed growth and its effect):
       The Speed number grows at an INCREASING rate over a player's progression: the further
       along the player is, the faster the number climbs. Speed gain must not shrink because
       the Speed stat is already high.
       The effect of the number on base/cruise speed has DIMINISHING returns: each extra
       point of Speed adds less cruise speed than the one before. The effect never flattens
       out and never reaches zero; a higher Speed must always give a cruise speed the player
       can tell apart. There is no hard cap on cruise speed. (REPLACED 2026-10-27: cruise is capped at
       RaceConfig.MAX_CRUISE, see "Owner decision, 2026-10-27 (cruise cap and worlds)" under Rebirth system.)
       Maths (same date; the constants are placeholders, the shapes are fixed):
       Race Speed gain per second = GAIN_PER_SECOND x the permanent Speed Gain multipliers.
       It is independent of Speed, equipped car, cruise multipliers, temporary boosts and actual speed.
       Workshop Speed gain per second = BASE_RATE x Speed multi x workshop level x Workshop
       points x Showcase multi (owner 2026-10-22). Nothing divides it by the Speed stat; it rises with the workshop level and the
       multipliers. Offline earnings are that rate x the offline share x the capped time.
       Cruise speed uses a friendly early segment followed by diminishing returns: for effective Speed up to HALF_STAT,
       BASE_SPEED + (MAX_SPEED - BASE_SPEED) x Speed / HALF_STAT; above HALF_STAT,
       MAX_SPEED + (MAX_SPEED - BASE_SPEED) / 2 x log2(1 + (Speed - HALF_STAT) / HALF_STAT)
       (owner 2026-10-22: each doubling above HALF_STAT adds HALF the range, so 196 studs/s at 1M).
       "Speed" here is the effective Speed: the stat multiplied by the damped car/aura cruise multi, capped at
       1.5x, before the curve (owner 2026-10-22: the multi scales the stat, not the cruise result; REPLACED
       2026-10-27: the multi now scales the cruise result and HALF_STAT is 10,000, see below). The active
       placeholder HALF_STAT was 100,000 (REPLACED 2026-10-27: 10,000), so the first 100K Speed is easier to feel (linear). The join at 100K is
       a kink (owner 2026-10-22: kept, not smoothed); past it every later point adds less.
       The tail never flattens and has no hard cap (REPLACED 2026-10-27: cruise is capped at
       RaceConfig.MAX_CRUISE, see "Worlds").
       Owner decision, 2026-10-20: the Speed stat itself has no cap either (only infinity and
       non-numbers are rejected, since they can not be saved).
       Owner decision, 2026-10-20 (one steady speed): the auto-racing car drives at exactly its
       cruise speed for the whole run, with no acceleration and no slowing in corners. A car
       starting a run, a checkpoint or a restart is at its cruise speed at once, so every car
       races at its own speed everywhere on the chain. This must stay stable (no flips, no tilt,
       on the path) up to the test reference stat MAX_STAT. The NPC opponents are unchanged.
       Historical decision, 2026-10-20 (superseded by the 2026-10-21 active rule below): cruise speed is much slower
       (placeholders BASE_SPEED 12, MAX_SPEED 18: +3 studs/s per doubling of Speed, still no
       cap). The car's speed multi has diminishing returns: a multi m above 1 counts as 1 + log2(m)
       in the cruise formula (2x stays 2x); the multi shown on the car is unchanged. Each
       next track's NPC is twice as fast as the
       one before (placeholders: Track 1 = 9 studs/s, x2 per track). A car that leaves the road
       (more than 2 studs under it or 8 studs over it) is put back on it, so no speed drops a
       car out of the map.
       Historical decision, 2026-10-20 (superseded by the 2026-10-21 active rule below):
       placeholders MAX_SPEED 22 (+5 studs/s per doubling of Speed), HALF_STAT 5000,
       GAIN_PER_STUD 0.01 (was 0.05) and workshop BASE_RATE 0.2 (was 1): Speed is earned 5x
       slower and each point buys less cruise speed. Shapes unchanged: diminishing, no cap.
       Historical decision, 2026-10-21 (superseded later the same day): every NPC, Track 1 included, is much harder.
       Beginners are expected to lose Track 1 until they build Speed or roll a faster car.
       Placeholders: Track 1 NPC = 45 studs/s (was 30, formerly 9), x2.5 per track. NPCs on tracks 1-10
       drive imported car models, and their label shows from 200 studs.
       Owner decision, 2026-10-21 (multiplied Speed; revised 2026-10-21 to damp rare-car speed):
       The player has a base Speed (the number they earn, see and save). The equipped car (and
       any shop effect that changes cruise speed) has a separate cruise multi. It is used only when
       calculating movement speed; it never changes the displayed Speed stat or its gain rate. The
       HUD, Stats panel, Roblox player list, and global Speed leaderboard therefore all show base
       Speed. The car's own multi is still shown on the car.
       Before the cruise formula, the raw cruise multi is damped to `1 + log10(raw cruise multi)`
       and capped at effective 1.5x (minimum 0.1 for valid positive values). This keeps rare cars
       faster without allowing a 350x/1000x car to create hundreds or thousands of studs/s. The same base Speed can therefore
       produce different cruise speeds with different cars, while the Speed gain rate remains identical.
       Saving, rebirth resets and Speed gain still use the base Speed. The gain rules above are
       unchanged.
       Large Speed numbers are abbreviated with suffixes (K, M, B, T, Qd = quadrillion,
       Qt = quintillion, and onward) instead of growing endless digits. The exact point where
       the HUD switches from full digits to suffixes is a placeholder.
       Owner decision, 2026-10-27 (replaces the capital suffixes above): every displayed Speed,
       Money and Unbanked number (HUD, panels, gate signs, leaderboards) uses LOWERCASE suffixes
       k, m, b, t, qd (quadrillion), qt (quintillion), sx, sp, oc, no, dc with 3 significant
       digits ("1.5k", "10.2m", "$3.4b", "10qd", "10sp"). Money is shortened too ("$1.2m").
       Shortening starts at 1,000 (placeholder); below that the full number is shown.
       Owner decision, 2026-10-27 (later): Speed numbers keep full digits with thousands separators
       ("123,456") up to 1,000,000 and shorten from there ("1.23m"), so every second's gain is visible
       early. Money and Unbanked still shorten from 1,000. Both thresholds are placeholders.
       Historical decision, 2026-10-21 (superseded later the same day): Track 1 must not need ~10M Speed.
       Placeholders: MAX_SPEED 22 (was 18; +5 studs/s per Speed doubling), Track 1 NPC 15 studs/s
       (was 45), x1.37 per track (was x2.5). Recommended Speed: Track 1 ~2.6K, Track 5 ~1.4M,
       Track 10 ~2.1Qt. A stat-0 starter car (10 studs/s) still loses Track 1.
       Owner decision, 2026-10-21 (later again; replaces the speed-proportional race gain and the
       "increasing rate" shape of 2026-10-13 for racing): race Speed gain per second is a flat
       GAIN_PER_SECOND (placeholder 2) x the permanent Speed Gain multipliers (the Speed Gain
       stat/upgrade and rebirth). It does not depend on the player's Speed stat, equipped car,
       car/aura cruise multi, temporary boosts, or how fast the car drives.
       Cruise speed is buffed: placeholder MAX_SPEED 109 (+48.5 studs/s per doubling of shown
       Speed; same log shape, no cap). Each next track's NPC is 1.75x faster (placeholder Track 1
       = 16 studs/s). Recommended Speed: Track 1 ~7.7K, Track 5 ~301K, Track 10 ~2.15e23.
       Owner decision, 2026-10-27 (speed feel, replaces where they differ the 2026-10-21 / 10-22 cruise
       entries): (1) the damped car / shop cruise multi (1 + log10(raw), 0.1 .. 1.5) multiplies the final
       cruise studs/s instead of the Speed fed into the curve, so cars differ from the first second (at 0
       Speed the starter drives 10 studs/s and a car at the full damped x1.5, i.e. raw x3.16 or more, 15; a raw
       x1.5 car gives 1 + log10(1.5) = x1.18, 11.8 studs/s). (2) HALF_STAT is 10,000 (placeholder, was
       100K): about 17.8 studs/s at 1K Speed, 88 at 10K, then +39 studs/s per doubling. NPC recommended
       Speeds (StatFor) drop 10x with it. The displayed Speed and its gain are unchanged.
       Owner decision, 2026-10-22 (speed feel): make the first 100K Speed easier to gain and begin
       the stronger diminishing-return tail only after 100K. Placeholders MAX_SPEED 88 and HALF_STAT 100K.
       With raw multi 1 this gives about 18 studs/s at 10K, 49 at 50K, 88 at 100K, and 218 at 1M
       (owner 2026-10-26: 218 corrects the earlier 205, which did not match the formula above);
       above 100K every later point adds less cruise speed, with no cap.
       Track gates show a recommended Speed: the shown Speed at which the car's cruise speed
       matches that track's NPC. Players compare their own shown Speed with it, whatever car
       they drive (see Track environments).

  In races, Speed gain uses the flat permanent Speed Gain formula above. Workshop gain is separate and does not use
  the equipped car or a Speed-stat diminishing term.

  Owner decision, 2026-10-27 (Speed gain rebalance, "+1 Speed" style): the equipped aura (A) and the equipped
  trail (T, new term) now multiply ALL Speed gain, race and workshop, on top of the Speed Gain stat/upgrade and the
  rebirth multi: gain = GAIN_PER_SECOND x Speed Gain stat x R x A x T (workshop: its own rate x the same A x T).
  This replaces the 2026-10-21 rule that auras never affect Speed gain. The aura also keeps its cruise-speed
  multi. The equipped car still never affects Speed gain. Aura and trail multis and prices are placeholders
  (see "What Money buys").

  Balance tip: with nine multipliers stacked, a small change to one moves everything. Model
  the numbers in a spreadsheet before building. Stat points are easier to tune if each point
  adds to its multi (e.g. +0.1x per point) rather than multiplying it.


  Starting state and Mechanical Workshop
  New players start with the starter car (1x), 0 Speed, 0 Money, level 1, 1x luck and a tier-1
  workshop. The workshop is their main source of Speed.

  Workshop requirements

         Every player gets their own workshop at their base. Server size should match the
         number of base plots (e.g. 8 plots, 8 players).



                                                                                                         Page 3 of 14


Idle Vehicle Simulator — Game Design Requirements




       Speed is earned only while the player stands inside the workshop zone. Leaving the
       zone stops the gain.
       Gain per second uses the full formula above, including the workshop multi (W).
       Money upgrades raise W in big jumps. Placeholder: each level doubles W; prices follow the price curve
       (see Racing, owner 2026-10-27).
       The Gold, Diamond and Void gamepass tiers add a larger permanent W boost (see
       Monetization).

  Heads-up on AFK: Roblox disconnects players after 20 minutes with no input
  (DevForum). A game built on idling needs a plan for that:

       Offline earnings (recommended): on rejoin, credit part of what the player would have
       earned while away. Placeholder: 25% of workshop gain, capped at 8 hours.
       Welcome-back screen: show "You were away 3h 12m, collect 4.2M Speed" so the kick
       feels like a reward, not a loss.


  Racing (core game loop)
  Racing turns Speed into Money: climb a deterministic ladder of NPC races and receive the current track's payout.

  Requirements

       Several environments (placeholder names: City, Desert, Snow, Volcano, Space). Each
       one is a ladder of tracks, like levels.
       Each track has an NPC with a fixed speed. Every next track's NPC is much faster.
       A win pays the current/last track immediately. There is no banked pot or Continue-risk mechanic.
       A loss pays nothing for that track; earlier payouts remain.
       The payout grows with the difficulty of the track beaten.

  Owner decision, 2026-10-27 (payout and price curves; constants are placeholders, the shapes are fixed):
       Track payouts grow exponentially: Track 1 pays $100 and each next track pays x10, then x7.5,
       alternating (Track 2 x10, Track 3 x7.5, Track 4 x10, ...). Track 10 pays about $31.6b. This replaces
       the old linear payout (Track N = N x $100).
       Prices grow faster than payouts so each upgrade needs more wins than the last: the price of step k
       of a ladder = its base price x (payout of Track k / payout of Track 1) ^ 1.5, rounded to two
       significant figures. It applies to workshop levels (step = level - 1, base $500), upgrade tree tiles
       (step = price depth, base $150 x branch weight) and the aura and trail ladders (step = place in the
       ladder, bases $2.5K aura and $500 trail).
       The Money cap rises from $1 trillion to $1 quadrillion (1e15), still inside exact 64-bit integers
       (REPLACED 2026-10-27: the cap is 1e30, see "Worlds").
       The player keeps earning Speed during races (see Core stat model).

  Track environments (owner, 2026-10-20; docs/BIOME_DRESSING_SPEC.md)

       Every track has one visual theme (its Biome), dressed so the auto-driven car gives an
       immersive drive-by: a repeating roadside rhythm, landmarks where the car turns or climbs,
       horizon silhouettes, and a themed gate at the track start.
       Themes are cosmetic only. They never change physics, payouts, NPC speed or race results,
       and they do not decide how environments group tracks into ladders (still an open question).
       Biomes never change global Lighting: weather events own the sky.
       Downloaded art (kenney.nl, itch.io) is CC0 only; each pack's license and source are recorded.
       Owner decision, 2026-10-21 (gate signs): every track's gate carries a sign, readable as
       the car drives in, showing the biome the player is entering and the recommended Speed
       for that track (the shown Speed whose cruise speed matches the track's NPC; see Core
       stat model). The number is computed from the live speed and NPC settings, so it stays
       correct when they are tuned, and it uses the same suffixes as the HUD.
       Owner decision, 2026-10-26 (visual pass): the drive must feel rewarding to watch. Every
       track's ground is filled beyond the roadside (scattered props and flat ground patches, so
       no stretch of the drive shows an empty plain), every track shows horizon silhouettes, and
       each biome has its own ambient particles (fireflies, dust, snowfall, embers ...) at its
       landmarks. Still cosmetic only, with the same no-Lighting rule.
       Owner decision, 2026-10-27 (scale and detail): scenery is bigger and comes in mass.
       Landmarks, horizon pieces and scattered props are built larger than their base sizes,
       and each track may hold more scenery parts. The City (Track 6) buildings are detailed
       skyscrapers (podium, setback tiers, window bands, corner fins, lit crown and rooftop
       equipment), not plain boxes. Scale factors and the part budget are placeholders.
       Owner decision, 2026-10-27 (populated city): the City reads as a populated city. Continuous
       rows of buildings line both sides of the road, two rows deep, with no wide empty gaps
       between them; the City may use more scenery parts than other tracks (placeholder).
       Owner decision, 2026-10-27 (giant scenery in every biome): taking the populated City as the
       model, every biome has large assets near the road (giant trees, rock pillars, towers,
       spires, ships ...) mixed with its small roadside props, so the player and car feel small
       in a much bigger world. Giant sizes, spacing and counts are placeholders.




                                                                                          Page 4 of 14


Idle Vehicle Simulator — Game Design Requirements




     stateDiagram-v2
       [*] --> Race
       Race --> Won: deterministic speed comparison
       Race --> Lost: deterministic speed comparison
       Won --> Race: next sequential track
       Lost --> Race: restart at checkpoint

  Sample ladder for one environment (placeholder numbers)


     Track        NPC speed               Take-home if you cash out here

     1            100                     $50

     2            500                     $300

     3            2.5K                    $2K

     4            12.5K                   $12K

     5            62.5K                   $75K


  NPC speed rises 5x per track and payout about 6x, so pushing further pays off more than
  it costs.

  Design flag: make Continue a real gamble. If a race is just "player Speed beats NPC
  speed" and both numbers are visible, players always know the result in advance. Continue
  is never risky. Options:

   1. Win chance from the speed ratio (recommended). Being faster makes a win likely, not
      certain. Luck could nudge the odds.
   2. Hide the next NPC's speed. Show a range or "???" until the race starts.
   3. Light skill check. A boost button with a timing window.

  For option 1, one simple formula (S_p = player speed, S_n = NPC speed, k = tuning knob):

     P(\text{win}) = \frac{S_p^{\,k}}{S_p^{\,k} + S_n^{\,k}}


  With k = 2, twice the NPC's speed wins 80% of the time; ten times wins 99%.

  Checkpoints (owner decision, 2026-10-16). Contract: docs/CHECKPOINT_SPEC.md.

       A "Checkpoints" NPC stands in the spawn hub beside the RACE START pavilion. Pressing its
       prompt (E) opens a panel with one card per track.
       The player picks the track their auto race starts on. Track 1 is always open; any other
       track is open only once the player has beaten it (BestTrack). A locked card is dimmed
       with a lock over it and can not be picked.
       Every run starts on the chosen track. A loss sends the car back to the chosen track,
       and after the last track the chain loops back to it.
       The choice is saved. The server checks every pick and never starts a player on a track
       they have not beaten.




                                                                                       Page 5 of 14


Idle Vehicle Simulator — Game Design Requirements




  Level system
  Players earn XP every second based on their Speed, so faster players level up faster.
  Levels matter because they unlock rebirths.

       XP per second scales with current Speed.
       Each level needs more XP than the last.
       Level milestones unlock rebirths (see next section).

  Speed grows by multiplying, so XP taken straight from Speed would make late-game levels
  fly by. Proposed: feed XP from a slower curve, like the square root of Speed. Placeholder
  formulas:

     \text{XP per second} = c \times \sqrt{\text{Speed}} \qquad \text{XP to next
     level} = 100 \times 1.15^{\,\text{level}}

       Owner decision, 2026-10-27 (replaces the square root of Speed above): XP per second follows
       the player's Speed gain multiplier, not the Speed stat: XP/s = XP_PER_SECOND (1, placeholder)
       x Speed Gain multi (Speed Gain stat/upgrade x rebirth x equipped aura x equipped trail). So
       anything that multiplies Speed gain multiplies XP gain by the same amount. XP still ticks
       while auto racing and while standing in the workshop zone.




  Rebirth system
  Rebirth trades the player's Money and Speed for a big permanent boost to Speed multi
  and Luck multi, plus Rebirth Points to spend on stats.

  Requirements

       Rebirth unlocks at level milestones: 10, 25, 50, 75, 100, then every 25 after (proposed).
       Rebirthing resets Money, Speed, Level and XP. Level returns to 1 and XP returns to 0.
       Owner decision, 2026-10-27 (rev. 2, replaces the x3 .. x20 totals with x10 per rebirth after 10,
       which grew too fast): the rebirth level sets one TOTAL Speed Gain and Luck multiplier that grows
       by addition, never by multiplication. Rebirths 1-20 add +5x each (rebirth 1 x5, 2 x10, ... 20 x100);
       the total is capped at x100 from rebirth 20 on (21, 22, 30 ... all stay x100). Level 0 stays x1.
       Owner decision, 2026-10-27 (rev. 4, replaces rev. 2 and rev. 3; based on the "+1 Speed" genre's
       public rebirth table): rebirth N needs level 15, 25, 40, 60, 75, 100, 125, 150, 175, 200, 225, 260,
       300, 340, 380, 420, 465, 510, 560, 600 (N = 1 .. 20); rebirth 20 is the last. The TOTAL multi for Speed
       gain, XP gain and roll Luck is 1.5, 2, 2.5, 3, 3.5, 4, 5, 6, 7.5, 10, then x10 per rebirth up to x100b.
       XP to next level = 10 x level up to level 225, then 2,250 x 10^((level - 225) / 40) (placeholders), so
       one rebirth takes at most about 7.5 h at base gain. XP per second = 1 x the Speed gain multi.
       Owner decision, 2026-10-28 (replaces the 10 and 40 above; balance sim fit, tools/balance_sim.py, for
       World 1 in about 30 h): XP to next level = 122 x level up to level 225, then 27,450 x
       10^((level - 225) / 37.2) (placeholders).
       Owner decision, 2026-10-27 (rev. 3, replaces the +5x step of rev. 2, which made gain too slow):
       still by addition, but rebirths 1-40 add +25x each (rebirth 1 x25, 2 x50, ... 40 x1000); the total
       is capped at x1000 from rebirth 40 on. Level 0 stays x1. The step and the cap are placeholders.
       Rebirths do not multiply race payout Money; Money upgrades and temporary Money effects remain separate.
       Each rebirth also gives Rebirth Points to spend on four stats.
       Rebirth Points per rebirth: 1 (placeholder; owner 2026-10-15). They join the same free stat
       point pool as the car index (StatPoints) and are spent on the same four stats; they are derived
       from the rebirth count, never saved separately.

       Owner decision, 2026-10-27: the Roblox player list shows the current rebirth level as a third
       leaderstat, Rebirth, after Money and Speed. The server keeps it equal to RebirthLevel.

       Active milestone rule: if level resets on rebirth, each rebirth needs the next milestone; after level 100,
       milestones continue at 125, 150, 175 and so on without a cap.
  Rebirth 1 at level 10, rebirth 2 at level 25, and so on. That gives rebirths a rising cost.

  Stats (bought with Rebirth Points)




                                                                                                Page 6 of 14


Idle Vehicle Simulator — Game Design Requirements




     Stat                                           What it boosts                       Per point (placeholder)

     Base Speed Multi                               All Speed gain                       +0.1x

     Base Money Multi                               Race payouts                         +0.1x

     Luck Multi                                     Car roll odds                        +0.05x

     Mechanical Workshop Multi                      Workshop gain only, on top of W      +0.2x


  Speed and Luck grow two ways: the automatic rebirth bonus and stat points. That's fine,
  but the rebirth screen should show both so players see where their boost came from.

  Rebirth screen (owner 2026-10-15, docs/REBIRTH_SPEC.md): a WARNING that Money and Speed reset
  (Robux purchases stay), REWARDS UNLOCKED tiles for the next rebirth (+Luck, +Speed gain, +1 Rebirth
  Stat Point), REQUIREMENTS as a player-level progress bar to the next milestone, and the REBIRTH button.

  What resets and what stays


     Item                                           On rebirth

     Money                                          Resets (brainstorm)

     Speed                                          Resets (brainstorm)

     Level                                          Resets to 1

     XP                                             Resets to 0

     Car inventory                                  Kept (proposed): rare cars take too long to re-roll

     Auras, trails                                  Kept (owner 2026-10-27)

     Fuel, spoilers                                 Open

     Workshop money upgrades                        Open

     Jett Fuel upgrades                             Open

     Rebirth Points and stats                       Kept

     Gamepass perks                                 Always kept




  Worlds (owner decision, 2026-10-27; contract: docs/WORLDS_SPEC.md)
  Owner decision, 2026-10-27 (cruise cap and worlds):
       Cruise speed is capped at RaceConfig.MAX_CRUISE: just under the speed where the car starts to
       fail the stability tests (flip, tilt or leaving the path), kept between 700 and 800 studs/s.
       Set to 800 studs/s on 2026-10-27 (the speed probe was clean up to 1000). Speed numbers keep
       growing past the cap; cruise does not.
       The game has two worlds. World 1 is today's game: rebirths 1-10 (x1.5 .. x10). Reaching
       rebirth 10 unlocks World 2, a separate Roblox place in the same universe, reached through a
       portal in the hub; players can travel back and forth. Rebirths 11-20 (x100 .. x100b) happen
       only in World 2; World 1 refuses rebirths past 10.
       Owner decision, 2026-10-28 (interim): until World 2 ships, the single place allows rebirths 1-20
       and refuses only at 20; the World 1 cap at 10 starts with the World 2 release.
       World 2 has its own 10 new tracks and biomes, its own NPC ladder, payouts that continue from
       World 1's (World 2 Track n pays like Track 10 + n) and its own Speed -> cruise table: cruise
       starts at 150 studs/s (owner 2026-10-27, so a 30k-stud track never takes half an hour) and needs far
       bigger Speed numbers, under the same cap. Saved Money, MoneyEarned, single payouts and admin
       amounts are all capped at 1e30 (was 1e15; payouts were capped at 1e9), and leaderstats.Money is a
       NumberValue (an IntValue stops at about 9.2e18). Leaderboards store int64, so scores tie past 9e18.
       Kept per world: Speed, BestTrack, Checkpoint, race best times, Level and XP.
       Shared by both worlds: cars, index, Copies and Showcase, Money, rebirths and their multi,
       upgrades, auras and trails.
       World 2 content (owner, 2026-10-27, "even bigger"): long, very wide tracks through massive mega
       biomes; road width 160, tracks 30k-60k studs, one 14k x 14k biome tile per track in a 5 x 2 snake,
       Terrain plus streamed props. Biomes in order: Meadow Valleys, Blossom Terraces, Coral Lagoon, Titan
       Redwoods, Crystal Caverns, Sky Archipelago, Aurora Glacier, Sunset Mesas, Glowshroom Marsh, Nebula
       Rift. In World 2 only, each biome may blend its own Sky, Atmosphere and colour grade on the client
       (an exception to "props never touch global Lighting"; World 1 keeps that rule). Sizes are placeholders.
       Pacing targets for an average free player: about 30 hours to clear World 1 and reach
       rebirth 10, then about 35 hours to clear World 2 and reach rebirth 20. Constants are fitted
       by tools/balance_sim.py and approved by the owner (placeholders until then).

  Economy (Money)
  Money comes from one place, race cash-outs, and gets spent on permanent Speed
  boosts.

Superseded by the owner, 2026-10-22 (Workshop Showcase): duplicate cars are NO LONGER sold. Every
duplicate roll is kept as a saved copy of that car, and copies of the three cars shown in the
player's workshop raise workshop Speed gain (docs/WORKSHOP_SPEC.md "Showcase"). (Old rule: Money
could also be made from auto selling duplicate cars, about 5 dollars for the starter car.)

  Owner decision, 2026-10-22: race cash-outs are now the ONLY source of Money (duplicate sales
  were removed). Earlier wording, 2026-10-12: these two are the ONLY sources of Money. Nothing else pays Money:
  not the workshop, not offline earnings (Speed only), not daily login rewards (potions and a
  guaranteed rare car only), not duels. A weather event's Money multiplier scales a race payout;
  it is not a new source.

  Source: race payouts, multiplied by the Base Money Multi stat and the 2x Money
  gamepass. Idle players earn Speed but no Money, which pushes everyone to race
  (confirmed by the owner, 2026-10-12).




                                                                                                               Page 7 of 14


Idle Vehicle Simulator — Game Design Requirements




  What Money buys


     Purchase                         Effect                               Notes

     Fuel types                       Speed multi (F). Pricier fuel,       Open: one-time unlock, or burns
                                      higher multi                         over time?

     Car aura                         Speed multi (A) plus a visual        One equipped at a time (proposed)
                                      effect

     Trail                            Speed Gain multi (T) plus a visual   One equipped at a time

     Spoilers                         Speed multi (P) plus a visual part   One equipped at a time (proposed)

     Workshop                         Workshop multi (W)                   See workshop section
     upgrades

     Jett Fuel                        Stronger or more frequent luck       See gacha section
     upgrades                         bursts


  Draft aura (owner 2026-10-26): a golden "Super Saiyan" style ki aura inspired by Dragon Ball Z
  (internal id ascended_aura, working name "Ascended Aura": the Dragon Ball names stay out of the game).
  It is shown only in the VFX showcase area for review and is not sold yet. Open question: its price,
  its Speed multi (A) and whether it joins the Market.


  Aura and trail ladders (owner 2026-10-27, placeholder numbers; prices follow the price curve under Racing). Both multiply all Speed gain; the
  aura also multiplies cruise speed. Both are kept on rebirth.


     Trail              Speed Gain multi        Cost              Aura             Speed multi    Cost

     Rainbow            1.5x                    $500              Azure            1.2x           $2.5K

     Solar              2x                      $16K              Ember            2x             $79K

     Void               3x                      $320K             Galaxy           3x             $1.6M

     Frost (new)        4x                      $10M

     Prism (new)        5x                      $210M


  Sample fuel ladder (placeholder numbers)


     Fuel               Speed multi             Cost

     Regular            1x                      Free

     Premium            1.5x                    $1K

     Racing             2.5x                    $25K

     Nitro              5x                      $500K

     Plasma             10x                     $10M


  If fuel, auras and spoilers reset on rebirth, players re-buy them every run and Money stays
  important. If they're kept, Money matters less after the first few rebirths.



  Car gacha
  Players auto-roll for cars for free; rarer cars carry bigger Speed multipliers, and Luck
  makes rare cars more likely.

  Requirements

       Open gacha: rolls cost nothing and every car's odds are shown in-game (assumed
       meaning of "open", confirm).



                                                                                                         Page 8 of 14


Idle Vehicle Simulator — Game Design Requirements




       Auto-roll runs passively. Placeholder: one roll every 3 seconds.
       Base luck is 1x. Stats, rebirths, gamepasses, Server Luck and Jett Fuel raise it.
       Rolled cars go to an inventory. The player equips one car at a time.
       Rarer car, higher Speed multi.

  How luck works (proposed). Each car has a "1 in N" chance. A roll checks cars from rarest
  to most common and awards the first hit. Luck L divides N:

     P(\text{hit this car}) = \min\left(1, \frac{L}{N}\right)


  So at 10x luck, a 1-in-1,000 car becomes 1-in-100.

  Sample rarity table (placeholder, two cars from the brainstorm)


     Car                             Rarity         Base chance                   Speed multi

     Rusty Hatchback                 Common         Catch-all (whatever's left)   1.1x

     Wooden Car                      Uncommon       1 in 10                       1.25x

     Go-Kart                         Rare           1 in 50                       2x

     Street Racer                    Epic           1 in 250                      6x

     Rocket Car                      Legendary      1 in 1,000                    25x

     Hover Car                       Mythic         1 in 10,000                   150x

     Void Racer                      Secret         1 in 100,000                  1,000x


  Every roll must return something, so the table needs a catch-all common. The brainstorm's
  1-in-10 Wooden Car leaves 90% of rolls undefined otherwise.

  Owner decision, 2026-10-27 (odds rev., replaces every car's Chance; rebirth Luck now reaches x100b): each
  rarity spans its own band, cars spaced evenly on a log scale in their old order, values rounded to 2
  significant figures. Inspired by public RNG games (Sol's RNG: about x10 per tier, top auras 1 in 1-3b), pushed
  further because our Luck stack is far larger. Bands: Uncommon 1 in 10 .. 200, Rare 500 .. 25k, Epic 50k .. 2.5m,
  Legendary 10m .. 1b, Mythic 5b .. 1qd, Secret 10qd .. 5qt (the rarest-car leaderboard stores Chance as an int64, max about 9.2e18). Odds show with the HUD suffixes from 1,000
  ("1 in 2.5m", "1 in 32qd"). Speed multis, ids and rarities are unchanged. Bands are placeholders.

  Owner expansion, 2026-10-20 (docs/CAR_EXPANSION_SPEC.md):
       Add 100 original base rollable cars: 18 Uncommon, 24 Rare, 22 Epic, 17 Legendary,
       11 Mythic, and 8 Secret (8 explicitly approved). Rusty Hatchback remains the only
       Common catch-all. Existing permanent ids, event cars and gamepass exclusions stay.
       Five visual families have 20 cars each: city/utility, off-road/rally, track/hyper,
       futuristic/hover, fantasy/novelty. All skins use the shared invisible physics body.
       Chance and SpeedMulti bands are recorded in the expansion spec/manifest. Art must
       be original, with source/export/preview notes; no assets extracted from other games.

  Owner car art redesign, 2026-10-20 (docs/CAR_REDESIGN_SPEC.md):
       Every car with a redesign reference (111 of 112; Ember Wyvern has none and keeps its
       model) is rebuilt as a Blender-modelled MeshPart skin that matches its reference
       render: bevelled body, separate wheels, colour from Roblox materials. The references
       are modelling aids only and are never shipped or committed. Midnight Kart, Golden
       Racer and Rain Runner get their own models instead of sharing Go-Kart, Rocket Car and
       Street Racer. Ids, rarities, chances and multipliers do not change; the skin never
       changes physics. Delivered in waves of about 20 cars, each approved by the owner.
       Owner, 2026-10-20 (after review): every car gets a slightly aggressive sport look
       (front splitter with a neon lip, rear diffuser, low lip spoiler unless it has a wing,
       wider tyres, lower stance) while keeping its identity. Glowing details are bright neon.
       Singularity keeps its black hole: a dark core inside a tilted neon-gold ring.
       Owner, 2026-10-26 (car finish + geometry pass): every car skin gets a showroom finish
       (glossy paint, reflective metal and glass, glowing parts cast no shadow) and a geometry
       pass in Blender (more bevels, panel lines and wheel detail) within the existing budget
       and identity. Delivered in waves the owner approves (docs/CAR_REDESIGN_SPEC.md section 8).
       Owner, 2026-10-27 (Ember Wyvern draft): special-case rides such as the Ember Wyvern
       may go over the per-car triangle budget and may use textures (painted scales); every
       other car keeps the budget and flat colours. The Ember Wyvern follows the owner's
       references: a black shadow-flame wyvern with glowing cyan markings, cyan wing
       membranes with tattered flame edges and blue fire effects (owner, 2026-10-27, replacing
       the earlier black-and-amber look). Inspiration only: the design stays original, no
       existing character is copied.
       Owner, 2026-10-27 (Ember Wyvern flight, docs/WYVERN_FLIGHT_SPEC.md): the Ember Wyvern
       flies: while auto racing and on its pedestal the wings flap in bursts and glides and the
       body moves (neck, tail, heave, bank and head turn into curves), played on each client
       only. As an exception it is shown much bigger than other rides (SkinScale, placeholder
       2.5, owner 2026-10-27 "a lot bigger"; pedestal capped at 1.6) with a long whip tail. The physics body never changes, so speed, payouts and
       every stability rule stay the same; a physics test suite covers it.
       Owner, 2026-10-27 (Ember Wyvern breath, docs/WYVERN_BREATH_SPEC.md): the Ember Wyvern
       breathes blue fire in bursts during each glide between wingbeats, while racing and on
       its pedestal. Client-only particles in the cyan palette with the uploaded VFX textures;
       nothing changes physics, speed or payouts.
       Owner, 2026-10-27 (car redesign v3, docs/CAR_REDESIGN_SPEC.md section 10): every car
       skin moves to a stylised toy racer look: chunky, rounded bodies, big chunky wheels, short
       overhangs and a taller, bubblier cabin, keeping each car's colours and signature parts.
       The per-car budget rises from 6,000 to 15,000 triangles. Applies to all 111 cars with a
       reference; the Ember Wyvern and the built-in starter keep their models. Flat colours stay
       (no textures). A 3-car pilot (Rusty Hatchback, Street Racer, Singularity) is approved
       by the owner before the other cars are rebuilt. Proportion numbers are placeholders.
       Owner, 2026-10-27 (after approving the pilot): the rollout keeps big rear wings as they are.
       Owner, 2026-10-27 (Singularity orb, docs/CAR_REDESIGN_SPEC.md section 11): Singularity's
       black hole is smaller and floats above the engine deck (no stand). It spins and bobs up
       and down, with a bright neon glow around its black core. The motion plays on each client
       only; it never changes physics, speed or payouts.

  Owner rendering pass, 2026-10-26 (docs/RENDERING_SPEC.md):
       The world gets a richer lighting baseline (coloured ambient, colour grading, soft
       shadows, light haze), real surface materials on roads and walls instead of flat
       plastic, and level-of-detail rules so phones keep their frame rate. Weather events
       still own the sky and restore this baseline when they end. Purely visual: nothing
       here changes physics, payouts or race results.

  Jett Fuel (luck burst, shown in game as TURBO LUCK)

  Owner decision, 2026-10-12 (replaces the brainstorm's "every 50 rolls, 10x"):

       It starts at every 10 auto-rolls: the 10th roll gets 10x luck, stacked on top of the
       player's normal luck.
       Upgradeable with Money (the Turbo branch of the upgrade tree). Every tier raises both
       numbers: the rolls needed per burst and the luck multi.

     Jett Fuel level            Triggers every      Luck on that roll

     Start (no upgrade)         10 rolls            10x
     Turbo I                    50 rolls            50x
     Turbo II                   200 rolls           200x
     Turbo III                  500 rolls           500x
     Turbo IV                   1,000 rolls         1,000x

  Owner decision, 2026-10-12: a longer wait is fine as long as the multi is a lot bigger. This
  overrides the earlier design flag about never lengthening the interval. Prices: the upgrade
  tree's price table (docs/UPGRADE_TREE_SPEC.md).

  Rules for paid luck. Roblox treats paid luck boosts as paid random items (Creator Hub).
  That covers the luck gamepasses and Server Luck:

         Show each car's odds as a percentage, summing to 100%.
         Explain a luck purchase's effect in numbers before purchase.
         Keep the catalog rarity visible while boosts are active; boosts change the server's actual roll probability,
         not the advertised "1 in N" rarity.
         Check ArePaidRandomItemsRestricted per player and block or hide paid luck for
         restricted players.


  Monetization
  Each Robux item is either a gamepass (bought once, owned forever) or a developer
  product (can be bought again and again) (Creator Hub). Items that stack with every
  purchase can't be a single gamepass.


     Item                              Effect                       Roblox type               Notes

     2x Auto-Roll                      Auto-roll runs twice as      Gamepass                  More rolls: treat as
     Speed                             fast                                                   paid luck (see
                                                                                              gacha rules)

     Extra Roll I                      +1 simultaneous auto-roll    Gamepass                  Same as above
                                       (2 total)

     Extra Roll II                     +1 more (3 total)            Gamepass                  Sold only after
                                                                                              Extra Roll I

     Speed Doubler                     2x Speed; each buy           Chain of                  Needs a cap
                                       doubles it again (2x, 4x,    gamepasses
                                       8x). Price doubles each      (Speed I, II, III...)
                                       time




                                                                                                                Page 10 of 14


Idle Vehicle Simulator — Game Design Requirements




     Item                              Effect                       Roblox type          Notes

     2x Money                          Doubles race payouts         Gamepass

     +1 Luck                           +1 permanent base luck       Gamepass             Paid luck rules
                                                                                         apply

     +2 Luck                           +2 permanent base luck       Gamepass             Paid luck rules
                                                                                         apply

     Server Luck                       2x luck for the whole        Developer product,   Paid luck rules
                                       server, 15 min. Each extra   one per tier         apply. Buyer can
                                       buy doubles the multi,                            pause
                                       doubles the price, adds
                                       15 min

     Workshop tiers:                   Each tier raises the         Chain of             Each requires the
     Gold, Diamond,                    workshop multi (W)           gamepasses           tier before
     Void


     Gamepass cars (owner, 2026-10-13. Contract: docs/GAMEPASS_CARS_SPEC.md):
       Two cars are sold as gamepasses, one pass per car: Ember Wyvern (a dragon) and
       Singularity (a black-hole hypercar). They are never rolled and are not in the Index.
       Each stands on a small pedestal beside the Best Roll Ever pedestal; walking up to it
       offers the purchase. Their speed multis are proposed values.
       Owner, 2026-10-16: Ember Wyvern is the stronger car (Secret, listed at 1999 Robux) and
       Singularity the cheaper one (Mythic, listed at 999 Robux). Both are the top (FEATURED)
       section of the Shop.
       Owner, 2026-10-20: a bought gamepass car is playable: it can be equipped from its
       pedestal, the Shop and the Backpack. Admins own every gamepass car. Singularity's
       model is a sharp, original wedge supercar with the black hole in its engine bay.

     Shop (owner, 2026-10-16. Contract: docs/GAMEPASS_SHOP_SPEC.md):
       The HUD Shop is one scrolling panel in sections, top to bottom: FEATURED (the two
       gamepass cars), Gamepasses, Potions (potion packs and a Potion Bundle), DOUBLE Server
       Luck, Codes.
       Each Robux item shows a listed price kept in the game's config (proposed values, except
       the two cars). Once the item has a real Roblox id, the Shop shows Roblox's own live
       price instead. Roblox still charges what the Creator Dashboard says.
       Potion packs and the Potion Bundle are developer products (bought again and again).
       The server grants the potions into the player's saved potion counts when Roblox
       confirms the purchase, exactly once per purchase (docs/SHOP_PURCHASES_SPEC.md).
       Potions never pay Money; a Money potion multiplies race payouts, it is not a new source.

     Codes (owner, 2026-10-16. Contract: docs/SHOP_PURCHASES_SPEC.md):
       The Shop has a code box. A valid code gives potions, once per player. Codes never pay
       Money. The code list lives only on the server.

     Gifting (owner plan, approved 2026-10-20; docs/PANEL_ART_GIFTING_SPEC.md):
       Potion packs and the potion bundle may be gifted to another player currently in
       the server. Gamepasses/gamepass cars are account-bound and Server Luck is server-wide,
       so neither is giftable. The buyer selects a recipient and confirms before Roblox's
       purchase prompt. Server-owned product definitions determine every grant.
       A durable recipient mailbox and purchase-id deduplication protect offline delivery
       and retries. A receipt is acknowledged only after its mailbox grant is durable.
       Gift state was introduced as additive VERSION 10 data; it is part of the current VERSION 11 schema and older
       saves default to empty gift state.

  Implementation notes

       Rising prices need one item per tier. Each gamepass or product has one fixed price.
       "Price doubles each time" means separate items (Server Luck 2x, 4x, 8x) and
       prompting the next one.
       Speed Doubler as a gamepass chain (recommended). Roblox tracks pass ownership
       for you. A developer product would mean saving the purchase count yourself.
       Cap the Speed Doubler. Uncapped doubling lets one big spender outgrow every
       balance number. Placeholder cap: 5 buys (32x).
       Luck passes add to base luck before multipliers (proposed). +1 doubles a new player's
       luck but barely matters late game.
       Server Luck edge cases. Proposed: only the buyer can pause; if the buyer leaves, the
       timer resumes and runs out normally.


  Duels (player vs player)
  Owner decision, 2026-10-12. Contract: docs/DUEL_SPEC.md.

       A player can request a duel against another player in the same server.
       The challenger is asked at once which track to race. Only tracks BOTH players have
       unlocked can be picked.
       The other player accepts or declines. No answer counts as a decline.
       Both cars race that one track at the same time. The first car to reach the finish wins;
       the server decides it.
       There is no stake. No Money moves and nobody loses anything. The winner's saved Duel
       Wins count goes up by one.
       Both players keep earning Speed during the duel, like any race.

  Global leaderboards
  Owner decision, 2026-10-12. Contract: docs/LEADERBOARD_SPEC.md.

       Signs in the spawn area show the top players across all servers for: Speed, Money
       earned (lifetime), rolls, and rarest car.
       The leaderboard signs are large showcase boards, approximately 32 by 20 studs each, arranged in a compact row
       inside the hub so their rows are readable from the spawn approach without blocking the race-start pavilion.
       Server-only: the server writes and reads the boards; clients only see the signs.
       A rebirth never lowers a player's place on the Speed board (it shows the best Speed
       reached).
       Owner decision, 2026-10-13: a BEST ROLL EVER pedestal in the spawn area shows the rarest
       car any player has rolled across all servers (the top row of the rarest-car board). The
       car turns slowly on a round platform; its odds, its name and the player's name are shown
       above it.

  Weather events
  Contract: docs/WEATHER_EVENTS_SPEC.md.

       Owner decision, 2026-10-13 (replaces "every 10 to 20 minutes" and the three-event list):
       every 15 minutes a server-wide weather runs for a few minutes. The server picks one of
       five at random: Clear, Rain, Night Race, Gold Rush, Aurora. It changes luck, race
       payouts or NPC speed, and the sky and lighting (Clear changes nothing).
       For now every weather has the same chance (1 in 5). Planned, not built: weathers with
       bigger benefits will get a lower chance to appear.
       A small weather icon sits at the bottom right of the HUD. Hovering it (tapping on touch)
       shows the weather's name and what it changes.
       The 15 minutes, the weather list and each weather's numbers are placeholders.
       Luck from an event is free and changes actual server roll probability. The roll animation continues to show
       each car's base catalog rarity so a temporary boost never makes a car's advertised rarity misleading.

  HUD layout
  Contract: docs/HUD_LAYOUT_SPEC.md.

       Owner decision, 2026-10-27 (HUD art and hover): use the approved simple
       transparent cartoon icons; Shop is a red/tan house, Items a brown backpack,
       Market a detailed red shopping bag without coin/logo. Hover feedback is
       slight enlargement only, with no white outlined hover box. The icon set,
       layouts/actions and existing accessibility behavior are documented in
       HUD_LAYOUT_SPEC.md; no economy or gameplay values change.

  Race progress map
       During NPC auto-races, the HUD shows the current track's non-interactive
       route map and personal-best timer described by docs/RACE_PROGRESS_MAP_SPEC.md.
       It is presentation-only, private to the player, and never changes race
       authority or applies to Duel mode.

       Owner decision, 2026-10-15 (replaces the left INDEX / STATS / REBIRTH text column and the
       right-side button stack): cartoon icon tiles with the label under each icon. Index,
       Stats and Rebirth are on the left edge, Shop is on the right edge, and Items and Upgrade
       sit left and right of the level bar at the bottom centre. Daily, Quests and
       Market are Roblox-style pills at the top right, next to a round Settings button. Items
       opens the Backpack (Misc, Trails, Auras and Cars tabs; owner 2026-10-20: the Cars tab lists owned cars least
       rare first and equips on click; the Index remains the discovery gallery). Settings keeps its current
       options in the new look. Active potions show bottle icons with the time left under each.
       No buttons or panels may overlap at any screen size.

       Owner decision, 2026-10-26 (accessibility and devices; details in docs/HUD_LAYOUT_SPEC.md
       section 7): the UI respects reduced motion (Roblox's Reduced Motion setting or the in-game
       REDUCED EFFECTS toggle: tweens land at once and the roll reel lands without spinning);
       interactive UI stays inside the device safe area (notches), while full-screen dims and
       overlays may still bleed edge to edge; console is supported: opening a panel with a
       gamepad selects its first button, focus stays inside the panel, B closes it and closing
       restores the previous selection.

       Owner decision, 2026-10-27 (UI visual pass; details in docs/HUD_LAYOUT_SPEC.md sections
       8-10, docs/NPC_RACER_SPEC.md "Loser screen" and docs/RACE_PROGRESS_MAP_SPEC.md):
       every screen shares one theme (Fredoka text with a dark outline, the theme's corner radii,
       gradient plates, multipliers written "x1.5"). Money and UNBANKED sit on gradient plates and
       count up smoothly with a pop on gain. The Speed stat sits in the centre of a speedometer
       dial whose needle shows the car's real speed (studs/s) while auto racing and rests at 0 on
       foot; the dial is presentation-only and the displayed number stays the base Speed stat.
       The loser screen is a full race recap. The progress map gets a smooth route, a heading
       arrow, the NPC's name and the time gap. The UI uses motion graphics (pops, slide-ins,
       shines, pulses) that all respect reduced motion.
       Owner decision, 2026-10-27 (checkpoint panel, docs/CHECKPOINT_SPEC.md section 4): each
       checkpoint card shows a small 3D preview of its biome, the track number and biome name; clicking a
       card shows its recommended Speed (as on the gate sign) against the player's Speed in a detail pane
       with a START HERE button.

       Owner plan, 2026-10-20: Daily Rewards, Quests, Shop and Market share the Backpack
       frame vocabulary (header/icon/title, red X, rounded frame, backdrop, tabs, PanelBand).
       Daily retains its red styling and all existing panel contents/remotes remain.
       Trails and auras get shared authored transparent icons and distinct cosmetic
       in-world profiles, applied to the shared chassis without changing physics or equip authority.

  Technical and data requirements
  The server decides every number (Speed, Money, rolls, race results) and the client only
  displays it. That's the main defense against exploiters.

       Server-authoritative. Compute Speed gain, payouts, rolls and race outcomes on the
       server. Never trust a value the client sends.



                                                                                                           Page 11 of 14


Idle Vehicle Simulator — Game Design Requirements




       Workshop zone check on the server. Check the character's position on a timer instead
       of trusting client-side touch events.
       Purchases. Grant developer products inside ProcessReceipt on the server. If the
       grant fails, return NotProcessedYet so Roblox retries next join. Roblox doesn't store
       per-player product history, so save it yourself (Creator Hub).
       Big numbers. Luau numbers are 64-bit floats: exact up to about 9 quadrillion, max
       about 1.8e308. Stacked multipliers will get there. Build number abbreviations (1.2k,
       3.4m, 5.6qd; owner 2026-10-27) from day one.
       Saving. Use DataStores with session locking so data can't duplicate across servers;
       libraries like ProfileStore handle this. Save on leave, on an interval and on server
       shutdown ( BindToClose ).
       Paid luck compliance. Odds display and restricted-player checks, as listed under Car
       gacha.

  Per-player saved data

       Speed, Money, level, XP
       Rebirth count, Rebirth Points, stat allocation
       Car inventory and equipped car
       Owned and equipped fuel, aura, spoiler
       Workshop upgrade level, Jett Fuel level, roll counter
       Developer product purchase records (receipt IDs)
       Last logout time, for offline earnings
       Lifetime Money earned and Duel Wins (leaderboards, duels)
       Session lock (which server holds the save, and since when)


  Open questions
  These decisions change what gets built. Tick them off as you decide.

  Racing

       How is a race decided: speed check, win chance, hidden NPC speed or skill check?
       Is the payout a pot that grows with each win, or just the last track's reward?
       How do environments unlock: by level, or by clearing the previous environment?
       Do races get every multiplier except the workshop, or a flat base rate?

  Progression

       Daily and weekly quests (docs/QUESTS_SPEC.md) track core-loop actions, reset on UTC periods, and reward existing
       potion items. They never create a second Money source.

       What survives rebirth: cars, fuel, auras, spoilers, workshop upgrades, Jett Fuel?


                                                                                           Page 12 of 14


Idle Vehicle Simulator — Game Design Requirements




         Can players reset (respec) their Rebirth Points?
         Do levels unlock anything besides rebirths?
         Offline earnings: yes or no, and what percent and cap?

  Economy and gacha

         Should idle players earn any Money, or only racers?
         Is fuel a one-time unlock or used up over time?
         Are workshop money upgrades and the Gold/Diamond/Void passes one track or two?
         Does "open gacha" mean free rolls with public odds?
         Inventory: size cap, auto-delete below a chosen rarity? (Duplicates DECIDED 2026-10-22:
         kept as copies, never sold; they power the Workshop Showcase.)
         Jett Fuel upgrades: DECIDED 2026-10-12. Each tier raises both the roll count and the
         multiplier: 10/10x, 50/50x, 200/200x, 500/500x, 1,000/1,000x.

  Monetization

         Speed Doubler cap: how many purchases?
         Server Luck: can several players stack it at once?


  Suggested build order
  Build the core loop first and add layers on top, so there's something playable after every
  phase.


     Phase         Build                                                Playable result

     1             Starter car, workshop zone, Speed gain, saving       Idle and watch Speed climb

     2             One environment, 5-track ladder, cash out or         Core loop works
                   continue, Money

     3             Fuel, auras, spoilers, workshop upgrades             Money has something to buy

     4             Levels, rebirth, stat points                         Long-term progression

     5             Car gacha, auto-roll, inventory, Jett Fuel           Collection layer

     6             Gamepasses, Server Luck, odds display, restricted-   Ready to monetize
                   player checks




                                                                                                Page 13 of 14


Idle Vehicle Simulator — Game Design Requirements




  Sources
       Paid random items policy guidelines, Roblox Creator Hub
       Developer Products, Roblox Creator Hub
       Remove the 20 minutes idle kick, Roblox DevForum




                                                                 Page 14 of 14


