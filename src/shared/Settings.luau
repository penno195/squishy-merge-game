--!strict
-- Per-game settings. To ship a reskin: add a theme under Shared/Themes, point
-- `Theme` at it, and fill in that experience's own pass/product IDs here.

export type Settings = {
	Theme: string,
	DataStoreName: string,
	LeaderboardPrefix: string,
	StudioGems: number,
	StudioPlaytimeSpeed: number,
	StudioPasses: { string },
	GamePasses: { [string]: number },
	Products: { [string]: number },
}

local settings: Settings = {
	Theme = "Squishies",

	-- Changing this starts every player fresh. Keep it stable once the game is live.
	DataStoreName = "PlayerData_v1",
	LeaderboardPrefix = "Leaderboard_v1",

	-- Tops every player up to this many Gems on join **in Studio only**, so the
	-- gem-priced things can be tried before any have been earned. A live server
	-- ignores it entirely. Set to 0 to test the real drip instead.
	StudioGems = 1000,

	-- Runs the playtime ladder this many times faster **in Studio only**, so its
	-- rungs can be watched arriving instead of waited out -- at 20, the
	-- ninety-minute rung lands four and a half minutes in. A live server always
	-- runs it at 1. Set to 1 to test the real pace.
	StudioPlaytimeSpeed = 20,

	-- Passes treated as owned **in Studio only**, named as they're keyed below.
	-- A live server ignores this list entirely.
	--
	-- Without it no pass can be played at all until the experience is published
	-- and its IDs are filled in, because an ID of 0 is never checked against
	-- anything -- so every pass effect would sit untested behind a purchase that
	-- cannot happen yet. This grants the effect without the purchase.
	--
	-- It adds to real ownership rather than replacing it, so once the IDs exist a
	-- Studio session shows what the player actually owns plus whatever is listed
	-- here. Two things to remember while it's non-empty: the shop still hides any
	-- entry whose ID is 0, so this tests the *effects* and not the buying; and
	-- some of them change the baseline -- LuckCharm tilts every drop, so the mix
	-- you see is not the one a new player sees.
	--
	-- Set to {} to play as someone who has bought nothing.
	--
	-- "StarterPack" is left out on purpose. Owning it is what withdraws the offer,
	-- so listing it hides the timed card and its countdown -- the one piece of
	-- shop UI worth looking at. Add it to watch the bundle land on join instead;
	-- you can't see both in one session, because that is the point of it.
	StudioPasses = {
		"DoubleCash",
		"AutoMerge",
		"FastSpawn",
		"LuckCharm",
		"AutoCollect",
		"CraftSlot",
		"BiggerGarden",
	},

	-- Asset IDs are unique to each Roblox experience, so every reskin needs its own.
	-- 0 means "not set up yet": the matching shop button is hidden.
	GamePasses = {
		DoubleCash = 0,
		AutoMerge = 0,
		FastSpawn = 0,
		-- The lucky charm, permanently, instead of ten minutes for gems.
		LuckCharm = 0,
		-- Full-rate offline earnings, for a day instead of eight hours.
		AutoCollect = 0,
		-- A second craft running alongside the first.
		CraftSlot = 0,
		-- More room in the garden than the cash upgrade can reach.
		BiggerGarden = 0,
		-- The one-off bundle, offered for a player's first day only. A pass
		-- rather than a product because a pass can only be bought once, which is
		-- what "one-time" has to mean when real money is involved.
		StarterPack = 0,
	},
	Products = {
		CashSmall = 0,
		CashLarge = 0,
		UnitBoost = 0,
		GemPack = 0,
	},
}

return settings
