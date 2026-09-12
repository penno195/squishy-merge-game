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
		PlotGap = 40,
		-- Keeps the gardens clear of the hub even with only a couple of them.
		Clearance = 60,
		-- The moving walkway, as a fraction of the distance out to the gardens.
		-- Far enough out to be a short hop from each gate.
		RingFraction = 0.56,
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
	PropZones = {
		{ Id = "HubEdge", Count = 12, Radius = 0.68, Offset = 0.5, Jitter = 4 },
		{ Id = "BetweenGardens", Count = 6, Radius = 1, Offset = 0.5, Jitter = 6 },
		-- Far enough out that even the inward end of its jitter clears the back
		-- of the gardens, which reach 1.23 of the plot radius.
		{ Id = "Outer", Count = 24, Radius = 1.5, Offset = 0, Jitter = 14 },
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

	-- PerLevel is what each level adds: a cash multiplier for Income, and roll
	-- bias for Luck. The rest keep it at 0 so every entry has the same shape.
	-- Order matters: this is the order the garden board shows them in.
	Upgrades = {
		{ Id = "SpawnTier", Name = "Drop Tier", BaseCost = 1000, Growth = 6, MaxLevel = 8, PerLevel = 0 },
		{ Id = "SpawnSpeed", Name = "Drop Speed", BaseCost = 100, Growth = 1.6, MaxLevel = 20, PerLevel = 0 },
		{ Id = "GardenSpace", Name = "Max Items", BaseCost = 250, Growth = 8, MaxLevel = 5, PerLevel = 0 },
		{ Id = "Luck", Name = "Increase Luck", BaseCost = 400, Growth = 1.9, MaxLevel = 12, PerLevel = 0.35 },
		{ Id = "Income", Name = "Income Boost", BaseCost = 200, Growth = 1.45, MaxLevel = 50, PerLevel = 0.25 },
	},

	-- The timed earning boost, bought with gems from the garden board.
	Boost = {
		Multiplier = 5,
		Seconds = 300,
		GemCost = 25,
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

	Leaderboard = {
		Size = 25,
		RefreshSeconds = 60,
	},

	AutosaveSeconds = 120,
}
