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

- Every player is given one of the plots arranged around the hub and is
  teleported to it when they spawn.
- A new unit appears on a free slot every few seconds; players can also buy one.
- Drag a unit onto another: same tier merges, empty slot moves, anything else
  swaps. The server decides the outcome, so the client can't cheat.
- Cash accrues every second from every unit on the plot, multiplied by the
  income upgrade, rebirths and gamepasses.
- Upgrades raise spawn speed, spawn tier, plot size and income. Rebirth trades
  everything for a permanent multiplier.
- Offline earnings, a 7-day daily reward streak and global leaderboards keep
  players coming back.

## Reskinning

Everything theme-specific lives in one file per theme.

1. Copy `src/shared/Themes/Squishies.luau` to `src/shared/Themes/YourTheme.luau`.
2. Edit it: the words the UI uses (`Text`), colours (`Palette`, `World`), the
   font, optional sounds, and the `Units` list — index 1 is the first tier, and
   the list can be any length of at least 2.
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
src/server     Services: data, plots, gameplay loop, shop, daily, passes, products, leaderboards
src/client     State, drag and effects controllers, HUD and panels
assets/units   Optional theme models (.rbxm)
```

Balance and formulas live in `src/shared/Economy.luau`, shared by the server
(which is authoritative) and the client (which only displays them).
