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

`Settings.StudioPlaytimeSpeed` does the same for the playtime ladder, running
its clock that many times faster in Studio — at 20, the ninety-minute rung lands
four and a half minutes in. A published server always runs it at 1.

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
- A leaderboard stands on the other side of the crafting station from the
  wheel, raised on a post so it reads at eye level. One face, one ranking:
  total earned, with each player's rebirth count as a badge on their row. A
  board nobody can see both sides of at once can't be compared, and a combined
  score of cash and rebirths is a number no player can act on — so it ranks the
  one thing that's always moving and carries the other alongside it. A second
  metric, if it ever wants ranking properly, belongs on a second board standing
  beside this one. `Leaderboard.BoardRows` sets how many places it shows; the
  panel still lists the full top 25.
- The panel carries a third board the hub's doesn't: **this week's race**, which
  ranks what each player has earned since their week turned over, and pays out.
  See below.
- A prize wheel stands beside the crafting station, a little taller than the
  players queuing at it. Everyone gets one free spin a day and can buy more
  with gems; prizes are cash, gems and bonus units. Walk up to it or open it
  from Rewards in the menu. With more than one spin saved up, an **Auto** button
  beside Spin keeps spinning until they're all spent, pausing on each prize long
  enough to read it. Prizes are plain reward bundles in
  `Balance.Wheel.Prizes`, so re-theming the wheel means editing that list and
  nothing else. The wheel face is drawn from the palette, with no artwork
  needed; a theme that wants its own can set `Images.Wheel` to an asset ID
  (a circle split into as many equal segments as there are prizes, segment 1
  centred at the top) and the labels are still drawn over it.
- The crafting station stands on the hub's rim, opposite the spawn pad. Carry ordinary units
  over and load up to four of them in, and after a wait it makes something
  back. See below.
- Units fall from the sky into the garden every few seconds; players can also
  buy one. A drop rolls a tier from a five-rung window at the top of the
  player's range, weighted as a pyramid (roughly 48/24/14/10/5 by default), so
  there's always low-tier fodder to merge with and the top of the window stays
  a prize. It then rolls a **variant** over the top of that — see below.
- Run over a unit to pick it up. You carry one at a time. Run over a *matching*
  tier and both are destroyed, leaving the next tier on the ground to be picked
  up again — merges don't chain in your hands. Running over a different tier is
  ignored; press Q (or the on-screen button) to put down what you're holding.
  The server decides every outcome, so the client can't cheat.
- Cash accrues every second from every unit lying in the garden, multiplied by
  the income upgrade, rebirths, gamepasses, any running earning boost and every
  sparkle on your plinths. Whatever you're carrying doesn't earn.
- The board across the back of the garden sells every upgrade for cash (Drop
  Tier over Drop Speed, Max Items over Income Boost) and the three timed things
  for gems (the Earning Boost, a Lucky Charm and Auto Merge), with Rebirth taking its
  whole last column. Luck tilts the drop pyramid upward while it runs — every rung
  is multiplied by `(1 + bias)` more than the one below it, taking the top of
  the drop window from about 5% of drops to about 43% without ever making a
  tier impossible. Ten minutes for 10 gems; the tile quotes what buying one
  would do, not the odds you already have. Rebirth trades everything for a
  permanent multiplier, takes two presses on the board so a stray click can't
  throw a garden away, and needs two things rather than one: the cash, and a
  unit on the ground at or above a required rung. Cash alone made it a waiting
  game — park a full garden, come back, press the button — where a rung has to
  be merged for. The requirement starts at tier 10 and climbs by one per
  rebirth, stopping two short of the top of the ladder so the late ones stay
  reachable; `Balance.Rebirth.BaseTier` and `TierPerRebirth` are the knobs.
- The menu on the left is five buttons: Upgrades, Shop and Ranks open their
  panel directly, and Rewards (daily, playtime, quests, the wheel) and
  Collection (pets, the crafting station, the index) open a tray of their panels
  beside the grid. A group's button carries a count of everything inside it
  that's ready to collect, so grouping never hides a reward. The boost and luck
  timers sit beside the gem count as chips rather than stacking up above the
  menu.
- A bin sits in the front-left corner of each garden — somewhere to dump tiers
  that have dropped out of the window and can no longer find a partner. What a
  unit is worth shows on the carry line the moment you pick it up, and running
  into the bin asks before it sells rather than taking the unit off you. The
  price is half that tier's base cost rather than a slice of its income, so
  selling a bought unit can never turn a profit. The HUD also says outright
  when the unit you're holding can no longer be merged with anything.
- Gems are the premium currency, earned from discoveries, daily rewards and
  rebirths, or bought with Robux. They buy the two timed effects — the earning
  boost and the lucky charm — and finish a craft early, so the drip is
  deliberately small.
- Offline earnings, a 7-day daily reward streak and global leaderboards keep
  players coming back. Offline earnings ignore the boost, so one can't be
  banked against hours away. By default they pay half rate for up to eight hours;
  the Auto Collect pass makes that full rate for twenty-four. The one-minute
  minimum stands either way, so reconnecting after a dropout pays nobody.
- A **playtime ladder** pays for staying, where the daily streak pays for coming
  back: eight rungs from one minute to ninety, claimed as the session runs. It
  measures the current session and resets when you leave, so it's never stored —
  `Balance.Playtime.Rungs` is the whole thing, and a rung coming up announces
  itself. `data.Playtime` still keeps the lifetime total for anything that wants
  to ask how long someone has played; the ladder isn't counting that.

## The weekly race

The two boards that have always been there rank lifetime totals, which is right
for a hall of fame and wrong for a prize: whoever has played longest sits on top
of them forever, so paying out on one would reward seniority rather than the
week. The race is a third board that everyone starts level on every Monday.

- It ranks **earned this week** — `TotalEarned` now, minus where it stood when
  that player's week turned over. Nothing is wiped to reset it.
- Last week's top finishers win Gems, listed by place in
  `Balance.Leaderboard.Prizes`. The list's own length is how many places pay, so
  shortening it makes the prize rarer.
- A prize is **claimed, not granted**: it's waiting at the top of the Ranks
  panel when the winner next logs in. Someone who won while they were offline
  should be told they won, and a line of Gems appearing in the corner isn't
  being told.
- A prize has to be collected during the week after the one it was won in. Miss
  a week entirely and it's gone — the board it was won on stops being the one
  the game is paying out against.

The whole reset is a naming trick: each week's board is its own
OrderedDataStore, named `<LeaderboardPrefix>_Weekly_<week number>`. So there's
nothing to clear, last week's standings are still readable while this week's
race is already running, and rolling over costs a rename. Old weeks' stores are
simply never read again.

## The crafting station

The one place in the game that makes something you can't merge your way to.

- Carry a unit to the machine and load it into a slot, up to four per slot.
  They're used up whatever happens, and carrying is one at a time, so a full
  slot is four trips out of the garden.
- A player has **one slot**, or two with the Second Slot pass — two crafts with
  their own loads and their own clocks, running side by side. `Balance.Craft` has
  both numbers, and they are easy to confuse: `Slots` is how many crafts at once,
  `Inputs` is how many units each one takes. The pass sells a second craft, never
  a bigger one, so the odds a load can reach are the same for everybody.
- The panel shows the odds as they're loaded, recalculated from
  `Economy.craftOutcomes` — the same function the server rolls with, so what's
  on screen is exactly what will happen.
- Start it, and it runs for **four hours of real time**, offline included. The
  machine's own screen out in the hub counts down, and a toast lands when it's
  done. Gems finish one early.
- What comes out is either one of the theme's **sparkles** or an ordinary unit
  a few tiers above the best one fed in. By default that's +3 tiers 60% of the
  time and +1 tier 40%, sharing out whatever the sparkle chance leaves.

### How the odds are built

Each sparkle covers a **band** of three ordinary tiers — ten bands over the
thirty-rung ladder both shipped themes use — and the best unit in the machine
picks which sparkle is being played for. Every input counts for
`TierWeight ^ (tier - the bottom of that band)`, so one unit from the top of a
band is worth four from the bottom of it, and a unit below the band counts for
a fraction. Fill all four inputs with the band's top tier and the odds reach
that sparkle's ceiling; anything less curves away below it.

So four tier 3s, playing for a 1-3 sparkle: **50% sparkle, 30% tier 6, 20%
tier 4**. Four tier 1s in the same band: about 9%. One tier 3 on its own: the
same as four tier 1s, which is the rule in a sentence — one good one is worth
four poor ones.

The ceiling comes down as the bands climb (50% at the bottom, 30% at the top),
so the deeper sparkles stay rare on two counts: they cost more to play for, and
they pay out less often. Nothing reaches certainty, by design.

### Sparkles and the plinths

A sparkle is a unit like any other — it lies in the garden, earns, and can be
picked up and carried — with three differences: it can't be merged, the bin
won't take it, and it survives a rebirth. It earns like a unit four tiers above
its band, which is more than anything else a craft can produce.

The first one of each also earns a **permanent share of everything you make**
(+10% at the bottom band, +50% at the top, and they stack across the ten). That
bonus belongs to the trophy rather than the copy: it's counted off the
collection record, so it survives a rebirth and never has to be kept in the
garden, and a second copy of the same sparkle doesn't pay it twice. Duplicates
are still worth crafting — they're among the best-earning units in the game —
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

## Variants

The same unit, worth more. After a drop has rolled its tier it rolls a variant:
Shiny, Golden or Rainbow by default, at 6%, 1.2% and 0.2%. The rest of the
time — almost all of it — an ordinary unit lands.

A variant multiplies what that unit earns and what it sells for (x3, x12, x60
by default) without changing its rung, so a Golden tier 4 earns more than an
ordinary tier 9 while still merging like a tier 4. That's the point of them: a
drop that would otherwise be fodder is occasionally the best thing in the
garden, and it arrives on its own schedule rather than the upgrade board's.

The variant roll is independent of the tier roll, so a variant is as likely on
a low rung as a high one — the prize is the variant, not the pairing. Luck
lifts each variant's chance by the same `(1 + Bias)` it puts on the tier
pyramid, so a lucky charm is worth buying for two reasons at once.

### What a variant is for

Two things, and the second is the one that matters.

**It can be merged**, with another of the same tier *and* the same variant.
That works, and on its own it isn't enough: climbing a variant costs
exponentially — a Shiny tier 5 needs sixteen Shiny tier 1s — and the rarer the
variant the further out of reach that gets. Treat it as something that
occasionally happens near the bottom of the ladder, not as the point of them.

**It can be fed to the crafting machine**, which is the point of them. A
variant counts as the rung it copies for choosing the sparkle and for progress,
and on top of that it lifts the ceiling on that load's sparkle chance. So a
variant is a decision rather than a windfall: leave it in the garden earning
its multiple, or spend it on the odds of a trophy.

What the boost buys is a share of the gap between that sparkle's own ceiling
and `Craft.HardCap`, not a multiple of the ceiling. Multiplying looks simpler
and behaves badly — the bottom band's ceiling is already 50%, so one Golden
would reach the cap by itself and a machine full of Rainbows would be worth no
more than that. Closing the gap keeps every rung of the variant ladder
distinguishable and keeps stacking worth something:

| load, on the 1–3 band | sparkle chance |
|---|---|
| four ordinary tier 3 | 50% |
| three, plus one Shiny | 60% |
| three, plus one Golden | 71% |
| three, plus one Rainbow | 79% |
| four Rainbow | 90% |
| one Rainbow, alone | 13% |

That last row is the shape of the whole thing: the machine still wants to be
full, and a single rare unit doesn't substitute for filling it. Variants help
most on the deepest bands, where the ceiling is lowest and the gap widest —
one Shiny takes the 28–30 band from 30% to 46%.

Sparkles still can't go in. Variants now can.

**Merging matches on the whole unit, not the rung.** Two Golden tier 4s make a
Golden tier 5; a Golden and an ordinary tier 4 do nothing at all. So a variant
is a decision rather than a windfall: it's worth far more than its tier, but
climbing with it means finding another of the same kind. Variants do not
survive a rebirth — they're progress, not limited editions, which is what the
sparkles are for.

### How they're built

Variants are the sparkle trick used a second time. `Config.Units` is the merge
ladder, then the sparkles, then one full copy of the ladder per variant:

```
1 .. MaxTier                            the merge ladder
MaxTier + 1 .. VariantBase              the sparkles
VariantBase + (v - 1) * MaxTier + tier  variant v of that tier
```

So a variant unit is just another unit index. It drops, merges, is carried,
earns, is sold and is labelled by code that has never heard of variants. And
because each block is a copy of the ladder *in order*, merging is still "the
next index up", which is what keeps a merge inside the variant it started in
without anything having to check.

Config stamps `Tier` and `Variant` onto every entry as it builds the list, so
reading either back is a lookup rather than arithmetic. The arithmetic that's
left — going from a tier and a variant to an index — lives in
`Economy.variantIndex` and nowhere else.

`Balance.Variants` is the mechanics: the Id, how rare each one is, and what it
multiplies by. A theme's own `Variants` table names and colours them by that
Id. Anything a theme leaves out falls back to the Id as a name and a tint
toward white, so a new skin has working variants before anyone has styled them,
and `Balance.Variants = {}` turns them off entirely.

## Scenery

Props are split the same way everything else is: **where** they stand is shared
layout, **what** stands there is theme data.

- `Balance.PropZones` defines rings of evenly spaced slots (`Ringside`,
  `HubEdge`, `Approach`, `BetweenGardens`, `Outer`) as fractions of the distance
  out to the gardens: round the feet of the canopy poles, just clear of the
  walkway, out in the open ground, in the gaps between gardens, and the far
  skyline. This never changes between skins.
  Each ring has to clear the walkway on the way in and the gardens on the way
  out, and a prop's own width counts against both.
- A theme's `Props` table fills those slots. Each zone lists candidates and
  every slot picks one at random, so a handful of entries dresses a whole ring
  without repeating obviously.
- A zone the theme says nothing about is left bare, and a theme with no `Props`
  at all gets a clean map.

The fences and the paths are dressed from the same theme data. `World.FenceStripe`
bands each rail between that colour and `World.Fence` and alternates the posts
between them, which is what makes a candy-cane fence out of parts alone; `World.FenceTexture`
does it properly instead, wrapping an uploaded stripe round each rail -- a
diagonal is the one thing parts cannot draw, since a part is one colour -- and a
textured rail is one part however long it is, so it costs *less* than banding; `World.PathTiles` lays
sweets over the path slabs, framed by a kerb in `World.PathKerb`, with `World.Path`
showing between them as the grouting. Both are optional, and a theme that omits
them gets the plain fence and plain paths the base always had. They are not free:
at the default `Garden.FenceStripe` of 3.5 studs a fence costs about 155 parts a
garden instead of 10, and the tiles about 50 a path. Those two numbers --
`Garden.FenceStripe` and `Hub.PathTile.Size` -- are the dials if that ever matters.

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
which has to stay off the walkway — so a `Butter` there wants a `Height`
around 9, where a `Cane` could be 45. They
exist so a new skin looks dressed before a single asset has been modelled or
bought, and they're a shared vocabulary rather than a themed one — a new skin
that needs a shape nobody has built yet adds it here, and every other theme can
then use it too. `Blob` and `Butter` carry a face on the side turned towards
the middle of the map, which is what makes a giant prop read as one of the
things the game is about rather than as furniture. To swap in real
artwork later, drop an `.rbxm` into `assets/props/` and name it in the entry's
`Model` field — no placement or gameplay code changes.

### The big top

A canopy over the hub, so the middle of the map is a tent rather than open sky.
Layout is `Balance.Canopy`; what it's made of is the theme's `Canopy` table, and
a theme that omits that gets no tent and nothing else changes.

It is a roof, not a room. The hub only works because you can stand anywhere in
the middle and see all four stations at once, so it has no walls and nothing in
the centre: six banded poles stand outside the walkway, in the same gaps between
the garden paths the stations use, and the roof rests on them 30 studs up. At the
default six gardens that's a tent 133 studs across, with the machine, the wheel,
the leaderboard, the egg pads and the whole walkway under it.

Each gore is cut into `PanelSteps` segments on the way up, each sized to the arc
at its own radius. One rectangle per gore is the obvious way to build it and
looks wrong: a gore is a triangle, so a rectangle wide enough for the eaves is
three times wider than its share of the crown, and the top of the roof turns into
a jumble of overlapping flaps.

Two properties are load-bearing and easy to lose in an edit. Every canopy part
except the poles sets **`CanQuery = false`**, because the camera picks its
distance by raycasting at the player and would otherwise slam in against the roof
every time somebody walks under it; and **`CastShadow = false`**, because a closed
cone over the hub otherwise drops all four stations into shade.

## Quests

Three a day and one a week, drawn from pools in `Balance.Quests`. Each one is a
tally of a verb the game already announces — merges, drops, sales, upgrades,
spins, crafts, discoveries — so adding a quest is a line in Balance and nothing
else. Rewards are ordinary reward bundles, the same ones the wheel and the daily
streak use, so they scale with the player's income.

Two things make this cheap. Progress is measured off the lifetime tallies
`StatsService` already keeps, from where the counter stood when the quest was
handed out, so nothing is counted twice and a quest can't be completed by work
done before it was set. And which quests a player gets is a pure function of
their user id and the day, so the same three come back on a rejoin without the
set being stored, and the server and the panel agree without talking.

Dailies and the weekly roll over independently: a weekly in progress survives
the daily reset. The panel is built on `ClaimList`, a shared list of
"make progress, then claim" rows — the playtime ladder and the leaderboard
payouts are the same shape and will use it rather than growing their own.

## Pets

One pet follows at your heels and the rest wait in the inventory, swappable
whenever you like. That single decision is what the whole system is built around:
a pet is a **tool you pick for what you are about to do**, not a number you
accumulate. So the **perk is the reason to own one**, and the cash multiplier is a
nudge — 3% to 15% across the entire rarity ladder. A pet that paid double would be
worn forever and there would be nothing left to choose.

The pet walks along the ground behind you with a little hop. The server puts it in
the world and never moves it; every client moves every pet itself each frame
(`PetController`), which is what keeps it smooth, and it stays on the floor when
you jump.

- **Hatching** happens at three egg pads side by side, one of the four stations
  around the hub's rim (see "The hub" below). They stand in the gap beside the spawn
  pad, because a shop by the entrance is a shop people find.
- The pad's sign carries the **name and price only**. Its prompt opens a panel with
  the odds, every pet the egg can hand over and what each one does, and the Hatch
  button. Showing that before any cash changes hands is deliberate: a gacha that
  hides its odds is hiding them, and since a pet's whole value is its perk, choosing
  between a cheap egg and a dear one is really choosing between two lists of perks.
  There is no timer either — the machine already owns the long wait, and two systems
  competing for the same patience is one too many.
- **Six perks**, in `Balance.Pets.Perks`: Merge Payout, Gem Finder, Lucky Crafter,
  Haggler, Charmed and Gardener. They map onto things a player is *doing* — so the
  Lucky Crafter goes on before opening the machine, the Gardener when the garden
  is full, and the Gem Finder while grinding merges. Each is deliberately small.
- **Variants give a stronger perk**, not more cash. Pets reuse the same
  Golden/Rainbow/Shiny ladder the units have, with the same chances and the same
  theme styling, so a Golden pet needs nothing configured that Golden units don't
  already have. `PetPerk` on each variant rung is how much better its one job gets;
  it's far smaller than the `Income` multiplier a variant *unit* carries, and on
  purpose — a Rainbow pet sixty times better would end the switching.
- **Rarity** decides how hard the perk hits and how much the nudge is worth.
  A Legendary pays 12% more than a Common and is three times better at its job.
  Which rarities an egg can reach is the egg's business and lives only there.

Pets are **theme data**. A `PetDef` names a rarity and a perk from `Balance` and is
otherwise a colour and a few `Features` off the same vocabulary the units use, so
a new skin's pets look right with no model made for them — a pet that says
`"CatEars"` gets cat ears from code that already existed. Both shipped themes
carry the same thirteen, dressed differently, so a perk that feels wrong can be
judged as the perk rather than as the skin.

Nothing outside `PetService` knows what a perk *does*. It hands back a strength
and the service that owns the affected thing applies it, exactly as the gamepasses
work: the bin asks for `SellBonus`, the machine asks for `CraftLuck`, the drop loop
asks for `DropLuck` and `Space`. Adding a perk is one entry in `Balance` and one
number read in one service.

The inventory panel sorts strongest first with whatever is equipped above it, and
rings each pet's swatch in its rarity's colour — taken from the theme's palette, so
a skin's rarest pet is its own accent. A list in hatch order buries the pet you want
under twenty commons, and the panel exists to make the swap quick.

Two consequences worth knowing. The equipped pet is read **at the moment of
collection** for a craft rather than when the craft was started — swapping a Lucky
Crafter on before opening the machine is meant to pay, because rewarding the swap
is the point of having an inventory. And the model is built on the **server** and
welded to the player, so everyone sees everyone's pet with nothing to keep in
sync; it's rebuilt on respawn for the same reason a carried unit is.

### The hub

The middle of the hub is open ground, and all four of its landmarks — the crafting
machine, the prize wheel, the leaderboard and the egg pads — stand around the rim
facing inward. A landmark in the centre is something to walk round rather than up
to, and with four of them the middle was becoming a maze; from the rim each one has
a face turned inward, so a player standing anywhere in the hub can see all four and
walk straight at the one they want. It also fixes a read: a flat face — the wheel's
dial, the board's rows, the machine's screen — is hard to read at an angle, and from
the rim the whole open middle is square on to every one of them.

They stand in the **gaps between the paths**. Six paths leave the walkway at even
angles, so the midpoint between two of them — `(i - 0.5) / PlotCount` of a turn — is
the only place a building isn't in the way of someone walking home. Positions are
written in `STATION_GAPS` as offsets from the spawn pad's own gap rather than as
angles, so the arrangement holds if `PlotCount` changes:

- The spawn's own gap stays **clear** — it's where players arrive.
- The **machine** takes the gap opposite it, so it's what you see on arrival.
- The **wheel** and the **leaderboard** flank the machine, the mirror they always had.
- The **egg pads** take the gap beside the spawn, three of them side by side.

With six gardens that puts the machine 180° from the spawn, the wheel and board 120°
either side, and the eggs 60° away, leaving two gaps empty. `STATION_INSET` is how
far in from the walkway they stand — set by the deepest of them, the machine's
plinth, with room to walk round the back.

## What Robux buys

Nine gamepasses and four developer products, all of them optional and none of
them the only way to get anywhere. Every ID lives in `src/shared/Settings.luau`
and an ID left at `0` hides that entry, so a fresh reskin shows only what it has
actually set up.

The passes, and what each one is worth:

| Pass | Effect | Where the number lives |
| --- | --- | --- |
| x2 Currency | Doubles income, forever | `Monetisation.DoubleCashMultiplier` |
| Auto Merge | Merges a matching pair for you as you play | `Monetisation.AutoMergeInterval` |
| Fast Spawn | Halves the wait between drops | `Monetisation.FastSpawnMultiplier` |
| Lucky Forever | The lucky charm permanently, no gems and no clock | `Balance.Luck.Bias` |
| Auto Collect | Full-rate offline earnings for a day, not half for eight hours | `Monetisation.AutoCollect` |
| Second Slot | A second craft running alongside the first | `Monetisation.ExtraCraftSlots` |
| Bigger Garden | More room than the cash upgrade can reach | `Monetisation.BiggerGardenSpaces` |
| Starter Pack | One bundle, a player's first day only | `Monetisation.StarterPack` |
| Admin Panel | Trolling commands to use on other players | `src/shared/AdminCommands.luau` |

Auto Merge can also be had for a while with gems, from the garden board
(`Balance.AutoMerge`), the way Lucky Forever is a permanent Lucky Charm: an owner of
the pass isn't offered it and the server won't sell it to them.

The **Admin Panel** is opened from its card in the shop. It picks a player and does
something to them — squish them under a giant squishy, freeze, jail, fling, rocket,
trip, shrink or slow them — or to yourself (speed, super jump, giant), or rains
squishies on the whole server. It's the troll-admin pass other games sell, with two
lines drawn: **nothing touches progress** (no stealing, deleting or kicking; every
effect wears off in seconds and none of it can reach saved data), and **no
flashbangs** or screen flashes. A cooldown between an admin's commands and a spell
of protection for anyone just hit stop one admin from pinning a player down all
session. Everyone in Studio is an admin, and so is the experience's creator on a
live server.

Three of them are worth knowing the shape of:

- **Lucky Forever** is exactly a charm that never expires, and the code says so
  rather than growing a second luck system: every luck-sensitive function in
  `Economy` already takes a `bias` override so the upgrade board can quote what
  buying a charm *would* do, and the pass is that same override, passed in
  permanently. It follows that the charm and the pass don't stack — there is
  nothing to stack — so the board stops offering to sell one and the server
  refuses the sale outright rather than taking gems for nothing.
- **Bigger Garden** adds a flat number of spaces on top of whatever Garden Space
  has reached, rather than extra levels of it. Extra levels would have to line up
  with `GardenCapacities`, and a flat number is worth the same to a player at
  level 0 as at level 5 — which is the one likely to buy it.
- **Starter Pack** is a pass rather than a product, because "one-time" has to
  mean it when real money is involved: Roblox won't sell a pass twice. Owning it
  and having had the bundle are separate, though — a purchase can land on a
  server that dies before it saves — so ownership is re-checked on every join and
  `StarterClaimed` in the save is what stops a second helping. The window only
  ever governs the **offer**: a pass bought in its last second is still honoured
  whenever the player next appears.

### Playing the passes before they exist

An ID of `0` is never checked against anything, so until the experience is
published every pass effect sits behind a purchase that cannot happen. Two
Studio-only settings close that gap, both ignored outright by a live server:

- `Settings.StudioPasses` lists passes treated as owned. It adds to real
  ownership rather than replacing it, so once the IDs exist a Studio session shows
  what the player actually owns plus whatever is being tested. A name that isn't a
  pass is warned about, because a typo there looks exactly like an effect that
  doesn't work.

  It is **empty by default**, and wants putting back to empty after testing a pass.
  Anything in it changes the game you are looking at, and `"AutoMerge"` changes it
  completely: it merges a pair for you every 1.5 seconds, so units appear to upgrade
  and vanish on their own and the core loop plays itself. It was all seven passes for
  a while, which had Studio running about three times faster than the real game.
- In Studio the shop also draws entries whose ID is still `0`, greyed out and
  captioned "No ID yet". Otherwise that panel reads "nothing for sale yet" for the
  whole of development and none of its layout is seen until the day it goes live.

`StarterPack` is worth its own note: owning it is what withdraws the offer, so
listing it hides the timed card and its countdown. Add it to watch the bundle land
on join instead. You can't see both in one session, which is the point of a
one-time offer.

No pass effect is written into `Economy`. That module stays pure and takes each
one as an argument — a multiplier, a bias, a number of spaces — which the server
supplies from `PassService` and the client from the `Passes` map in its snapshot.
Where both sides have to answer the same question, the mapping from "owns it" to
"is worth this much" lives in `Economy` too (`gardenPassSpaces`, `luckPassBias`),
because two copies of one `if` is how the shop comes to promise something the
server doesn't give.

## The staff panel

The game's own admin tool, separate from the Admin Panel pass. A 👑 **Staff** button
appears in the menu for staff only, and every command is checked again on the server
(`StaffService`), so hiding the button is not what keeps anyone out.

**Who is staff:** the experience's creator if a person owns it; anyone at or above
`Settings.StaffGroupRank` (255, the owner) if a group does; anyone whose user id is
in `Settings.StaffUserIds`; and everyone in Studio.

- **Events** run on every server at once, and on servers that start while one is on.
  Pick a length (15 minutes to 4 hours) and a strength: **Drop Luck** (x2 is a Lucky
  Charm for everyone), **Variant Luck**, **Hatch Luck**, **Craft Luck**, **Cash
  Boost** and **Fast Drops**. They stack with charms, passes and pets. Players see a
  chip with the clock in the top right, and the egg panel shows the boosted odds. The
  list is `src/shared/LiveEvents.luau`; `EventService` keeps it in a DataStore, pushes
  changes by MessagingService and re-reads every minute in case a message was lost.
- **Gifts:** any unit on the ladder, variants and sparkles included, x1 to x25, to
  yourself, one player or everyone in the server, up to the room in each garden. Or
  any amount of currency or gems.
- **Players:** go to, bring, kick, or ban for a day, a week or for good. Bans cover
  every server and alt accounts, and are undone from the Creator Hub under Moderation.
  Reasons are a fixed list, so nothing typed reaches the player unfiltered. Staff
  can't kick or ban each other.
- **Message:** up to 200 characters to every player in every server, shown as a
  banner. It goes through Roblox's text filter first, as it must.

Staff also get the Admin Panel's commands with no cooldown and no protection window,
for running an admin-abuse event. In Studio those rules still apply, since everyone
there is staff.

Cross-server events, messages and bans only work on a published game with API access
on. In Studio an event still runs on the Studio server, which is enough to test what
it does.

## What the game measures

Every verb the game has — a drop, a merge, a sale, an upgrade, a craft, a
spin, a rebirth, a purchase — is announced once through `ActionService`, a
server-side bus that requires nothing and that anything can subscribe to.

Two things listen today. `AnalyticsService` reports to Roblox's analytics:
currency in and out of every action, custom events for the rare ones, the
merge ladder as a progression path, and one summary when a session ends.
Currencies are reported as "Cash" and "Gems" whatever the theme calls them, so
one dashboard reads every game built from this base. `StatsService` keeps
lifetime tallies in the save, because "has this player ever..." and "how many
more until..." are the questions quests and the tutorial are made of.

Analytics has to be switched on for the experience in the Creator Dashboard.
Until it is, every call throws; they're all wrapped, so the game plays normally
and warns once.

Measuring something new is a line in `AnalyticsService`, not an edit to the
gameplay that reported it.

## Reskinning

Everything theme-specific lives in one file per theme.

`src/shared/Themes/CandyLand.luau` is a worked example: it's a complete reskin
of the Squishies reference theme, and switching between the two is a one-line
change in `Settings.Theme`. Squishies is the theme this place currently ships.

One caveat when swapping themes over an existing save: units carry across by
tier, and so do sparkles, which are indexed the same way. The *collection
record* behind the plinths is keyed by sparkle `Id`, so it doesn't — a Cherry
Sparkle isn't a Red Sparkle. That's right for two separate games, each with its
own `DataStoreName`, and only surprising when testing both over one save.

1. Copy `src/shared/Themes/Squishies.luau` to `src/shared/Themes/YourTheme.luau`.
2. Edit it: the words the UI uses (`Text`), the glyphs beside stats and on
   upgrade tiles (`Icons`), colours (`Palette`, `World`), the font, optional
   sounds, optional artwork (`Images`), and the `Units` list — index 1 is the first tier, and the list can be
   any length of at least 2.
   `Sparkles` is optional: each one names a band of tiers it's crafted from, the
   permanent bonus it pays and the best odds it can be made at. A theme with no
   sparkles still gets a working crafting station — it just trades units up.
3. Point `Theme` in `src/shared/Settings.luau` at the new file.
4. Optional: give a unit `Features` — see below.
5. Optional: drop `.rbxm` models into `assets/units/` and name them in a unit's
   `Model` field. Units without a model get a procedural blob in their colour.
6. Optional: override any economy number for that theme with a `Balance` table
   inside the theme (tables merge over the defaults in
   `src/shared/Balance.luau`; arrays replace).

Nothing in `src/server` or `src/client` needs to change for a reskin.

A theme's `Pets` list follows the same rule: each entry names a `Rarity` and a
`Perk` that exist in `Balance.Pets` and supplies the dressing. Unlike a unit's
unknown feature, a pet naming a rarity or perk that doesn't exist is a hard error
at load — there is no sensible fallback, and a pet with no perk has no reason to be
owned. `Config` also refuses a theme where an egg can roll a rarity that theme has
no pets for, because that egg would take a player's cash and hand back nothing.

### What the UI looks like

Every panel is built from `src/client/UI/Components.luau`, so the whole game's
look is one file plus the theme's palette. The dressing is the chunky moulded
plastic the front page of the platform is made of: a heavy near-black outline on
every surface, generous corners, fills that ramp light to dark, a gloss over the
top half of anything pressable, buttons sitting on a lip they sink onto when
pressed, and text outlined in the same near-black.

None of it needs artwork. The outline colour is derived from the theme's own
`Palette.Background` rather than fixed, so a pale skin gets dark grey where a
dark one gets near-black. `OUTLINE_THICKNESS` at the top of that file is the
single biggest lever on how moulded or how soft the whole game reads.

Cards built with `Pattern = true` — the shop rows, upgrade tiles, index cells,
daily days and claim rows — get a checker behind their contents. Without any
asset it's built from one gradient per row rather than one frame per square,
which is five instances for a forty-square checker. A theme that would rather
supply its own sets `Images.CardPattern` to a square that tiles seamlessly, and
it's tiled in place of the built one.

### What a unit looks like

Every procedural unit is a squishy ball with a face: two eyes, a highlight in
each, and a smile under them. The mouth is what makes it a face from the side as
well as head on — two dots on a ball only read as eyes when you're square in
front of them.

The smile is an arc of five overlapping segments, each laid on the body's own
surface and turned to the slope of the curve under it, rather than one flattened
part. That's worth the four extra parts: a single part gives a straight slot, and
a straight slot on a round face reads as a grimace at every size you can make it.

On top of that a unit can name **features**, so a thing called a Pup has
something dog about it and a thing called a Cat doesn't look identical to it:

```lua
{ Name = "Puddle Pup", Color = ..., Features = { "DogEars", "Snout", "Tail" } },
```

Features are split the same way scenery is: **which** ones a unit wears is theme
data, and **what each one looks like** is shared code in
`src/shared/UnitVisuals.luau`. So a new skin gets dog ears by writing
`"DogEars"`, not by modelling one, and both shipped themes draw on the same
vocabulary:

| | |
|---|---|
| `DogEars` `CatEars` `BunnyEars` `RoundEars` | ears: floppy, pointed, long, round |
| `Snout` `Beak` `Whiskers` `Patches` | a muzzle and nose, a beak, whiskers, dark rings round the eyes |
| `WideMouth` | a wider, deeper grin — a frog, an axolotl, a quokka |
| `Tail` `Fluke` `Fins` `Wings` `Legs` | a curled tail, a whale's tail, flippers, folded wings, haunches and feet |
| `Frills` `Tentacles` `Fluff` | axolotl fronds, a skirt of arms, wool over the crown |
| `Crown` `Ring` `Star` | a gold crown, a tilted planet ring, a spark above the head |

A few things worth knowing:

- A unit with a `Model` ignores its features. The model is already the artwork,
  and bolting procedural ears onto it would fight it.
- A name the vocabulary doesn't have is warned about once and skipped, so a typo
  costs one unit its ears rather than breaking the game.
- `WideMouth` is the one name that builds nothing: it's read when the face is
  laid out, not run afterwards like the rest. An arc has to be placed in one go,
  and rebuilding one that a `Snout` had already moved would put it back on the
  cheek.
- Variants inherit the features of the rung they copy — a Golden Pup is a Pup.
  Sparkles have none: they're trophies, and the glow is the point of them.
- Leaving the bottom rungs plain is deliberate in both shipped themes. They're
  named after sweets rather than animals, and it's what makes the first animal,
  several merges in, feel like it was worth getting to.
- A shape nobody has built yet is added to `UnitVisuals.Features` once, and
  every other theme can then use it. Each one is handed the blob's width and
  height and the unit's colour and builds in the model's own space; anything
  sitting on the crown should overlap the head rather than rest on it, because
  the body squashes underneath it and a gap would open on every bounce.

## Publishing a new game from this base

`docs/launch-plan.md` walks through the whole of it step by step, from the first
publish to playtesting and switching the shop on.

Each Roblox experience has its own asset IDs, so per game:

- Create the gamepasses and developer products on Creator Hub, then put their IDs in
  `GamePasses` and `Products` in `src/shared/Settings.luau`. An ID left at `0`
  simply hides that shop entry — which means the whole of "What Robux buys" above
  can be built and played before the experience exists, and switched on by pasting
  eight numbers in afterwards.
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

## What's next

`ROADMAP.md` has the planned work in dependency order.

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
