--!strict
-- The crafting station in the hub. Players carry ordinary units to it, load up
-- to Balance.Craft.Slots of them in, and start a craft that runs for hours in
-- real time -- including while they're offline, which is the point of it.
--
-- What comes out is rolled here, from the odds in Economy.craftOutcomes: the
-- same pure function the panel shows the player, so what's on screen while the
-- clock runs is exactly what the server rolls at the end of it.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local DataService = require(script.Parent.DataService)
local Economy = require(ReplicatedStorage.Shared.Economy)
local Format = require(ReplicatedStorage.Shared.Format)
local HubService = require(script.Parent.HubService)
local ItemService = require(script.Parent.ItemService)
local Net = require(ReplicatedStorage.Shared.Net)
local PlinthService = require(script.Parent.PlinthService)
local StateService = require(script.Parent.StateService)

local Craft = Config.Balance.Craft
local Theme = Config.Theme

-- How often finished crafts are looked for. Only a toast rides on this: the
-- panel and the machine's own screen count down on the client.
local ANNOUNCE_SECONDS = 5
local READY_MESSAGE = `Your {Theme.Text.Machine} has finished! Collect what's inside.`

local CraftService = {}

-- Players already told their craft is done, so the toast lands once rather
-- than every time the loop comes round.
local announced: { [Player]: boolean } = {}

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

-- Feeding it. The unit has to be carried here in person: that walk is the
-- machine's whole reason for standing in the middle of the map.
local function add(player: Player)
	local data = DataService.get(player)
	if not data then
		return
	end
	if Economy.craftRunning(data) then
		StateService.notify(player, `The {Theme.Text.Machine} is already running.`, "Error")
		return
	end
	if #data.Craft.Inputs >= Craft.Slots then
		StateService.notify(player, `The {Theme.Text.Machine} is full -- start it!`, "Error")
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
	table.insert(data.Craft.Inputs, tier)
	StateService.markDirty(player)
end

-- Second thoughts. Whatever fits goes back in the garden; anything that
-- doesn't stays in the machine rather than vanishing.
local function takeBack(player: Player)
	local data = DataService.get(player)
	if not data or Economy.craftRunning(data) then
		return
	end
	local left: { number } = {}
	for _, tier in data.Craft.Inputs do
		if not (Economy.hasRoom(data) and ItemService.dropItem(player, tier, nil, false)) then
			table.insert(left, tier)
		end
	end
	data.Craft.Inputs = left
	if #left > 0 then
		StateService.notify(player, "Your garden is full, so the rest stayed in the machine.", "Error")
	end
	StateService.markDirty(player)
end

local function start(player: Player)
	local data = DataService.get(player)
	if not data or Economy.craftRunning(data) or #data.Craft.Inputs == 0 then
		return
	end
	data.Craft.EndsAt = os.time() + Economy.craftSeconds()
	announced[player] = nil
	StateService.markDirty(player)
	StateService.notify(
		player,
		`{Theme.Text.Machine} started -- back in {Format.time(Economy.craftSeconds())}.`,
		"Reward"
	)
end

local function skip(player: Player)
	local data = DataService.get(player)
	if not data or not Economy.craftRunning(data) then
		return
	end
	local now = os.time()
	if Economy.craftRemaining(data, now) <= 0 then
		return
	end
	local cost = Economy.craftSkipCost(data, now)
	if data.Gems < cost then
		StateService.notify(player, `You need {cost} Gems to finish that now!`, "Error")
		return
	end
	data.Gems -= cost
	data.Craft.EndsAt = now
	StateService.markDirty(player)
end

local function collect(player: Player)
	local data = DataService.get(player)
	if not data or not Economy.craftReady(data, os.time()) then
		return
	end
	-- Checked before the roll, so a full garden costs the player nothing: the
	-- craft simply stays finished until there's somewhere to put the result.
	if not Economy.hasRoom(data) then
		StateService.notify(player, "Your garden is full -- make room, then collect!", "Error")
		return
	end

	local index = Economy.rollCraft(data.Craft.Inputs)
	if index == 0 or not ItemService.dropItem(player, index, nil, true) then
		return
	end
	data.Craft.Inputs = {}
	data.Craft.EndsAt = 0
	announced[player] = nil

	local sparkle = Economy.sparkleAt(index)
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
		StateService.notify(player, `The {Theme.Text.Machine} made you a {Config.Units[index].Name}.`, "Reward")
	end
	StateService.markDirty(player)
	Net.event("CraftResult"):FireClient(player, index, sparkle ~= nil)
end

-- Tells a player their craft is done once, whether it finished while they were
-- stood there or overnight.
function CraftService.addPlayer(player: Player)
	local data = DataService.get(player)
	if data and Economy.craftReady(data, os.time()) then
		StateService.notify(player, READY_MESSAGE, "Offline")
		announced[player] = true
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

	-- The clock the client counts down to. Sent as game time, like the drop
	-- timer, so it doesn't rely on the player's own clock being right.
	StateService.addProvider(function(player, snapshot)
		local data = DataService.get(player)
		if not data then
			return
		end
		local now = os.time()
		snapshot.CraftReadyAt = Workspace:GetServerTimeNow() + Economy.craftRemaining(data, now)
		snapshot.CraftSkipCost = Economy.craftSkipCost(data, now)
	end)

	task.spawn(function()
		while true do
			task.wait(ANNOUNCE_SECONDS)
			local now = os.time()
			for _, player in Players:GetPlayers() do
				local data = DataService.get(player)
				if data and not announced[player] and Economy.craftReady(data, now) then
					announced[player] = true
					StateService.notify(player, READY_MESSAGE, "Reward")
				end
			end
		end
	end)
end

return CraftService
