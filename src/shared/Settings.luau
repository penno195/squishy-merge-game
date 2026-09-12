--!strict
-- Per-game settings. To ship a reskin: add a theme under Shared/Themes, point
-- `Theme` at it, and fill in that experience's own pass/product IDs here.

export type Settings = {
	Theme: string,
	DataStoreName: string,
	LeaderboardPrefix: string,
	GamePasses: { [string]: number },
	Products: { [string]: number },
}

local settings: Settings = {
	Theme = "CandyLand",

	-- Changing this starts every player fresh. Keep it stable once the game is live.
	DataStoreName = "PlayerData_v1",
	LeaderboardPrefix = "Leaderboard_v1",

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
