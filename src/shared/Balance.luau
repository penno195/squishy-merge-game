--!strict
-- Default economy numbers, shared by every theme. A theme can override any of
-- these through its `Balance` table (tables merge, arrays replace).

local Types = require(script.Parent.Types)

return {
	StartingCash = 50,
	-- How many gardens each server builds; set the place's max players to match.
	PlotCount = 6,

	-- The hub in the middle of the map, and how far out the gardens sit.
	Hub = {
		-- Space between neighbouring gardens. Raising this pushes every garden
		-- further out, which is the main knob for how open the arena feels.
		-- With six gardens the plot radius works out at 48 + this.
		PlotGap = 72,
		-- Keeps the gardens clear of the hub even with only a couple of them.
		Clearance = 60,
		-- The moving walkway, as a fraction of the distance out to the gardens.
		-- Deliberately well inside them: the ring of open ground between the
		-- walkway and the garden fences is where the arena gets its room to
		-- breathe, and where most of the scenery stands. Stepping off the
		-- walkway onto a path is the start of the walk home, not the end of it.
		RingFraction = 0.36,
		RingWidth = 12,
		-- How fast the walkway carries players, in studs per second. Roughly
		-- doubles walking speed without making it hard to step off.
		RingSpeed = 26,
		-- Straight segments the ring is built from: more is smoother, and more
		-- parts. 48 keeps each segment under 7 studs long.
		RingSegments = 48,
		-- The pad players spawn on before they're sent to their garden.
		SpawnOffset = 22,
		PadThickness = 1,
	},

	-- Where scenery stands. Each zone is a ring of evenly spaced slots which the
	-- active theme fills from its own `Props` table, so the layout is shared and
	-- only what stands in it changes between skins.
	--
	-- `Radius` is a fraction of the distance out to the gardens. `Offset` turns
	-- the ring by that fraction of one slot, so 0.5 puts slots in the gaps
	-- between gardens rather than in front of them. `Jitter` is studs of random
	-- in-and-out, applied along the radius only: nudging them sideways too would
	-- eventually drop one across a path.
	--
	-- A prop's `Height` is not its footprint: the shapes vary from a Cane at
	-- 0.3 times its height across to a Butter at 1.55, so the rings are sized
	-- for the widest thing a theme might stand in them.
	--
	-- Every ring has to clear the walkway on the way in and the gardens on the
	-- way out, and a prop's own width counts against both. `HubEdge` sat at
	-- 0.62 for a while, which put it on top of the walkway once that moved.
	PropZones = {
		-- A ring hugging the open side of the walkway, at a size you walk past.
		{ Id = "HubEdge", Count = 12, Radius = 0.55, Offset = 0.5, Jitter = 3 },
		-- Out in the middle of the open ground, between the walkway and the
		-- gardens. Offset half a slot so nothing lands across a garden path.
		{ Id = "Approach", Count = 12, Radius = 0.7, Offset = 0.5, Jitter = 4 },
		-- Was level with the gardens, which only worked while every prop was a
		-- narrow cone. The plinths then widened each garden's reach from 24
		-- studs to 28 and the ring started cutting into them, so it sits out
		-- past them now: 54 studs from a garden's centre, 26 clear of its
		-- plinths before the prop's own width is counted.
		{ Id = "BetweenGardens", Count = 6, Radius = 1.15, Offset = 0.5, Jitter = 5 },
		-- Far enough out that even the inward end of its jitter clears the back
		-- of the gardens, which reach 1.23 of the plot radius -- with enough
		-- room left over for the prop's own depth, which is what the old jitter
		-- of 14 didn't allow for once the shapes got wide.
		{ Id = "Outer", Count = 24, Radius = 1.45, Offset = 0, Jitter = 10 },
	},

	Garden = {
		-- Sized off what has to fit on the floor, not off how it looks empty.
		-- An item needs `Drop.Spacing` clear of its neighbours, so hexagon-packed
		-- each one claims `Spacing^2 * sqrt(3)/2` -- about 37 square studs at the
		-- default 6.5. The usable floor is the fence less `Drop.EdgePadding` on
		-- every side, less the corner the bin keeps clear.
		--
		-- At the 48x40 this was, that came to room for 29 items touching, against
		-- a capacity of 40 -- or 55 with the Bigger Garden pass. Placement asks
		-- for a clear spot a few times and then gives up and overlaps, so every
		-- upgraded garden was a heap. At 76x66 the same 55 items have 1.8x the
		-- floor they need, which reads as scattered rather than tiled.
		--
		-- Widening pushes the whole arena out rather than crowding it: the plot
		-- radius is `Width + Hub.PlotGap`, so the gap between neighbouring
		-- gardens stays exactly PlotGap whatever this is.
		Width = 76,
		Depth = 66,
		FenceHeight = 5,
		-- Gap in the fence at the front so players can run in.
		GateWidth = 12,
		-- The upgrade screen standing over the back wall. It spans the full
		-- width of the fence, so only its height is a free knob. Tall enough
		-- that the five tiles across it are portrait cards rather than a
		-- letterbox strip -- which means it has to grow with Width, or the
		-- tiles flatten out as the fence gets wider.
		BoardHeight = 28,
	},

	-- How many items the ground holds, per Garden Space level (index 1 = level 0).
	-- Read against Garden.Width and Depth: the floor has to have room for the last
	-- number here plus Monetisation.BiggerGardenSpaces.
	GardenCapacities = { 12, 16, 21, 27, 33, 40 },

	Drop = {
		BaseInterval = 10,
		MinInterval = 2,
		-- Interval multiplier per Drop Speed level.
		Factor = 0.9,
		-- Each wait is randomised by up to this fraction either way, so drops
		-- don't arrive like a metronome.
		Jitter = 0.4,
		-- Drops pick a tier from a window at the top of the player's range: the
		-- drop tier and the tiers below it. One weight per rung, lowest first,
		-- and the window is as wide as this list. Pyramid-shaped on purpose --
		-- there's always plenty of low-tier fodder to merge with, and the top
		-- of the window stays a genuine prize. Luck tilts it upward.
		TierWeights = { 50, 25, 15, 10, 5 },
		-- Items fall in from this height, over this long.
		FallHeight = 70,
		FallSeconds = 0.9,
		-- Keep landings off the fence line and out of each other's laps.
		EdgePadding = 5,
		-- Comfortably wider than the pickup radius, so walking up to one item
		-- doesn't put you on top of its neighbour.
		Spacing = 6.5,
	},

	-- Variants: the same unit, worth more. A drop rolls a tier first and then a
	-- variant, so a variant is a second axis over the whole ladder rather than
	-- content of its own -- thirty rungs become a hundred and twenty without a
	-- single new model, and every drop carries a chance of something better
	-- than its tier.
	--
	-- This list is the mechanics: how rare each one is, and what it multiplies
	-- income and sale value by. A theme names and colours them in its own
	-- `Variants` table, keyed by these Ids; one it says nothing about falls
	-- back to the Id as its name and a default tint, so a new skin gets working
	-- variants before anyone has picked a palette for them.
	--
	-- Ordinary-first, rarest-last, and the chances have to add up to less than
	-- 1 -- whatever is left over is an ordinary unit, which is most of them.
	-- Luck lifts each chance by (1 + Bias), the same tilt it puts on the tier
	-- pyramid, so a charm is worth buying for two reasons at once.
	-- `CraftBoost` is what a variant is worth in the crafting machine. It lifts
	-- the ceiling on that load's sparkle chance rather than the chance itself,
	-- so a rare one is worth feeding to a machine already full of the band's
	-- best tier. That's the decision a variant is for — leave it in the garden
	-- earning, or spend it on the odds. Boosts multiply when several go in, and
	-- what they buy is a share of the gap up to Craft.HardCap, so the ladder
	-- stays distinguishable instead of everything above Shiny hitting the cap.
	Variants = {
		{ Id = "Shiny", Chance = 0.06, Income = 3, CraftBoost = 1.35, PetPerk = 1.5 },
		{ Id = "Golden", Chance = 0.012, Income = 12, CraftBoost = 2.1, PetPerk = 2.2 },
		{ Id = "Rainbow", Chance = 0.002, Income = 60, CraftBoost = 3.6, PetPerk = 3.5 },
	},

	-- Pets. One follows at the player's heels at a time and the rest wait in the
	-- inventory, swappable whenever, which is the decision the whole system turns
	-- on: a pet is a tool you pick for what you are about to do, not a number you
	-- accumulate. So the *perk* is the reason to own one and the cash multiplier
	-- is a nudge -- 3% to 15% across the entire rarity ladder. A pet that paid
	-- double would be welded on forever and there would be nothing to choose.
	--
	-- Which pets exist is theme data. What a rarity and a perk are worth is here,
	-- so a reskin names pets and balances none of them.
	Pets = {
		-- One at a time. Raising this would need the panel and the heel offset
		-- revisited, and would dilute the choosing that is the point.
		EquipSlots = 1,
		-- How close to an egg pad a player has to be to hatch. Also the range its
		-- prompt answers from, and re-checked on the server: a ProximityPrompt is
		-- driven by the client, so the distance it enforces is the client's word.
		PadRadius = 14,
		-- Room to collect the whole vocabulary a few times over without a save
		-- that grows without limit. Full means the pads refuse to hatch until
		-- something is released.
		MaxOwned = 24,
		-- What an egg costs is priced off the rarity it can reach, and the ladder
		-- is narrow, so these are priced as a thing to spend a working income on
		-- rather than a wall. `Weights` replaces the rarity weights by Id, and a
		-- rarity an egg doesn't list can't come out of it -- which is the whole
		-- reason to walk to a dearer pad.
		Eggs = {
			{
				Id = "Basic",
				Tone = "Surface",
				Name = "Basic Egg",
				Cost = 2500,
				Weights = { Common = 72, Rare = 25, Epic = 3 },
			},
			{
				Id = "Golden",
				Tone = "Accent",
				Name = "Golden Egg",
				Cost = 120000,
				Weights = { Common = 30, Rare = 45, Epic = 22, Legendary = 3 },
			},
			{
				Id = "Rainbow",
				Tone = "Primary",
				Name = "Rainbow Egg",
				Cost = 5000000,
				Weights = { Rare = 28, Epic = 52, Legendary = 20 },
			},
			-- Annotated because the eggs weight different sets of rarities, and Luau
			-- would otherwise infer the whole list from the first one.
		} :: { Types.PetEggDef },
		-- `Multiplier` is the cash multiplier the equipped pet adds. `Perk` scales
		-- its perk's Amount, and is where rarity is allowed to matter: a Legendary
		-- pays 12% more than a Common and is three times better at its job.
		--
		-- No weights here. How often a rarity turns up is the egg's business, and
		-- lives in Eggs.Weights above -- two places saying it would be two answers.
		Rarities = {
			{ Id = "Common", Name = "Common", Multiplier = 1.03, Perk = 1, Tone = "TextMuted" },
			{ Id = "Rare", Name = "Rare", Multiplier = 1.06, Perk = 1.6, Tone = "Primary" },
			{ Id = "Epic", Name = "Epic", Multiplier = 1.1, Perk = 2.3, Tone = "Secondary" },
			{ Id = "Legendary", Name = "Legendary", Multiplier = 1.15, Perk = 3, Tone = "Accent" },
		},
		-- The vocabulary. A pet names one of these and the code that applies it
		-- switches on the Id, so a theme can only choose among what exists --
		-- adding a perk is shared work, which is the reskin promise.
		--
		-- `Amount` is one unit of strength, multiplied by the rarity's `Perk` and
		-- again by the variant's `PetPerk`. What it means per perk:
		--   MergeCash  fraction of the merged unit's value, paid on every merge
		--   GemFind    chance of a Gem on a merge, capped at 1
		--   CraftLuck  added to the boost on a craft's sparkle ceiling
		--   SellBonus  added to Bin.Refund, so the bin pays better
		--   DropLuck   added to Luck's bias on the drop roll
		--   Space      extra room in the garden, rounded down to whole spaces
		Perks = {
			{
				Id = "MergeCash",
				Name = "Merge Payout",
				Description = "Pays out every time you merge",
				Amount = 0.2,
			},
			{
				Id = "GemFind",
				Name = "Gem Finder",
				Description = "Merges sometimes turn up a Gem",
				Amount = 0.012,
			},
			{
				Id = "CraftLuck",
				Name = "Lucky Crafter",
				Description = "Better odds at the machine",
				Amount = 0.25,
			},
			{
				Id = "SellBonus",
				Name = "Haggler",
				Description = "The bin pays more",
				Amount = 0.1,
			},
			{
				Id = "DropLuck",
				Name = "Charmed",
				Description = "Tilts drops toward the top of your range",
				Amount = 0.35,
			},
			{
				Id = "Space",
				Name = "Gardener",
				Description = "Makes room in the garden",
				Amount = 2,
			},
		},
	},

	Pickup = {
		-- How close the player has to get to scoop an item up.
		Radius = 4,
	},

	-- The bin, in a corner of the garden: run into it carrying a unit to sell
	-- it off. Somewhere for tiers that have dropped out of the drop window and
	-- can no longer find a partner to merge with.
	Bin = {
		Radius = 5,
		-- Fraction of the tier's base price paid back. Below 1 so binning a
		-- bought unit can never pay for itself.
		Refund = 0.5,
	},

	-- Where a carried item sits, relative to the player's middle: held out in
	-- front with both arms rather than floating overhead.
	Hold = {
		Height = 0.4,
		Distance = 1.1,
	},

	Income = {
		-- Cash per second from a tier 1 item lying in the garden.
		Base = 1,
		-- Each tier earns this many times the tier below. Above 2 so merging always pays.
		TierGrowth = 2.5,
	},

	BuyUnit = {
		BaseCost = 10,
		-- Cost grows per item bought since the last rebirth.
		Growth = 1.04,
	},

	-- PerLevel is what each level adds: a cash multiplier for Income. The rest
	-- keep it at 0 so every entry has the same shape.
	-- Order matters: this is the order the garden board shows them in.
	--
	-- Drop Tier is the pacing knob for the whole game, and its Growth only means
	-- anything read against Income.TierGrowth: the cost rises by `Growth` per
	-- level while the income that pays for it rises by `TierGrowth`, so what the
	-- player feels is the ratio between them. At 2.8 against 2.5 that ratio is
	-- 1.12 -- each level costs 12% more playtime than the last.
	--
	-- Keeping the ratio near 1 and moving BaseCost is deliberate, and it is the
	-- one thing to understand before changing either. The ratio decides the
	-- *shape* of the game and BaseCost decides its *length*, and the shape goes
	-- bad long before it looks like it should:
	--
	--     ratio 1.12  ->  the ladder is   191x the first level, last level 11% of it
	--     ratio 1.28  ->  the ladder is  3583x the first level, last level 22% of it
	--     ratio 1.56  ->  the ladder is 456351x the first level, last level 36% of it
	--
	-- At 1.56 (Growth 3.9, which was tried) the tail is not a curve, it is a wall:
	-- the sim reached tier 20 in an hour and a half on one run and not within two
	-- days on the next, because a single level either side of the budget is most of
	-- the game. At 1.12 the last level is a ninth of the run and the whole thing
	-- lengthens smoothly, so BaseCost is the honest knob -- 1000 to 25000 makes the
	-- first gate a few minutes' income instead of a few seconds'.
	--
	-- These numbers are measured, not guessed. `tests/sim.luau` plays a run against
	-- this file and prints when each tier arrived. Buying nothing: first upgrade at
	-- a minute, tier 10 -- and so the first rebirth -- at half an hour, tier 15
	-- around an hour, tier 20 under two, and the top of the ladder a goal across
	-- several sittings that rebirths are meant to carry. The four passes that
	-- change the pace are worth roughly three times, which is meant to be worth
	-- buying without being the only way up.
	--
	-- It was BaseCost 1000 at the same 2.8, with the other three at 1.6, 8 and
	-- 1.45. The sim put the whole thirty-rung ladder and every upgrade maxed at
	-- about half an hour, and twelve minutes with the passes -- which makes a
	-- four-hour craft, a daily streak and a weekly race meaningless. The other
	-- three got steeper for a different reason: at those numbers they were
	-- affordable the moment they appeared for the whole game, so there was never a
	-- choice about what to buy next, only a button to hold. Income's PerLevel came
	-- down with it, 0.25 to 0.15, because fifty levels of a quarter each was a free
	-- 13x on top of everything else.
	--
	-- Drop Tier's MaxLevel is 28 rather than 24 because `Economy.upgradeMaxLevel`
	-- clamps it to `MaxTier - 2` anyway, which is what should govern it: at 24 on a
	-- thirty-rung ladder drops stopped at tier 25, so the last five rungs had to be
	-- mass-merged at the capacity ceiling. That either happened or it didn't -- the
	-- sim reached tier 30 on one run and never on the next. Letting the clamp bind
	-- makes the top of the ladder something you buy your way to, and makes this
	-- entry correct for a theme of any length.
	Upgrades = {
		{ Id = "SpawnTier", Name = "Drop Tier", BaseCost = 25000, Growth = 2.8, MaxLevel = 28, PerLevel = 0 },
		{ Id = "SpawnSpeed", Name = "Drop Speed", BaseCost = 120, Growth = 2.1, MaxLevel = 20, PerLevel = 0 },
		{ Id = "GardenSpace", Name = "Max Items", BaseCost = 300, Growth = 11, MaxLevel = 5, PerLevel = 0 },
		{ Id = "Income", Name = "Income Boost", BaseCost = 250, Growth = 1.7, MaxLevel = 50, PerLevel = 0.15 },
	},

	-- The timed earning boost, bought with gems from the garden board.
	Boost = {
		Multiplier = 5,
		Seconds = 300,
		GemCost = 25,
	},

	-- Luck, the other thing gems buy. It tilts the drop pyramid upward while
	-- it runs: every rung is multiplied by (1 + Bias) more than the one below
	-- it, which takes the top of the drop window from about 5% of drops to
	-- about 43% without ever making a tier impossible.
	--
	-- Cheaper than the boost and twice as long, because what it buys is
	-- indirect -- better drops to merge, rather than cash in hand -- and
	-- because ten minutes is long enough to actually watch the mix change.
	Luck = {
		Bias = 2,
		Seconds = 600,
		GemCost = 10,
	},

	-- Auto merge on a clock, the third thing on the gem column of the board. The
	-- Auto Merge pass is the same thing forever, the way Lucky Forever is to the
	-- charm, so this has to be worth trying without being a substitute: five
	-- minutes is long enough to feel a garden tidy itself and short enough that
	-- keeping it running all session costs far more than the drip pays.
	--
	-- A first guess, not measured. The sim doesn't spend gems.
	AutoMerge = {
		Seconds = 300,
		GemCost = 20,
	},

	-- Gems are the premium currency: a slow drip from playing, or bought with
	-- Robux. Only ever spent on the boost, so the drip has to stay small.
	Gems = {
		PerDiscovery = 3,
		PerRebirth = 25,
	},

	Rebirth = {
		BaseCost = 1e6,
		Growth = 4,
		-- Permanent cash multiplier gained per rebirth.
		MultiplierPerRebirth = 0.5,
		-- A rebirth also needs the garden to have climbed: the best rung lying
		-- in it has to reach this one. Cash on its own makes the gate a waiting
		-- game -- park a full garden, come back, press the button -- where a
		-- rung has to be merged for. The requirement rises with each rebirth,
		-- so the run after a rebirth is a longer climb rather than a faster
		-- repeat of the same one, and it stops short of the top of the ladder
		-- so the last rebirths stay reachable.
		BaseTier = 10,
		TierPerRebirth = 1,
	},

	OfflineEarnings = {
		MinSeconds = 60,
		MaxHours = 8,
		-- Fraction of normal income earned while away.
		Rate = 0.5,
	},

	-- Rewards scale with the player's current income so they stay useful at every stage.
	-- `UnitTierBonus` drops an item that many tiers above the player's drop tier.
	DailyRewards = {
		{ IncomeMinutes = 5, MinCash = 100 },
		{ IncomeMinutes = 10, MinCash = 250, Gems = 5 },
		{ IncomeMinutes = 15, MinCash = 500 },
		{ IncomeMinutes = 20, MinCash = 1000, UnitTierBonus = 1, Gems = 10 },
		{ IncomeMinutes = 30, MinCash = 2500 },
		{ IncomeMinutes = 45, MinCash = 5000, Gems = 15 },
		{ IncomeMinutes = 60, MinCash = 10000, UnitTierBonus = 2, Gems = 30 },
	},

	Monetisation = {
		DoubleCashMultiplier = 2,
		FastSpawnMultiplier = 0.5,
		AutoMergeInterval = 1.5,
		-- Auto Collect: the offline clock on better terms. Rate 1 against the
		-- usual 0.5 means an hour away is worth an hour played, and the cap goes
		-- from one working day to a whole one -- which is the difference between
		-- logging off costing you the night and logging off being free.
		AutoCollect = { Rate = 1, MaxHours = 24 },
		-- Bigger Garden: spaces on top of whatever Garden Space has reached,
		-- rather than extra levels of it. Levels would have to line up with
		-- GardenCapacities, and a flat number keeps the pass worth the same to a
		-- player at level 0 as at level 5 -- which is the one who is likely to
		-- buy it.
		BiggerGardenSpaces = 15,
		-- Second Slot: crafts that can run alongside the first.
		ExtraCraftSlots = 1,
		-- The starter pack. `Hours` is how long after a player's first join it
		-- stays on offer; the pass is hidden from the shop after that, and from
		-- anyone who has already had it.
		--
		-- Priced as a pack rather than a pass: it is deliberately worth more than
		-- its parts, because a first-session player has no income for
		-- IncomeMinutes to multiply and the floor is what they actually get.
		StarterPack = {
			Hours = 24,
			Reward = { IncomeMinutes = 60, MinCash = 5000, Gems = 150, UnitTierBonus = 3 },
		},
		ProductRewards = {
			CashSmall = { IncomeMinutes = 15, MinCash = 1000 },
			CashLarge = { IncomeMinutes = 120, MinCash = 10000 },
			UnitBoost = { UnitTierBonus = 2 },
			GemPack = { Gems = 120 },
		},
	},

	-- The prize wheel, one of the four stations round the hub's rim. One free spin
	-- a day, more for
	-- gems. `Reward` is the same shape as a daily reward, so RewardService
	-- grants wheel prizes with no special cases.
	Wheel = {
		FreeSpinsPerDay = 1,
		GemCost = 10,
		-- How long the wheel takes to slow to a stop, in seconds.
		SpinSeconds = 4.5,
		-- `Tone` names a Palette entry, so the wheel is coloured by the theme.
		-- Weights are relative; they don't have to add up to anything.
		Prizes = {
			{ Label = "Small Cash", Weight = 26, Tone = "Positive", Reward = { IncomeMinutes = 3, MinCash = 250 } },
			{ Label = "3 Gems", Weight = 20, Tone = "Secondary", Reward = { Gems = 3 } },
			{ Label = "Big Cash", Weight = 18, Tone = "Positive", Reward = { IncomeMinutes = 10, MinCash = 1000 } },
			{ Label = "8 Gems", Weight = 14, Tone = "Secondary", Reward = { Gems = 8 } },
			{ Label = "Bonus Unit", Weight = 10, Tone = "Primary", Reward = { UnitTierBonus = 1 } },
			{ Label = "Huge Cash", Weight = 7, Tone = "Accent", Reward = { IncomeMinutes = 45, MinCash = 10000 } },
			{ Label = "25 Gems", Weight = 4, Tone = "Secondary", Reward = { Gems = 25 } },
			{ Label = "Rare Unit", Weight = 1, Tone = "Negative", Reward = { UnitTierBonus = 3 } },
			-- Annotated because the entries differ in shape, and Luau would
			-- otherwise infer the whole array from the first one.
		} :: { Types.WheelPrize },
	},

	-- The crafting station, stood on the hub's rim opposite the spawn pad. Feed it
	-- ordinary
	-- units, wait, and it makes something back -- usually a few tiers up, and
	-- sometimes one of the theme's sparkles.
	--
	-- The odds are built from what went in. Each input counts for
	-- `TierWeight ^ (tier - the bottom of the band being played for)`, so one
	-- unit from the top of a three-tier band is worth four from the bottom of
	-- it. Filling every slot with the band's top tier is the only way to reach
	-- the ceiling, and the ceiling is deliberately a coin flip: a sparkle you
	-- are more likely than not to get isn't a sparkle.
	Craft = {
		-- How many crafts can run at once, before the pass adds any. The inputs
		-- each one takes are `Inputs` below: what a player calls a slot is a
		-- craft, not a place to put a unit.
		Slots = 1,
		Inputs = 4,
		-- How close a player has to be to feed the machine. Also the range its
		-- prompt answers from.
		Radius = 16,
		-- Long enough to bridge two sittings without writing off an evening.
		-- See the README for why this is 4 hours and not 6.
		Seconds = 4 * 3600,
		-- Gems to finish one early, per hour still left on the clock.
		SkipGemsPerHour = 8,
		TierWeight = 2,
		-- The odds at an empty-ish machine and at a full one. A theme's sparkle
		-- can lower its own ceiling; only variants raise it.
		MinChance = 0.02,
		MaxChance = 0.5,
		-- However many variants go in, a craft never becomes a certainty. Four
		-- Rainbows on the bottom band reach this and stop.
		HardCap = 0.9,
		-- Above 1, so a nearly-full machine is worth far more than a half-full
		-- one and there's a reason to wait for the fourth unit.
		Curve = 1.4,
		-- A sparkle earns like an ordinary unit this many tiers above the top of
		-- its band -- one better than the best a craft can otherwise produce.
		SparkleIncomeTiers = 4,
		-- What comes out when the sparkle doesn't: an ordinary unit this many
		-- tiers above the best one fed in. `Share` splits whatever the sparkle
		-- left behind. Both are capped at the top of the ladder, and collapse
		-- into one outcome when the cap catches them.
		Consolation = {
			{ Tiers = 3, Share = 0.6 },
			{ Tiers = 1, Share = 0.4 },
		},
	},

	-- Quests: three a day and one a week, each one a tally of a verb the game
	-- already announces. `Stat` names a StatsService counter, and progress is
	-- measured from where that counter stood when the quest was handed out, so
	-- nothing has to be tracked twice.
	--
	-- Rewards are ordinary reward bundles, the same ones the wheel and the
	-- daily streak use, so they scale with the player's income and a theme can
	-- re-price them without touching any code.
	Quests = {
		DailyCount = 3,
		-- Pool for the daily three. Wider than DailyCount so the set changes.
		Daily = {
			{
				Id = "DailyMerge",
				Text = "Merge units",
				Stat = "Merges",
				Target = 30,
				Reward = { IncomeMinutes = 6, MinCash = 400 },
			},
			{
				Id = "DailyCollect",
				Text = "Collect drops",
				Stat = "Drops",
				Target = 40,
				Reward = { IncomeMinutes = 5, MinCash = 300 },
			},
			{
				Id = "DailyUpgrade",
				Text = "Buy upgrades",
				Stat = "Upgrades",
				Target = 3,
				Reward = { IncomeMinutes = 8, MinCash = 500 },
			},
			{
				Id = "DailySell",
				Text = "Sell units to the bin",
				Stat = "Sales",
				Target = 8,
				Reward = { IncomeMinutes = 4, MinCash = 250 },
			},
			{
				Id = "DailySpin",
				Text = "Spin the prize wheel",
				Stat = "Spins",
				Target = 1,
				Reward = { IncomeMinutes = 5, MinCash = 300, Gems = 2 },
			},
			{
				Id = "DailyCraft",
				Text = "Start a craft",
				Stat = "Crafts",
				Target = 1,
				Reward = { IncomeMinutes = 10, MinCash = 600, Gems = 3 },
			},
			{
				Id = "DailyDiscover",
				Text = "Discover new units",
				Stat = "Discoveries",
				Target = 2,
				Reward = { IncomeMinutes = 7, MinCash = 450 },
			},
		},
		-- Pool for the one weekly. Bigger asks, bigger bundles.
		Weekly = {
			{
				Id = "WeekMerge",
				Text = "Merge units this week",
				Stat = "Merges",
				Target = 400,
				Reward = { IncomeMinutes = 45, MinCash = 5000, Gems = 15 },
			},
			{
				Id = "WeekCraft",
				Text = "Collect finished crafts",
				Stat = "CraftsCollected",
				Target = 3,
				Reward = { IncomeMinutes = 60, MinCash = 8000, Gems = 25 },
			},
			{
				Id = "WeekDiscover",
				Text = "Discover new units this week",
				Stat = "Discoveries",
				Target = 10,
				Reward = { IncomeMinutes = 50, MinCash = 6000, Gems = 20 },
			},
			{
				Id = "WeekUpgrade",
				Text = "Buy upgrades this week",
				Stat = "Upgrades",
				Target = 25,
				Reward = { IncomeMinutes = 40, MinCash = 4000, Gems = 12 },
			},
		},
	},

	-- Playtime rewards: a ladder of claims through one sitting. The rungs are
	-- minutes into the current session and they reset when the player leaves, so
	-- this is a reason to stay rather than a second daily -- which is why the
	-- early ones land fast and the late ones are worth waiting for.
	--
	-- Rungs must be listed in ascending order; Economy asserts it, because a
	-- ladder out of order would show the panel's rows climbing and falling.
	Playtime = {
		Rungs = {
			{ Minutes = 1, Reward = { IncomeMinutes = 2, MinCash = 100 } },
			{ Minutes = 5, Reward = { IncomeMinutes = 5, MinCash = 300 } },
			{ Minutes = 10, Reward = { IncomeMinutes = 8, MinCash = 600, Gems = 2 } },
			{ Minutes = 20, Reward = { IncomeMinutes = 14, MinCash = 1200 } },
			{ Minutes = 30, Reward = { IncomeMinutes = 20, MinCash = 2000, Gems = 5 } },
			{ Minutes = 45, Reward = { IncomeMinutes = 30, MinCash = 3500, UnitTierBonus = 1 } },
			{ Minutes = 60, Reward = { IncomeMinutes = 45, MinCash = 6000, Gems = 12 } },
			{ Minutes = 90, Reward = { IncomeMinutes = 70, MinCash = 10000, UnitTierBonus = 2, Gems = 20 } },
		},
	},

	Leaderboard = {
		Size = 25,
		-- Gems paid to last week's top finishers, by finishing place. The list's
		-- own length is how many places pay, so shortening it is the knob for
		-- making the prize rarer. It pays steeply at the top on purpose: a prize
		-- spread evenly over ten places is ten players' worth of nothing much.
		Prizes = { 250, 150, 100, 60, 40, 30, 25, 20, 15, 10 },
		RefreshSeconds = 60,
		-- How many of those the board in the hub shows. Fewer than the panel,
		-- because it's read from across the map rather than scrolled.
		BoardRows = 8,
	},

	AutosaveSeconds = 120,
}
