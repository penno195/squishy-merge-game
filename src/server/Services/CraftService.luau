--!strict
-- The crafting station in the hub. Players carry ordinary units to it, load up
-- to Balance.Craft.Inputs of them into a slot, and start a craft that runs for
-- hours in real time -- including while they're offline, which is the point of
-- it.
--
-- A player has Economy.craftSlots of those slots: one, or two with the pass.
-- Every message from the client therefore names the slot it means, and every
-- handler here re-derives how many that player is allowed rather than trusting
-- the number sent -- a client asking to load slot 2 without the pass is exactly
-- the request this has to refuse.
--
-- What comes out is rolled here, from the odds in Economy.craftOutcomes: the
-- same pure function the panel shows the player, so what's on screen while the
-- clock runs is exactly what the server rolls at the end of it.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local ActionService = require(script.Parent.ActionService)
local Config = require(ReplicatedStorage.Shared.Config)
local DataService = require(script.Parent.DataService)
local Economy = require(ReplicatedStorage.Shared.Economy)
local Format = require(ReplicatedStorage.Shared.Format)
local HubService = require(script.Parent.HubService)
local ItemService = require(script.Parent.ItemService)
local Net = require(ReplicatedStorage.Shared.Net)
local PassService = require(script.Parent.PassService)
local PetService = require(script.Parent.PetService)
local PlinthService = require(script.Parent.PlinthService)
local StateService = require(script.Parent.StateService)
local Types = require(ReplicatedStorage.Shared.Types)

local Craft = Config.Balance.Craft
local Theme = Config.Theme

-- How often finished crafts are looked for. Only a toast rides on this: the
-- panel and the machine's own screen count down on the client.
local ANNOUNCE_SECONDS = 5

local CraftService = {}

-- Players already told a craft is done, per slot, so the toast lands once rather
-- than every time the loop comes round.
local announced: { [Player]: { [number]: boolean } } = {}

local function announcedFor(player: Player): { [number]: boolean }
	local flags = announced[player]
	if not flags then
		flags = {}
		announced[player] = flags
	end
	return flags
end

-- One slot reads as "the machine"; two are worth naming, because "your craft is
-- done" is no use to someone with two of them running.
local function readyMessage(player: Player, slot: number): string
	if PassService.craftSlots(player) <= 1 then
		return `Your {Theme.Text.Machine} has finished! Collect what's inside.`
	end
	return `Slot {slot} of your {Theme.Text.Machine} has finished! Collect what's inside.`
end

-- Room beyond what the Garden Space upgrade gives: the Bigger Garden pass plus a
-- Gardener pet. Both are the same kind of thing to Economy, which only wants a
-- number, so they are added here rather than threaded separately.
local function spacesFor(player: Player): number
	return PassService.extraGardenSpaces(player) + PetService.extraSpaces(player)
end

local function atMachine(player: Player): boolean
	local position = HubService.machinePosition()
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not (position and root and root:IsA("BasePart")) then
		return false
	end
	local delta = position - root.Position
	return Vector2.new(delta.X, delta.Z).Magnitude <= Craft.Radius
end

-- The craft a client's message is about, or nil if it named a slot this player
-- has no business touching. `slot` arrives over a remote, so it is whatever the
-- client felt like sending: a fraction, a string and a slot bought by somebody
-- else all have to come out of here as nil.
local function slotFor(player: Player, slot: unknown): (Types.PlayerData?, Types.CraftState?, number)
	local data = DataService.get(player)
	if not data then
		return nil, nil, 0
	end
	if typeof(slot) ~= "number" then
		return nil, nil, 0
	end
	local index = slot :: number
	if index % 1 ~= 0 or index < 1 or index > PassService.craftSlots(player) then
		return nil, nil, 0
	end
	return data, Economy.craftAt(data, index), index
end

-- Feeding it. The unit has to be carried here in person: that walk is the
-- machine's whole reason for standing in the middle of the map.
local function add(player: Player, slot: unknown)
	local data, craft = slotFor(player, slot)
	if not (data and craft) then
		return
	end
	if Economy.craftRunning(craft) then
		StateService.notify(player, `That slot is already running.`, "Error")
		return
	end
	if #craft.Inputs >= Economy.craftInputs() then
		StateService.notify(player, `That slot is full -- start it!`, "Error")
		return
	end
	if data.Carried == 0 then
		StateService.notify(player, `Pick a {Theme.Text.Unit} up and bring it over.`, "Error")
		return
	end
	if Economy.isSparkle(data.Carried) then
		StateService.notify(player, `{Theme.Text.SparklePlural} can't go in the {Theme.Text.Machine}.`, "Error")
		return
	end
	if not atMachine(player) then
		StateService.notify(player, `Stand at the {Theme.Text.Machine} to load it.`, "Error")
		return
	end

	local tier = ItemService.takeCarried(player)
	if not tier then
		return
	end
	table.insert(craft.Inputs, tier)
	StateService.markDirty(player)
end

-- Second thoughts. Whatever fits goes back in the garden; anything that
-- doesn't stays in the machine rather than vanishing.
local function takeBack(player: Player, slot: unknown)
	local data, craft = slotFor(player, slot)
	if not (data and craft) or Economy.craftRunning(craft) then
		return
	end
	local spaces = spacesFor(player)
	local left: { number } = {}
	for _, tier in craft.Inputs do
		if not (Economy.hasRoom(data, spaces) and ItemService.dropItem(player, tier, nil, false)) then
			table.insert(left, tier)
		end
	end
	craft.Inputs = left
	if #left > 0 then
		StateService.notify(player, "Your garden is full, so the rest stayed in the machine.", "Error")
	end
	StateService.markDirty(player)
end

local function start(player: Player, slot: unknown)
	local data, craft, index = slotFor(player, slot)
	if not (data and craft) or Economy.craftRunning(craft) or #craft.Inputs == 0 then
		return
	end
	craft.EndsAt = os.time() + Economy.craftSeconds()
	announcedFor(player)[index] = nil
	StateService.markDirty(player)
	StateService.notify(
		player,
		`{Theme.Text.Machine} started -- back in {Format.time(Economy.craftSeconds())}.`,
		"Reward"
	)
	ActionService.fire(player, "CraftStarted", {
		Value = #craft.Inputs,
		Fields = { Best = tostring(Economy.craftSparkleIndex(craft.Inputs)), Slot = tostring(index) },
	})
end

local function skip(player: Player, slot: unknown)
	local data, craft = slotFor(player, slot)
	if not (data and craft) or not Economy.craftRunning(craft) then
		return
	end
	local now = os.time()
	if Economy.craftRemaining(craft, now) <= 0 then
		return
	end
	local cost = Economy.craftSkipCost(craft, now)
	if data.Gems < cost then
		StateService.notify(player, `You need {cost} Gems to finish that now!`, "Error")
		return
	end
	data.Gems -= cost
	craft.EndsAt = now
	StateService.markDirty(player)
	ActionService.fire(player, "CraftSkipped", { Value = cost, GemsSpent = cost })
end

local function collect(player: Player, slot: unknown)
	local data, craft, index = slotFor(player, slot)
	if not (data and craft) or not Economy.craftReady(craft, os.time()) then
		return
	end
	-- Checked before the roll, so a full garden costs the player nothing: the
	-- craft simply stays finished until there's somewhere to put the result.
	if not Economy.hasRoom(data, spacesFor(player)) then
		StateService.notify(player, "Your garden is full -- make room, then collect!", "Error")
		return
	end

	-- The pet is read at the moment of collection rather than when the craft was
	-- started, which is deliberate: a Lucky Crafter is a pet you put on to open the
	-- machine, and rewarding the swap is the point of having an inventory.
	local unitIndex = Economy.rollCraft(craft.Inputs, PetService.perk(player, "CraftLuck"))
	if unitIndex == 0 or not ItemService.dropItem(player, unitIndex, nil, true) then
		return
	end
	craft.Inputs = {}
	craft.EndsAt = 0
	announcedFor(player)[index] = nil

	local sparkle = Economy.sparkleAt(unitIndex)
	if sparkle then
		local first = not Economy.hasSparkle(data, sparkle.Id)
		data.Sparkles[sparkle.Id] = (data.Sparkles[sparkle.Id] or 0) + 1
		-- The bonus is the plinth's, so it lands once: a second copy is still a
		-- very good unit, but it doesn't pay twice.
		StateService.notify(
			player,
			if first
				then `{sparkle.Name}! +{math.floor(sparkle.Bonus * 100)}% {Theme.Text.Currency} for good, and it's on your plinth.`
				else `Another {sparkle.Name}! Your plinth now shows {data.Sparkles[sparkle.Id]}.`,
			"Discovery"
		)
		PlinthService.refresh(player)
	else
		StateService.notify(player, `The {Theme.Text.Machine} made you a {Config.Units[unitIndex].Name}.`, "Reward")
	end
	StateService.markDirty(player)
	Net.event("CraftResult"):FireClient(player, unitIndex, sparkle ~= nil)
	ActionService.fire(player, "CraftCollected", {
		Value = unitIndex,
		Fields = { Made = Config.Units[unitIndex].Name, Sparkle = if sparkle then "yes" else "no" },
	})
end

-- Tells a player a craft is done once, whether it finished while they were stood
-- there or overnight. Only the first waiting slot is announced: two toasts on
-- top of each other say less than one, and the panel shows both anyway.
function CraftService.addPlayer(player: Player)
	local data = DataService.get(player)
	if not data then
		return
	end
	local slot = Economy.readyCraftSlot(data, os.time(), PassService.craftSlots(player))
	if slot then
		StateService.notify(player, readyMessage(player, slot), "Offline")
		announcedFor(player)[slot] = true
	end
end

function CraftService.init()
	Net.event("CraftAdd").OnServerEvent:Connect(add)
	Net.event("CraftTakeBack").OnServerEvent:Connect(takeBack)
	Net.event("CraftStart").OnServerEvent:Connect(start)
	Net.event("CraftSkip").OnServerEvent:Connect(skip)
	Net.event("CraftCollect").OnServerEvent:Connect(collect)

	Players.PlayerRemoving:Connect(function(player)
		announced[player] = nil
	end)

	-- The clocks the client counts down to, one per slot. Sent as game time, like
	-- the drop timer, so they don't rely on the player's own clock being right.
	-- `CraftSlots` is here too, because how many the player has is the server's
	-- answer to give -- the panel draws its selector from it rather than from
	-- what it thinks the pass list means.
	StateService.addProvider(function(player, snapshot)
		local data = DataService.get(player)
		if not data then
			return
		end
		local now = os.time()
		local gameNow = Workspace:GetServerTimeNow()
		local slots = PassService.craftSlots(player)
		local readyAt: { number } = {}
		local skipCost: { number } = {}
		for slot = 1, slots do
			local craft = Economy.craftAt(data, slot)
			if craft then
				readyAt[slot] = gameNow + Economy.craftRemaining(craft, now)
				skipCost[slot] = Economy.craftSkipCost(craft, now)
			end
		end
		snapshot.CraftSlots = slots
		snapshot.CraftReadyAt = readyAt
		snapshot.CraftSkipCost = skipCost
	end)

	task.spawn(function()
		while true do
			task.wait(ANNOUNCE_SECONDS)
			local now = os.time()
			for _, player in Players:GetPlayers() do
				local data = DataService.get(player)
				if data then
					local flags = announcedFor(player)
					local slots = PassService.craftSlots(player)
					for slot = 1, slots do
						local craft = Economy.craftAt(data, slot)
						if craft and not flags[slot] and Economy.craftReady(craft, now) then
							flags[slot] = true
							StateService.notify(player, readyMessage(player, slot), "Reward")
						end
					end
				end
			end
		end
	end)
end

return CraftService
