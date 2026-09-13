# squishy-merge-game

A reskinnable Roblox **merge tycoon**. Every player gets a plot, units spawn on
it over time, dragging one unit onto a matching one merges them into the next
tier, and higher tiers earn more cash per second.

The mechanics, layout and UI live in one codebase. A new game is a new **theme**
plus a few IDs — no gameplay code is copied or edited.

## Getting set up

1. Install the toolchain (one time per machine):
   ```bash
   curl -sSfL https://raw.githubusercontent.com/rojo-rbx/rokit/main/scripts/install.sh | bash
   rokit install        # installs the versions pinned in rokit.toml
   ```
2. Install the **Rojo** plugin in Roblox Studio (`rojo plugin install`).
3. Start the sync server:
   ```bash
   rojo serve
   ```
4. In Studio, open a new baseplate, open the Rojo plugin and press **Connect**.
   The code appears under ReplicatedStorage, ServerScriptService and
   StarterPlayerScripts. Press Play.
5. In Studio, set **Game Settings → Players → Max Players** to the same number
   as `PlotCount` in `src/shared/Balance.luau` (6 by default), and enable
   **Studio Access to API Services** so saving and leaderboards work.

`Settings.StudioGems` tops every player up to that many Gems on join **in
Studio only**, so the gem-priced things can be tried before any have been
earned. A published server ignores it; set it to 0 to test the real drip.

`rojo build -o game.rbxl` produces a place file instead, if you'd rather not sync.

## How a round plays

- Every player is given one of the fenced gardens arranged around the hub and
  is teleported to it when they spawn. Each one is named twice: a board the
  full width of the fence riding above the upgrade screen, legible from right
  across the map so players can pick their own garden out of six at a glance,
  and a signpost by the gate carrying just the name for anyone walking up.
  Both are built by the server, unlike the upgrade screen below them, because
  the point of a name plate is that everyone else can read it. `Hub.PlotGap` in
  `src/shared/Balance.luau` is the knob for how spread out the arena is.
- A moving walkway rings the hub, cutting a lap from about 17 seconds on foot
  to about 7. It's built from anchored conveyor segments rather than a platform
  that slides around under the player, which is far steadier to stand on.
  Paths run from the walkway out to each garden gate.
- The walkway sits well inside the gardens rather than at their doorstep, so
  there's a ring of open ground about 50 studs deep between the two. That ring
  is most of what the arena feels like, and most of where the scenery stands.
  `Hub.PlotGap` sets how far out the gardens are (the plot radius is 48 plus
  it, with six of them) and `Hub.RingFraction` how much of that the walkway
  takes; between them they decide how much open ground is left.
- A prize wheel stands beside the crafting station, a little taller than the
  players queuing at it. Everyone gets one free spin a day and can buy more
  with gems; prizes are cash, gems and bonus units. Walk up to it or use the
  menu button. Prizes are plain reward bundles in
  `Balance.Wheel.Prizes`, so re-theming the wheel means editing that list and
  nothing else. The wheel face is drawn from the palette, with no artwork
  needed; a theme that wants its own can set `Images.Wheel` to an asset ID
  (a circle split into as many equal segments as there are prizes, segment 1
  centred at the top) and the labels are still drawn over it.
- The crafting station stands in the middle of the hub. Carry ordinary units
  over and load up to four of them in, and after a wait it makes something
  back. See below.
- Units fall from the sky into the garden every few seconds; players can also
  buy one. A drop rolls a tier from a five-rung window at the top of the
  player's range, weighted as a pyramid (roughly 48/24/14/10/5 by default), so
  there's always low-tier fodder to merge with and the top of the window stays
  a prize.
- Run over a unit to pick it up. You carry one at a time. Run over a *matching*
  tier and both are destroyed, leaving the next tier on the ground to be picked
  up again — merges don't chain in your hands. Running over a different tier is
  ignored; press Q (or the on-screen button) to put down what you're holding.
  The server decides every outcome, so the client can't cheat.
- Cash accrues every second from every unit lying in the garden, multiplied by
  the income upgrade, rebirths, gamepasses, any running earning boost and every
  sparkle on your plinths. Whatever you're carrying doesn't earn.
- The board across the back of the garden sells Drop Tier, Drop Speed and Max
  Items for cash, and the two timed things for gems: the Earning Boost and a
  Lucky Charm. Luck tilts the drop pyramid upward while it runs -- every rung
  is multiplied by `(1 + bias)` more than the one below it, taking the top of
  the drop window from about 5% of drops to about 43% without ever making a
  tier impossible. Ten minutes for 10 gems; the tile quotes what buying one
  would do, not the odds you already have. Rebirth trades everything for a
  permanent multiplier.
- A bin sits in the front-left corner of each garden -- somewhere to dump tiers
  that have dropped out of the window and can no longer find a partner. What a
  unit is worth shows on the carry line the moment you pick it up, and running
  into the bin asks before it sells rather than taking the unit off you. The
  price is half that tier's base cost rather than a slice of its income, so
  selling a bought unit can never turn a profit. The HUD also says outright
  when the unit you're holding can no longer be merged with anything.
- Gems are the premium currency, earned from discoveries, daily rewards and
  rebirths, or bought with Robux. They buy the two timed effects -- the earning
  boost and the lucky charm -- and finish a craft early, so the drip is
  deliberately small.
- Offline earnings, a 7-day daily reward streak and global leaderboards keep
  players coming back. Offline earnings ignore the boost, so one can't be
  banked against hours away.

## The crafting station

The one place in the game that makes something you can't merge your way to.

- Carry a unit to the machine and load it in, up to four. They're used up
  whatever happens, and carrying is one at a time, so a full machine is four
  trips out of the garden.
- The panel shows the odds as they're loaded, recalculated from
  `Economy.craftOutcomes` -- the same function the server rolls with, so what's
  on screen is exactly what will happen.
- Start it, and it runs for **four hours of real time**, offline included. The
  machine's own screen out in the hub counts down, and a toast lands when it's
  done. Gems finish one early.
- What comes out is either one of the theme's **sparkles** or an ordinary unit
  a few tiers above the best one fed in. By default that's +3 tiers 60% of the
  time and +1 tier 40%, sharing out whatever the sparkle chance leaves.

### How the odds are built

Each sparkle covers a **band** of three ordinary tiers -- ten bands over the
thirty-rung ladder both shipped themes use -- and the best unit in the machine
picks which sparkle is being played for. Every input counts for
`TierWeight ^ (tier - the bottom of that band)`, so one unit from the top of a
band is worth four from the bottom of it, and a unit below the band counts for
a fraction. Fill all four slots with the band's top tier and the odds reach
that sparkle's ceiling; anything less curves away below it.

So four tier 3s, playing for a 1-3 sparkle: **50% sparkle, 30% tier 6, 20%
tier 4**. Four tier 1s in the same band: about 9%. One tier 3 on its own: the
same as four tier 1s, which is the rule in a sentence -- one good one is worth
four poor ones.

The ceiling comes down as the bands climb (50% at the bottom, 30% at the top),
so the deeper sparkles stay rare on two counts: they cost more to play for, and
they pay out less often. Nothing reaches certainty, by design.

### Sparkles and the plinths

A sparkle is a unit like any other -- it lies in the garden, earns, and can be
picked up and carried -- with three differences: it can't be merged, the bin
won't take it, and it survives a rebirth. It earns like a unit four tiers above
its band, which is more than anything else a craft can produce.

The first one of each also earns a **permanent share of everything you make**
(+10% at the bottom band, +50% at the top, and they stack across the ten). That
bonus belongs to the trophy rather than the copy: it's counted off the
collection record, so it survives a rebirth and never has to be kept in the
garden, and a second copy of the same sparkle doesn't pay it twice. Duplicates
are still worth crafting -- they're among the best-earning units in the game --
they just don't stack the multiplier.

**The plinths** are where the collection is shown off. Every garden has one
pedestal per sparkle standing outside its side fences: odd-numbered sparkles
down the left wall, even-numbered down the right, each one taller than the
pedestal in front of it. So both rows climb toward the back of the garden, and
the rarer the sparkle the higher it stands. An empty plinth names what belongs
on it and leaves the count as `???`, so the gaps read as clearly as the
trophies. They're built and filled by the server, unlike the upgrade board and
the machine's screen, because the point of a trophy is that visitors can see
it.

Mechanically sparkles are the tail of the same unit list: `Config.Units` is the
merge ladder with the theme's sparkles appended, and `Config.MaxTier` stays the
top of the ladder, which is what stops anything ever merging into one.

## Scenery

Props are split the same way everything else is: **where** they stand is shared
layout, **what** stands there is theme data.

- `Balance.PropZones` defines rings of evenly spaced slots (`HubEdge`,
  `Approach`, `BetweenGardens`, `Outer`) as fractions of the distance out to
  the gardens: just clear of the walkway, out in the open ground, in the gaps
  between gardens, and the far skyline. This never changes between skins.
  Each ring has to clear the walkway on the way in and the gardens on the way
  out, and a prop's own width counts against both.
- A theme's `Props` table fills those slots. Each zone lists candidates and
  every slot picks one at random, so a handful of entries dresses a whole ring
  without repeating obviously.
- A zone the theme says nothing about is left bare, and a theme with no `Props`
  at all gets a clean map.

Each entry is either a real model or a shape built from parts:

```lua
{ Shape = "Cane", Height = 34, Color = ..., Accent = ... }   -- built from parts
{ Model = "GiantCandyCane", Scale = 2 }                       -- ThemeAssets.Props
```

The built-in shapes are `Cane`, `Lollipop`, `Cone`, `Stack`, `Sphere`, `Blob`,
`Butter` and `Donut`, each coloured from the entry's own `Color`/`Accent`.

**`Height` is not the footprint.** Each shape is a different width for the same
height, and the difference is large enough to matter when picking numbers:

| shape | width | a 26-tall one |
|---|---|---|
| `Cane` | 0.30x | 8 studs across |
| `Lollipop` | 0.42x | 11 |
| `Stack` | 0.60x | 16 |
| `Cone` | 0.68x | 18 |
| `Sphere`, `Donut` | 1.00x | 26 |
| `Blob` | 1.18x | 31 |
| `Butter` | 1.55x | 40 |

A garden reaches 28 studs either side of its centre once its plinths are
counted. The tightest ring for width is `Approach`, which passes about 10
studs in front of the garden fences, and the tightest for height is `HubEdge`,
which has to stay off the walkway -- so a `Butter` there wants a `Height`
around 9, where a `Cane` could be 45. They
exist so a new skin looks dressed before a single asset has been modelled or
bought, and they're a shared vocabulary rather than a themed one -- a new skin
that needs a shape nobody has built yet adds it here, and every other theme can
then use it too. `Blob` and `Butter` carry a face on the side turned towards
the middle of the map, which is what makes a giant prop read as one of the
things the game is about rather than as furniture. To swap in real
artwork later, drop an `.rbxm` into `assets/props/` and name it in the entry's
`Model` field — no placement or gameplay code changes.

## Reskinning

Everything theme-specific lives in one file per theme.

`src/shared/Themes/CandyLand.luau` is a worked example: it's a complete reskin
of the Squishies reference theme, and switching between the two is a one-line
change in `Settings.Theme`. Squishies is the theme this place currently ships.

One caveat when swapping themes over an existing save: units carry across by
tier, and so do sparkles, which are indexed the same way. The *collection
record* behind the plinths is keyed by sparkle `Id`, so it doesn't -- a Cherry
Sparkle isn't a Red Sparkle. That's right for two separate games, each with its
own `DataStoreName`, and only surprising when testing both over one save.

1. Copy `src/shared/Themes/Squishies.luau` to `src/shared/Themes/YourTheme.luau`.
2. Edit it: the words the UI uses (`Text`), the glyphs beside stats and on
   upgrade tiles (`Icons`), colours (`Palette`, `World`), the font, optional
   sounds, and the `Units` list — index 1 is the first tier, and the list can be
   any length of at least 2.
   `Sparkles` is optional: each one names a band of tiers it's crafted from, the
   permanent bonus it pays and the best odds it can be made at. A theme with no
   sparkles still gets a working crafting station — it just trades units up.
3. Point `Theme` in `src/shared/Settings.luau` at the new file.
4. Optional: drop `.rbxm` models into `assets/units/` and name them in a unit's
   `Model` field. Units without a model get a procedural blob in their colour.
5. Optional: override any economy number for that theme with a `Balance` table
   inside the theme (tables merge over the defaults in
   `src/shared/Balance.luau`; arrays replace).

Nothing in `src/server` or `src/client` needs to change for a reskin.

## Publishing a new game from this base

Each Roblox experience has its own asset IDs, so per game:

- Create the gamepasses and developer products in Studio, then put their IDs in
  `GamePasses` and `Products` in `src/shared/Settings.luau`. An ID left at `0`
  simply hides that shop entry.
- Keep `DataStoreName` stable once the game is live — changing it wipes
  everyone's save.

## Pushing changes to Roblox without opening Studio

Once the experience exists, `scripts/publish.sh` builds the project and uploads
it straight to the place with the Open Cloud API:

```bash
cp .env.example .env     # then fill in the API key, universe ID and place ID
./scripts/publish.sh --save   # upload without going live
./scripts/publish.sh --live   # publish to everyone playing
```

The API key needs the **universe-places** permission with **Write** on that
experience, from https://create.roblox.com/dashboard/credentials. `.env` is
git-ignored — don't commit the key.

## Layout

```
src/shared     Config, Settings, Balance, Themes, Economy formulas, types, remotes
src/server     Services: data, gardens, hub, gameplay loop, shop, wheel, crafting, daily, passes, products, leaderboards
src/client     State, drag and effects controllers, HUD and panels
assets/units   Optional theme models (.rbxm)
assets/props   Optional theme scenery (.rbxm)
```

Balance and formulas live in `src/shared/Economy.luau`, shared by the server
(which is authoritative) and the client (which only displays them).
