--!strict
-- Global leaderboards (OrderedDataStores, refreshed periodically and broadcast
-- to clients) plus the in-game player list's leaderstats.
--
-- Two of the boards rank lifetime totals and never reset -- a hall of fame. The
-- third is the weekly race, which pays out: it ranks what each player has earned
-- since their week turned over, and it's the one a prize can sensibly hang off,
-- because the lifetime boards reward seniority and nobody new can climb them.
--
-- The weekly board lives in an OrderedDataStore *named for its week*, so there
-- is no reset to perform and last week's standings are still there to be paid
-- out on while this week's race is already running. Rolling over is a rename.

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ActionService = require(script.Parent.ActionService)
local Config = require(ReplicatedStorage.Shared.Config)
local DataService = require(script.Parent.DataService)
local Economy = require(ReplicatedStorage.Shared.Economy)
local Format = require(ReplicatedStorage.Shared.Format)
local HubService = require(script.Parent.HubService)
local Net = require(ReplicatedStorage.Shared.Net)
local RewardService = require(script.Parent.RewardService)
local StateService = require(script.Parent.StateService)

local Theme = Config.Theme
local LeaderboardBalance = Config.Balance.Leaderboard

-- PlayerData fields ranked on global boards.
local BOARDS = { "TotalEarned", "Rebirths" }
-- The board standing in the hub ranks one of them and badges the other. Both
-- are still stored and still shown in full in the panel.
local BOARD_STAT = "TotalEarned"
local BADGE_STAT = "Rebirths"
-- OrderedDataStore values must be integers.
local MAX_STORED_VALUE = 2 ^ 53

-- The weekly race rides alongside the lifetime boards in the same broadcast, so
-- the panel renders three columns out of one message.
local WEEKLY_BOARD = "Weekly"

type Entry = { Name: string, Value: number, UserId: number }

local LeaderboardService = {}

local stores: { [string]: OrderedDataStore } = {}
local latest: { [string]: { Entry } } = {}
local nameCache: { [number]: string } = {}
local leaderstats: { [Player]: { Cash: StringValue, Rebirths: IntValue } } = {}

-- Last week's finishing order, read once and kept: it's what every payout in
-- this server is judged against, and it cannot change. `standingsWeek` is the
-- week it belongs to, and -1 means it hasn't been read yet -- which is not the
-- same as "nobody placed", so a player is told nothing rather than told no.
local standings: { Entry } = {}
local standingsWeek = -1

local function getName(userId: number): string
	local cached = nameCache[userId]
	if cached then
		return cached
	end
	local ok, name = pcall(Players.GetNameFromUserIdAsync, Players, userId)
	local resolved = if ok then name else "Unknown"
	nameCache[userId] = resolved
	return resolved
end

local function weekStore(week: number): OrderedDataStore?
	local ok, store = pcall(
		DataStoreService.GetOrderedDataStore,
		DataStoreService,
		`{Config.Settings.LeaderboardPrefix}_{WEEKLY_BOARD}_{week}`
	)
	return if ok then store else nil
end

-- The top page of a week's board, ranked. One page covers every place that
-- pays, since Prizes is far shorter than Size.
local function readWeek(week: number): { Entry }
	local store = weekStore(week)
	if not store then
		return {}
	end
	local ok, pages = pcall(store.GetSortedAsync, store, false, LeaderboardBalance.Size)
	if not ok then
		return {}
	end
	local entries: { Entry } = {}
	for _, item in pages:GetCurrentPage() do
		local userId = tonumber(item.key)
		if userId then
			table.insert(entries, { Name = getName(userId), Value = item.value, UserId = userId })
		end
	end
	return entries
end

-- Where this player finished last week, or 0 for "not on the board at all".
local function placeOf(player: Player): number
	for rank, entry in standings do
		if entry.UserId == player.UserId then
			return rank
		end
	end
	return 0
end

-- Starts this player's week if it hasn't been started, capturing where their
-- earnings stood. Called on join and again whenever the board refreshes, which
-- is what carries a session across a Monday without a timer of its own.
local function rollOver(player: Player)
	local data = DataService.get(player)
	if not data then
		return
	end
	local thisWeek = Economy.currentWeek(os.time())
	if data.Weekly.Week ~= thisWeek then
		data.Weekly.Week = thisWeek
		data.Weekly.Base = data.TotalEarned
		StateService.markDirty(player)
	end
end

-- 1st, 2nd, 3rd, 4th. Teens are all "th", which is the case a naive lookup on
-- the last digit gets wrong.
local SUFFIXES = { "st", "nd", "rd" }

local function ordinal(rank: number): string
	local suffix = if rank % 100 >= 11 and rank % 100 <= 13 then "th" else SUFFIXES[rank % 10] or "th"
	return `{rank}{suffix}`
end

-- Pushes the latest rankings onto the board standing in the hub. Separate from
-- the broadcast, so it can also run at startup before the first refresh has had
-- anything to rank.
--
-- The badge is read off the other board rather than from live data, so it only
-- appears for players who rank on both. The two correlate closely enough that
-- that's almost always, and a missing badge reads as "no rebirths yet" rather
-- than as a bug.
local function refreshBoard()
	local badges: { [number]: number } = {}
	local badgeEntries: { Entry } = latest[BADGE_STAT] or {}
	for _, entry in badgeEntries do
		badges[entry.UserId] = entry.Value
	end

	local rows: { { Name: string, Value: string, Badge: string } } = {}
	local rowLimit = Config.Balance.Leaderboard.BoardRows
	local ranked: { Entry } = latest[BOARD_STAT] or {}
	for rank, entry in ranked do
		if rank > rowLimit then
			break
		end
		local rebirths = badges[entry.UserId] or 0
		table.insert(rows, {
			Name = entry.Name,
			Value = Format.number(entry.Value),
			Badge = if rebirths > 0 then `⭐{rebirths}` else "",
		})
	end
	HubService.setLeaderboard(BOARD_STAT, rows)
end

local function refresh()
	local now = os.time()
	local thisWeek = Economy.currentWeek(now)
	local weekly = weekStore(thisWeek)

	for _, player in Players:GetPlayers() do
		-- Before anything is written: a session that ran across a Monday has a
		-- base belonging to last week, and posting against it would put the
		-- whole of last week's earnings on top of this week's board.
		rollOver(player)
		local data = DataService.get(player)
		if data then
			for stat, store in stores do
				local value = math.min(math.floor((data :: any)[stat]), MAX_STORED_VALUE)
				pcall(store.SetAsync, store, tostring(player.UserId), value)
			end
			if weekly then
				local earned = math.min(math.floor(Economy.weeklyEarned(data, now)), MAX_STORED_VALUE)
				pcall(weekly.SetAsync, weekly, tostring(player.UserId), earned)
			end
		end
	end

	-- Last week's standings are what payouts are judged against, so they're
	-- re-read when the week turns rather than only at startup -- a server that
	-- has been up since before the weekend would otherwise pay out on a week
	-- that is now two weeks old.
	if standingsWeek ~= thisWeek - 1 then
		standings = readWeek(thisWeek - 1)
		standingsWeek = thisWeek - 1
		for _, player in Players:GetPlayers() do
			StateService.markDirty(player)
		end
	end
	if weekly then
		latest[WEEKLY_BOARD] = readWeek(thisWeek)
	end

	for stat, store in stores do
		local ok, pages = pcall(store.GetSortedAsync, store, false, LeaderboardBalance.Size)
		if ok then
			local entries = {}
			for _, item in pages:GetCurrentPage() do
				local userId = tonumber(item.key)
				if userId then
					table.insert(entries, { Name = getName(userId), Value = item.value, UserId = userId })
				end
			end
			latest[stat] = entries
		end
	end

	Net.event("Leaderboard"):FireAllClients(latest)
	refreshBoard()
end

-- Last week's prize, claimed rather than granted on sight. A player who won one
-- while they were offline should be told they won it, and a line of gems
-- appearing in the corner is not being told.
local function claimPrize(player: Player)
	local data = DataService.get(player)
	if not data then
		return
	end
	-- Nothing has been read yet: say so rather than telling a winner they lost.
	if standingsWeek < 0 then
		StateService.notify(player, "Last week's results aren't in yet. Try again in a moment.", "Error")
		return
	end
	if not Economy.prizeUnclaimed(data, standingsWeek) then
		StateService.notify(player, "You've already claimed that one.", "Error")
		return
	end

	local rank = placeOf(player)
	local gems = Economy.leaderboardPrize(rank)
	-- Marked paid either way. An unplaced player has nothing owed for that week,
	-- and leaving it unmarked would ask them the same question every refresh.
	data.Weekly.PaidWeek = standingsWeek
	if gems <= 0 then
		StateService.markDirty(player)
		StateService.notify(player, `You didn't place in the top {Economy.prizePlaces()} last week.`, "Info")
		return
	end

	RewardService.grantGems(player, gems)
	StateService.markDirty(player)
	StateService.notify(player, `{ordinal(rank)} place last week — {gems} Gems!`, "Reward")
	ActionService.fire(player, "PrizeClaimed", {
		Value = rank,
		Gems = gems,
		Fields = { Rank = tostring(rank), Week = tostring(standingsWeek) },
	})
end

function LeaderboardService.addPlayer(player: Player)
	local folder = Instance.new("Folder")
	folder.Name = "leaderstats"
	local cash = Instance.new("StringValue")
	cash.Name = Theme.Text.Currency
	cash.Parent = folder
	local rebirths = Instance.new("IntValue")
	rebirths.Name = `{Theme.Text.Rebirth}s`
	rebirths.Parent = folder
	folder.Parent = player
	leaderstats[player] = { Cash = cash, Rebirths = rebirths }

	rollOver(player)
	Net.event("Leaderboard"):FireClient(player, latest)
end

function LeaderboardService.removePlayer(player: Player)
	leaderstats[player] = nil
end

function LeaderboardService.init()
	-- Clients ask again once their UI is up, since the join-time send can beat it.
	Net.event("Ready").OnServerEvent:Connect(function(player)
		Net.event("Leaderboard"):FireClient(player, latest)
	end)

	Net.event("ClaimPrize").OnServerEvent:Connect(claimPrize)

	-- What the panel needs to draw the prize row: where this player finished and
	-- what that is worth. Sent rather than worked out on the client, because the
	-- client has no way to know the finishing order of a week it wasn't here for.
	StateService.addProvider(function(player, snapshot)
		if standingsWeek < 0 then
			return
		end
		local rank = placeOf(player)
		snapshot.PrizeWeek = standingsWeek
		snapshot.PrizeRank = rank
		snapshot.PrizeGems = Economy.leaderboardPrize(rank)
	end)

	-- Says "no one yet" until the first refresh lands, rather than sitting blank.
	refreshBoard()

	for _, stat in BOARDS do
		-- Fails in unpublished places; boards just stay empty there.
		local ok, store =
			pcall(DataStoreService.GetOrderedDataStore, DataStoreService, `{Config.Settings.LeaderboardPrefix}_{stat}`)
		if ok then
			stores[stat] = store
		end
	end

	task.spawn(function()
		while true do
			task.wait(1)
			for player, values in leaderstats do
				local data = DataService.get(player)
				if data then
					values.Cash.Value = Format.number(data.Cash)
					values.Rebirths.Value = data.Rebirths
				end
			end
		end
	end)

	-- Read once up front rather than waiting a full refresh interval for it:
	-- a player who won last week may well be joining in the first minute.
	task.spawn(function()
		local lastWeek = Economy.currentWeek(os.time()) - 1
		standings = readWeek(lastWeek)
		standingsWeek = lastWeek
		for _, player in Players:GetPlayers() do
			StateService.markDirty(player)
		end
	end)

	task.spawn(function()
		while true do
			task.wait(LeaderboardBalance.RefreshSeconds)
			refresh()
		end
	end)
end

return LeaderboardService
