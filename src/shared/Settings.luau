--!strict
-- Per-game settings. To ship a reskin: add a theme under Shared/Themes, point
-- `Theme` at it, and fill in that experience's own pass/product IDs here.

export type Settings = {
	Theme: string,
	DataStoreName: string,
	LeaderboardPrefix: string,
	StudioGems: number,
	StudioPlaytimeSpeed: number,
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

	-- Asset IDs are unique to each Roblox experience, so every reskin needs its own.
	-- 0 means "not set up yet": the matching shop button is hidden.
	GamePasses = {
		DoubleCash = 0,
		AutoMerge = 0,
		FastSpawn = 0,
	},
	Products = {
		CashSmall = 0,
		CashLarge = 0,
		UnitBoost = 0,
		GemPack = 0,
	},
}

return settings
