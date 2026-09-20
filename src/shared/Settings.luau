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
	StaffUserIds: { number },
	StaffGroupRank: number,
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
	-- Empty by default, so Studio plays the game a new player actually gets. Add the
	-- ones you mean to test and take them out again afterwards:
	--
	--   "DoubleCash"    x2 income
	--   "FastSpawn"     drops twice as often
	--   "LuckCharm"     the lucky charm, permanently
	--   "AutoCollect"   full-rate offline earnings for a day
	--   "CraftSlot"     a second craft running alongside the first
	--   "BiggerGarden"  more room than the cash upgrade reaches
	--   "AutoMerge"     merges a matching pair for you every 1.5 seconds
	--   "StarterPack"   grants the bundle on join
	--
	-- Two of those are worth a warning. **AutoMerge plays the core loop for you** --
	-- items land and pair off on their own, which looks like units randomly
	-- upgrading and vanishing and makes the game impossible to judge. And
	-- StarterPack, owning it is what withdraws the offer, so listing it hides the
	-- timed shop card and its countdown; you can see the offer or the bundle landing,
	-- not both in one session, because that is the point of a one-time offer.
	--
	-- This list was all seven for a while. That was a mistake: between x2 income,
	-- double drop rate, permanent luck and a bigger garden, Studio was running about
	-- three times faster than the real game, which is not the thing anyone is trying
	-- to look at.
	StudioPasses = {},

	-- Who else gets the staff panel, by Roblox user id. Whoever owns the experience
	-- has it already -- the creator when a person owns it, and anyone at or above
	-- StaffGroupRank when a group does -- so this is for the other admins.
	-- A user id is the number in the address of their profile page.
	StaffUserIds = {
		10068109232, -- sillynoah676767
		1446512024, -- louiepoolo05
	},
	-- 255 is the group's owner. Lower it to let a trusted rank in too.
	StaffGroupRank = 255,

	-- Asset IDs are unique to each Roblox experience, so every reskin needs its own.
	-- 0 means "not set up yet": the matching shop button is hidden.
	-- Created through Open Cloud on 2026-09-20, which can make passes but not
	-- products: POST a multipart Name/Description/File to
	-- `game-passes/v1/universes/<id>/game-passes`, then PATCH the same path with
	-- the id on the end to set Price and IsForSale. Products have a listing
	-- endpoint (`developer-products/v2/...?limit=n`) but no creation one, so
	-- those four are made by hand on the Creator Hub.
	GamePasses = {
		DoubleCash = 1983465880,
		AutoMerge = 1982745826,
		FastSpawn = 1984287797,
		-- The lucky charm, permanently, instead of ten minutes for gems.
		LuckCharm = 1986849214,
		-- Full-rate offline earnings, for a day instead of eight hours.
		AutoCollect = 1986489280,
		-- A second craft running alongside the first.
		CraftSlot = 1986429407,
		-- More room in the garden than the cash upgrade can reach.
		BiggerGarden = 1984719808,
		-- The admin panel: trolling commands to use on other players. Needs no
		-- entry in StudioPasses -- everyone in Studio is an admin, and so is the
		-- experience's creator on a live server.
		Admin = 1986543218,
		-- The one-off bundle, offered for a player's first day only. A pass
		-- rather than a product because a pass can only be bought once, which is
		-- what "one-time" has to mean when real money is involved.
		StarterPack = 1986657210,
	},
	Products = {
		CashSmall = 0,
		CashLarge = 0,
		UnitBoost = 0,
		GemPack = 0,
	},
}

return settings
