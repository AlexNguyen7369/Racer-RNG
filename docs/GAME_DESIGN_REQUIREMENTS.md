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
       Push your luck. After each race win, players bank the money or risk it on a harder race.
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
  Proposed: every source is a multiplier, and Speed gain per second is all of them multiplied
  together. The brainstorm doesn't say how they stack, so this is a starting point to confirm.


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
       can tell apart. There is no hard cap on cruise speed.
       Maths (same date; the constants are placeholders, the shapes are fixed):
       Race Speed gain per second = GAIN_PER_STUD x actual car speed x the gain multipliers.
       Nothing divides it by the Speed stat. A higher Speed gives a faster car, a faster car
       gives more gain, so the number climbs faster and faster.
       Workshop Speed gain per second = BASE_RATE x Speed multi x workshop level x Workshop
       points. Nothing divides it by the Speed stat; it rises with the workshop level and the
       multipliers. Offline earnings are that rate x the offline share x the capped time.
       Cruise speed = BASE_SPEED + (MAX_SPEED - BASE_SPEED) x log2(1 + Speed / HALF_STAT) / 2,
       x the car's speed multi. Every doubling of Speed (well above HALF_STAT) adds the same
       (MAX_SPEED - BASE_SPEED) / 2 studs per second: diminishing per point, never flat, no cap.

  In races, Speed gain uses the same formula without W (proposed). Confirm whether
  races should get every other multiplier or only a flat base rate.

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
       Money upgrades raise W in big jumps. Placeholder: each level doubles W and costs 5x
       the last.
       The Gold, Diamond and Void gamepass tiers add a larger permanent W boost (see
       Monetization).

  Heads-up on AFK: Roblox disconnects players after 20 minutes with no input
  (DevForum). A game built on idling needs a plan for that:

       Offline earnings (recommended): on rejoin, credit part of what the player would have
       earned while away. Placeholder: 25% of workshop gain, capped at 8 hours.
       Welcome-back screen: show "You were away 3h 12m, collect 4.2M Speed" so the kick
       feels like a reward, not a loss.


  Racing (core game loop)
  Racing turns Speed into Money: climb a ladder of NPC races, then bank the pot or risk it
  on a harder race.

  Requirements

       Several environments (placeholder names: City, Desert, Snow, Volcano, Space). Each
       one is a ladder of tracks, like levels.
       Each track has an NPC with a fixed speed. Every next track's NPC is much faster.
       After a win, the player picks Cash out (take the money, go home) or Continue (race the
       next track).
       A loss wipes all unbanked money from that run.
       The payout grows with the difficulty of the track beaten.
       The player keeps earning Speed during races (see Core stat model).




                                                                                          Page 4 of 14


Idle Vehicle Simulator — Game Design Requirements




     stateDiagram-v2
       [*] --> Race
       Race --> Won: beat the NPC
       Race --> Lost: NPC wins
       Won --> CashOut: bank the pot
       Won --> Race: continue, harder NPC
       Lost --> Home: pot lost
       CashOut --> Home


  Each win raises the pot; each Continue puts the whole pot at risk.

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




  Rebirth system
  Rebirth trades the player's Money and Speed for a big permanent boost to Speed multi
  and Luck multi, plus Rebirth Points to spend on stats.

  Requirements

       Rebirth unlocks at level milestones: 10, 25, 50, 75, 100, then every 25 after (proposed).
       Rebirthing resets Money and Speed.
       Each rebirth gives a large automatic boost to Speed multi (R) and Luck multi.
       Each rebirth also gives Rebirth Points to spend on four stats.
       Rebirth Points per rebirth: 1 (placeholder; owner 2026-10-15). They join the same free stat
       point pool as the car index (StatPoints) and are spent on the same four stats; they are derived
       from the rebirth count, never saved separately.

  Proposed milestone rule: if level resets on rebirth, each rebirth needs the next milestone.
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

     Level                                          Open: resetting fits the milestone rule above

     Car inventory                                  Kept (proposed): rare cars take too long to re-roll

     Fuel, auras, spoilers                          Open

     Workshop money upgrades                        Open

     Jett Fuel upgrades                             Open

     Rebirth Points and stats                       Kept

     Gamepass perks                                 Always kept




  Economy (Money)
  Money comes from one place, race cash-outs, and gets spent on permanent Speed
  boosts.

Money can also be made from auto selling duplicate cars (already discovered cars) Cars should be relativley cheap when sold (about 5 dollars for starter car and scale up but small)

  Owner decision, 2026-10-12: these two are the ONLY sources of Money. Nothing else pays Money:
  not the workshop, not offline earnings (Speed only), not daily login rewards (potions and a
  guaranteed rare car only), not duels. A weather event's Money multiplier scales a race payout;
  it is not a new source.

  Source: race cash-outs, multiplied by the Base Money Multi stat and the 2x Money
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

     Spoilers                         Speed multi (P) plus a visual part   One equipped at a time (proposed)

     Workshop                         Workshop multi (W)                   See workshop section
     upgrades

     Jett Fuel                        Stronger or more frequent luck       See gacha section
     upgrades                         bursts


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

       Owner decision, 2026-10-15 (replaces the left INDEX / STATS / REBIRTH text column and the
       right-side button stack): cartoon icon tiles with the label under each icon. Index,
       Stats and Rebirth are on the left edge, Shop is on the right edge, and Items and Upgrade
       sit left and right of the level bar at the bottom centre. Daily, Quests and
       Market are Roblox-style pills at the top right, next to a round Settings button. Items
       opens the Backpack (Misc, Trails and Auras tabs; cars are only in the Index). Settings keeps its current
       options in the new look. Active potions show bottle icons with the time left under each.
       No buttons or panels may overlap at any screen size.

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
       about 1.8e308. Stacked multipliers will get there. Build number abbreviations (1.2K,
       3.4M, 5.6Qa) from day one.
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

       Does level reset on rebirth?
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
         Inventory: size cap, duplicates, auto-delete below a chosen rarity?
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


