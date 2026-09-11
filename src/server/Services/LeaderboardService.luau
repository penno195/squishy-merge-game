--!strict
-- Global leaderboards (OrderedDataStores, refreshed periodically and broadcast
-- to clients) plus the in-game player list's leaderstats.

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local DataService = require(script.Parent.DataService)
local Format = require(ReplicatedStorage.Shared.Format)
local Net = require(ReplicatedStorage.Shared.Net)

local Theme = Config.Theme
local LeaderboardBalance = Config.Balance.Leaderboard

-- PlayerData fields ranked on global boards.
local BOARDS = { "TotalEarned", "Rebirths" }
-- OrderedDataStore values must be integers.
local MAX_STORED_VALUE = 2 ^ 53

type Entry = { Name: string, Value: number }

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
					table.insert(entries, { Name = getName(userId), Value = item.value })
				end
			end
			latest[stat] = entries
		end
	end

	Net.event("Leaderboard"):FireAllClients(latest)
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
