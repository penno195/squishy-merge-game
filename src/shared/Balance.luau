--!strict
-- Default economy numbers, shared by every theme. A theme can override any of
-- these through its `Balance` table (tables merge, arrays replace).

return {
	StartingCash = 50,
	-- How many gardens each server builds; set the place's max players to match.
	PlotCount = 6,

	Garden = {
		Width = 48,
		Depth = 40,
		FenceHeight = 5,
		-- Gap in the fence at the front so players can run in.
		GateWidth = 12,
		-- The upgrade screen standing over the back wall.
		BoardWidth = 26,
		BoardHeight = 13,
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
		-- Drops pick a random tier from the top of the player's range: the drop
		-- tier and the 3 below it, or down to tier 1, whichever comes first.
		TierWindow = 4,
		-- Items rest a touch above the floor so they read as sitting on it.
		RestLift = 0.2,
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

	-- PerLevel is only meaningful for Income (the multiplier each level adds);
	-- the others keep it at 0 so every entry has the same shape.
	Upgrades = {
		{ Id = "SpawnSpeed", Name = "Drop Speed", BaseCost = 100, Growth = 1.6, MaxLevel = 20, PerLevel = 0 },
		{ Id = "SpawnTier", Name = "Drop Tier", BaseCost = 1000, Growth = 6, MaxLevel = 8, PerLevel = 0 },
		{ Id = "GardenSpace", Name = "Garden Space", BaseCost = 250, Growth = 8, MaxLevel = 5, PerLevel = 0 },
		{ Id = "Income", Name = "Income Boost", BaseCost = 200, Growth = 1.45, MaxLevel = 50, PerLevel = 0.25 },
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
		{ IncomeMinutes = 10, MinCash = 250 },
		{ IncomeMinutes = 15, MinCash = 500 },
		{ IncomeMinutes = 20, MinCash = 1000, UnitTierBonus = 1 },
		{ IncomeMinutes = 30, MinCash = 2500 },
		{ IncomeMinutes = 45, MinCash = 5000 },
		{ IncomeMinutes = 60, MinCash = 10000, UnitTierBonus = 2 },
	},

	Monetisation = {
		DoubleCashMultiplier = 2,
		FastSpawnMultiplier = 0.5,
		AutoMergeInterval = 1.5,
		ProductRewards = {
			CashSmall = { IncomeMinutes = 15, MinCash = 1000 },
			CashLarge = { IncomeMinutes = 120, MinCash = 10000 },
			UnitBoost = { UnitTierBonus = 2 },
		},
	},

	Leaderboard = {
		Size = 25,
		RefreshSeconds = 60,
	},

	AutosaveSeconds = 120,
}
