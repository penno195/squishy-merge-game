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

`rojo build -o game.rbxl` produces a place file instead, if you'd rather not sync.

## How a round plays

- Every player is given one of the fenced gardens arranged around the hub and
  is teleported to it when they spawn. `Hub.PlotGap` in
  `src/shared/Balance.luau` is the knob for how spread out the arena is.
- A moving walkway rings the hub, cutting a lap from about 19 seconds on foot
  to about 7. It's built from anchored conveyor segments rather than a platform
  that slides around under the player, which is far steadier to stand on.
  Paths run from the walkway out to each garden gate.
- A prize wheel stands in the middle of the hub. Everyone gets one free spin a
  day and can buy more with gems; prizes are cash, gems and bonus units. Walk
  up to it or use the menu button. Prizes are plain reward bundles in
  `Balance.Wheel.Prizes`, so re-theming the wheel means editing that list and
  nothing else. The wheel face is drawn from the palette, with no artwork
  needed; a theme that wants its own can set `Images.Wheel` to an asset ID
  (a circle split into as many equal segments as there are prizes, segment 1
  centred at the top) and the labels are still drawn over it.
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
  the income upgrade, rebirths, gamepasses and any running earning boost.
  Whatever you're carrying doesn't earn.
- The board across the back of the garden sells Drop Tier, Drop Speed, Max
  Items, the Earning Boost and Luck. Luck tilts the drop pyramid upward --
  every rung is multiplied by `(1 + bias)` more than the one below it, taking
  the top tier from about 5% to about 65% at max level without ever making a
  tier impossible. The board quotes the resulting percentage. Rebirth trades
  everything for a permanent multiplier.
- A bin sits in the front-left corner of each garden -- somewhere to dump tiers
  that have dropped out of the window and can no longer find a partner. What a
  unit is worth shows on the carry line the moment you pick it up, and running
  into the bin asks before it sells rather than taking the unit off you. The
  price is half that tier's base cost rather than a slice of its income, so
  selling a bought unit can never turn a profit. The HUD also says outright
  when the unit you're holding can no longer be merged with anything.
- Gems are the premium currency, earned from discoveries, daily rewards and
  rebirths, or bought with Robux. They buy the timed earning boost and nothing
  else, so the drip is deliberately small.
- Offline earnings, a 7-day daily reward streak and global leaderboards keep
  players coming back. Offline earnings ignore the boost, so one can't be
  banked against hours away.

## Scenery

Props are split the same way everything else is: **where** they stand is shared
layout, **what** stands there is theme data.

- `Balance.PropZones` defines rings of evenly spaced slots (`HubEdge`,
  `BetweenGardens`, `Outer`) as fractions of the distance out to the gardens.
  This never changes between skins.
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

The built-in shapes are `Cane`, `Lollipop`, `Cone`, `Stack` and `Sphere`, each
coloured from the entry's own `Color`/`Accent`. They exist so a new skin looks
dressed before a single asset has been modelled or bought. To swap in real
artwork later, drop an `.rbxm` into `assets/props/` and name it in the entry's
`Model` field — no placement or gameplay code changes.

## Reskinning

Everything theme-specific lives in one file per theme.

`src/shared/Themes/CandyLand.luau` is a worked example: it's a complete reskin
of the Squishies reference theme, and switching between the two is a one-line
change in `Settings.Theme`. Candy Land is the theme this place currently ships.

1. Copy `src/shared/Themes/Squishies.luau` to `src/shared/Themes/YourTheme.luau`.
2. Edit it: the words the UI uses (`Text`), the glyphs beside stats and on
   upgrade tiles (`Icons`), colours (`Palette`, `World`), the font, optional
   sounds, and the `Units` list — index 1 is the first tier, and the list can be
   any length of at least 2.
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
src/server     Services: data, gardens, hub, gameplay loop, shop, wheel, daily, passes, products, leaderboards
src/client     State, drag and effects controllers, HUD and panels
assets/units   Optional theme models (.rbxm)
assets/props   Optional theme scenery (.rbxm)
```

Balance and formulas live in `src/shared/Economy.luau`, shared by the server
(which is authoritative) and the client (which only displays them).
