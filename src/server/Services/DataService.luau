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
	LuckEndsAt = 0,
	Items = Economy.startingItems(),
	Carried = 0,
	Upgrades = {},
	UnitsBought = 0,
	Rebirths = 0,
	TotalEarned = 0,
	HighestTier = 1,
	LastOnline = 0,
	FirstJoin = 0,
	StarterClaimed = false,
	Pets = {},
	EquippedPet = 0,
	Daily = { Streak = 0, LastClaimDay = -1 },
	Spins = 0,
	LastFreeSpinDay = -1,
	PurchaseIds = {},
	-- One craft to start with. migrateLegacy pads this out to however many slots
	-- the balance allows, so the length follows Balance rather than this literal.
	Craft = { { Inputs = {}, EndsAt = 0 } },
	Sparkles = {},
	Discovered = {},
	Stats = {},
	Playtime = 0,
	Codes = {},
	Tutorial = 0,
	Quests = { Day = -1, Week = -1, Active = {} },
	Weekly = { Week = -1, Base = 0, PaidWeek = -1 },
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

	-- `Discovered` arrived with variants, so a save from before it is empty
	-- while the player plainly has discovered things. Fill it in from what was
	-- already recorded, or every unit they own announces itself as new the
	-- first time they log in after the update.
	if next(data.Discovered) == nil then
		for tier = 1, data.HighestTier do
			data.Discovered[tostring(tier)] = true
		end
		for position, sparkle in Config.Sparkles do
			if (data.Sparkles[sparkle.Id] or 0) > 0 then
				data.Discovered[tostring(Economy.sparkleIndex(position))] = true
			end
		end
		for _, index in data.Items do
			data.Discovered[tostring(index)] = true
		end
	end

	-- The machine was one craft, saved as a single { Inputs, EndsAt }. It is a
	-- list of them now, one per slot, so the second-slot pass has somewhere to
	-- put its own load. An old save's craft becomes slot 1 with its clock and
	-- its contents untouched -- a craft left running over the update finishes
	-- on time.
	local craft = data.Craft :: any
	if craft.Inputs then
		data.Craft = { craft }
	end
	-- Kept at full length whatever the player owns, so no slot has to be created
	-- at the moment a pass is bought, and a load parked in a slot whose pass has
	-- lapsed is still sitting there rather than quietly gone.
	for slot = #data.Craft + 1, Economy.maxCraftSlots() do
		data.Craft[slot] = { Inputs = {}, EndsAt = 0 }
	end

	-- What the starter pack's window counts from. A save written before the field
	-- existed has 0 and gets stamped now: there is no way to recover when they
	-- really started, and handing everyone one window when the feature ships is
	-- the better of the two wrong answers.
	if data.FirstJoin <= 0 then
		data.FirstJoin = os.time()
	end
end

-- The theme can change between versions (fewer tiers, fewer sparkles, fewer
-- variants), so fit saved data to it. Items are clamped to the whole unit list
-- rather than the merge ladder, since the sparkles and the variant blocks live
-- on the end of it. Clamping is blunt: shortening the list can land a saved
-- item in a different block than it left in. That's the same trade the theme
-- swap has always made, and the reason DataStoreName is per game.
local function fitToConfig(data: PlayerData)
	local maxUnit = #Config.Units
	for index, tier in data.Items do
		data.Items[index] = math.clamp(tier, 1, maxUnit)
	end
	data.Carried = math.clamp(data.Carried, 0, maxUnit)
	data.HighestTier = math.clamp(data.HighestTier, 1, Config.MaxTier)
	-- The machine takes ordinary units and variants, never sparkles. Anything
	-- that no longer fits the list is clamped, and a sparkle that somehow got
	-- in is dropped rather than clamped into an ordinary unit.
	-- A pet whose Id the theme no longer has is dropped rather than clamped: there
	-- is no nearest pet the way there is a nearest tier, and keeping it would mean
	-- an inventory row naming something that cannot be built or equipped. Same
	-- trade the unit clamping makes, and the same reason DataStoreName is per game.
	local keptPets: { Types.PetRecord } = {}
	local equippedRecord = data.Pets[data.EquippedPet]
	local equipped = 0
	for _, record in data.Pets do
		if Economy.petDef(record.Id) then
			table.insert(keptPets, record)
			if record == equippedRecord then
				equipped = #keptPets
			end
		end
	end
	data.Pets = keptPets
	-- Re-found rather than clamped, so dropping a pet from the middle of the list
	-- doesn't silently equip whichever one slid into its place.
	data.EquippedPet = equipped

	for _, craft in data.Craft do
		local inputs = {}
		for _, index in craft.Inputs do
			local fitted = math.clamp(index, 1, maxUnit)
			if not Economy.isSparkle(fitted) then
				table.insert(inputs, fitted)
			end
		end
		craft.Inputs = inputs
	end
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
