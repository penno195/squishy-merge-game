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
		Width = 48,
		Depth = 40,
		FenceHeight = 5,
		-- Gap in the fence at the front so players can run in.
		GateWidth = 12,
		-- The upgrade screen standing over the back wall. It spans the full
		-- width of the fence, so only its height is a free knob. Tall enough
		-- that the five tiles across it are portrait cards rather than a
		-- letterbox strip.
		BoardHeight = 18,
	},

	-- How many items the ground holds, per Garden Space level (index 1 = level 0).
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
	-- Drop Tier is the ladder's pacing knob, and its Growth has to be read
	-- against Income.TierGrowth: the cost rises by `Growth` per level while the
	-- income that pays for it rises by `TierGrowth`, so what the player feels is
	-- the ratio between them. At 2.8 against 2.5 each level costs about 12% more
	-- playtime than the last -- roughly five minutes of income at the bottom of
	-- the ladder and eighty at the top. (It was 6, which is 2.4x more playtime
	-- per level: by level 8 that was already a ninety-hour upgrade, and over a
	-- thirty-rung ladder it diverges into the absurd.)
	Upgrades = {
		{ Id = "SpawnTier", Name = "Drop Tier", BaseCost = 1000, Growth = 2.8, MaxLevel = 24, PerLevel = 0 },
		{ Id = "SpawnSpeed", Name = "Drop Speed", BaseCost = 100, Growth = 1.6, MaxLevel = 20, PerLevel = 0 },
		{ Id = "GardenSpace", Name = "Max Items", BaseCost = 250, Growth = 8, MaxLevel = 5, PerLevel = 0 },
		{ Id = "Income", Name = "Income Boost", BaseCost = 200, Growth = 1.45, MaxLevel = 50, PerLevel = 0.25 },
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
		ProductRewards = {
			CashSmall = { IncomeMinutes = 15, MinCash = 1000 },
			CashLarge = { IncomeMinutes = 120, MinCash = 10000 },
			UnitBoost = { UnitTierBonus = 2 },
			GemPack = { Gems = 120 },
		},
	},

	-- The prize wheel in the middle of the hub. One free spin a day, more for
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

	-- The crafting station standing in the middle of the hub. Feed it ordinary
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
		Slots = 4,
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
		-- can lower its own ceiling; nothing raises it.
		MinChance = 0.02,
		MaxChance = 0.5,
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

	Leaderboard = {
		Size = 25,
		RefreshSeconds = 60,
	},

	AutosaveSeconds = 120,
}
