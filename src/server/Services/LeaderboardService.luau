--!strict
-- Global leaderboards (OrderedDataStores, refreshed periodically and broadcast
-- to clients) plus the in-game player list's leaderstats.

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local DataService = require(script.Parent.DataService)
local Format = require(ReplicatedStorage.Shared.Format)
local HubService = require(script.Parent.HubService)
local Net = require(ReplicatedStorage.Shared.Net)

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

type Entry = { Name: string, Value: number, UserId: number }

local LeaderboardService = {}

local stores: { [string]: OrderedDataStore } = {}
local latest: { [string]: { Entry } } = {}
local nameCache: { [number]: string } = {}
local leaderstats: { [Player]: { Cash: StringValue, Rebirths: IntValue } } = {}

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
	for _, player in Players:GetPlayers() do
		local data = DataService.get(player)
		if data then
			for stat, store in stores do
				local value = math.min(math.floor((data :: any)[stat]), MAX_STORED_VALUE)
				pcall(store.SetAsync, store, tostring(player.UserId), value)
			end
		end
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

	task.spawn(function()
		while true do
			task.wait(LeaderboardBalance.RefreshSeconds)
			refresh()
		end
	end)
end

return LeaderboardService
