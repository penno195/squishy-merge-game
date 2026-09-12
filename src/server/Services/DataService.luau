--!strict
-- Loads and saves player data with ProfileStore (session-locked, autosaving).
-- Other services read data through DataService.get and hook into the player
-- lifecycle with onLoaded / onReleasing.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Economy = require(ReplicatedStorage.Shared.Economy)
local ProfileStore = require(script.Parent.Parent.Vendor.ProfileStore)
local Types = require(ReplicatedStorage.Shared.Types)

type PlayerData = Types.PlayerData
type Callback = (Player, PlayerData) -> ()

local TEMPLATE: PlayerData = {
	Cash = Config.Balance.StartingCash,
	Gems = 0,
	BoostEndsAt = 0,
	Items = Economy.startingItems(),
	Carried = 0,
	Upgrades = {},
	UnitsBought = 0,
	Rebirths = 0,
	TotalEarned = 0,
	HighestTier = 1,
	LastOnline = 0,
	Daily = { Streak = 0, LastClaimDay = -1 },
	Spins = 0,
	LastFreeSpinDay = -1,
	PurchaseIds = {},
}

local DataService = {}

local store = ProfileStore.New(Config.Settings.DataStoreName, TEMPLATE)
local profiles: { [Player]: any } = {}
local loadedCallbacks: { Callback } = {}
local releasingCallbacks: { Callback } = {}

-- Saves from the original grid build stored a fixed-length `Slots` array and a
-- `PlotSize` upgrade. Carry both across to the garden rather than wiping them.
local function migrateLegacy(data: PlayerData)
	local legacy = data :: any
	if legacy.Slots then
		local migrated = {}
		for _, tier in legacy.Slots do
			if tier > 0 then
				table.insert(migrated, tier)
			end
		end
		data.Items = migrated
		legacy.Slots = nil
	end
	-- Untyped view: clearing a key means writing nil into a map of numbers.
	local upgrades = data.Upgrades :: any
	if upgrades.PlotSize then
		upgrades.GardenSpace = math.max(upgrades.GardenSpace or 0, upgrades.PlotSize)
		upgrades.PlotSize = nil
	end
end

-- The theme can change between versions (fewer tiers), so fit saved data to it.
local function fitToConfig(data: PlayerData)
	for index, tier in data.Items do
		data.Items[index] = math.clamp(tier, 1, Config.MaxTier)
	end
	data.Carried = math.clamp(data.Carried, 0, Config.MaxTier)
	data.HighestTier = math.clamp(data.HighestTier, 1, Config.MaxTier)
end

local function runCallbacks(callbacks: { Callback }, player: Player, data: PlayerData)
	for _, callback in callbacks do
		xpcall(callback, function(err)
			warn(`Player lifecycle callback failed for {player.Name}: {err}`)
		end, player, data)
	end
end

local function onPlayerAdded(player: Player)
	local profile = store:StartSessionAsync(`Player_{player.UserId}`, {
		Cancel = function()
			return player.Parent ~= Players
		end,
	})
	if profile == nil then
		if player.Parent == Players then
			player:Kick("We couldn't load your data. Please rejoin!")
		end
		return
	end

	profile:AddUserId(player.UserId)
	profile:Reconcile()
	profile.OnSessionEnd:Connect(function()
		profiles[player] = nil
		player:Kick("Your data was loaded on another server. Please rejoin!")
	end)

	if player.Parent ~= Players then
		profile:EndSession()
		return
	end

	migrateLegacy(profile.Data)
	fitToConfig(profile.Data)
	profiles[player] = profile
	runCallbacks(loadedCallbacks, player, profile.Data)
end

local function onPlayerRemoving(player: Player)
	local profile = profiles[player]
	if not profile then
		return
	end
	runCallbacks(releasingCallbacks, player, profile.Data)
	profiles[player] = nil
	profile:EndSession()
end

function DataService.get(player: Player): PlayerData?
	local profile = profiles[player]
	return if profile then profile.Data else nil
end

function DataService.getProfile(player: Player): any
	return profiles[player]
end

-- Callbacks run in order on the loading thread and may yield.
function DataService.onLoaded(callback: Callback)
	table.insert(loadedCallbacks, callback)
end

-- Runs before the profile is saved and released.
function DataService.onReleasing(callback: Callback)
	table.insert(releasingCallbacks, callback)
end

function DataService.start()
	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(onPlayerRemoving)
	for _, player in Players:GetPlayers() do
		task.spawn(onPlayerAdded, player)
	end
end

return DataService
