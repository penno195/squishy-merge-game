--!strict
-- The core loop: timed drops from the sky, per-second income from items lying
-- in the garden, run-over pickup and merging, and the auto-merge gamepass.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local DataService = require(script.Parent.DataService)
local Economy = require(ReplicatedStorage.Shared.Economy)
local Format = require(ReplicatedStorage.Shared.Format)
local GardenService = require(script.Parent.GardenService)
local ItemService = require(script.Parent.ItemService)
local Net = require(ReplicatedStorage.Shared.Net)
local PassService = require(script.Parent.PassService)
local RewardService = require(script.Parent.RewardService)
local StateService = require(script.Parent.StateService)

local Theme = Config.Theme

type Item = ItemService.Item

type Timers = {
	nextIncome: number,
	nextDrop: number,
	-- The randomised wait currently being counted down, so the HUD bar can
	-- show real progress rather than the average.
	dropInterval: number,
	nextAutoMerge: number,
	-- Items the player is currently standing in range of. Only items that
	-- weren't here last frame count as being run over.
	touching: { [Item]: boolean },
	-- Whether the player is stood on the bin. Same rule as items: you have to
	-- arrive carrying something, so picking a unit up while already stood on
	-- the bin doesn't instantly ask about throwing it away.
	onBin: boolean,
	-- Whether a sell confirmation is open, so it can be taken back down if the
	-- player wanders off instead of answering.
	sellPrompt: boolean,
}

local GameplayService = {}

local timers: { [Player]: Timers } = {}
local characterConnections: { [Player]: RBXScriptConnection } = {}

-- Run-over detection. Acting on every item in range every frame would chain
-- merges instantly and snatch back anything just put down, so only an item
-- that has newly come into range counts as being run over.
local function checkPickup(player: Player, playerTimers: Timers)
	local data = DataService.get(player)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not (data and root and root:IsA("BasePart") and humanoid and humanoid.Health > 0) then
		return
	end

	local nearby = ItemService.itemsWithin(player, root.Position, Config.Balance.Pickup.Radius)
	local touchingNow: { [Item]: boolean } = {}
	local ranOnto: Item? = nil
	for _, item in nearby do
		touchingNow[item] = true
		if not playerTimers.touching[item] and not ranOnto then
			ranOnto = item
		end
	end

	if ranOnto then
		if data.Carried == 0 then
			ItemService.pickUp(player, ranOnto)
		elseif data.Carried == ranOnto.tier then
			local created = ItemService.mergeWith(player, ranOnto)
			-- The result lands underfoot: treat it as already touched so the
			-- player has to step off and back on to collect it.
			if created then
				touchingNow[created] = true
			end
		end
		-- Carrying something else: left alone, so players can walk past freely.
	end

	playerTimers.touching = touchingNow

	local bin = GardenService.binPosition(player)
	if bin then
		local delta = bin - root.Position
		local onBin = Vector2.new(delta.X, delta.Z).Magnitude <= Config.Balance.Bin.Radius
		if onBin and not playerTimers.onBin and Economy.isSparkle(data.Carried) then
			-- Limited editions, with no way to make that one back: the bin
			-- says no rather than asking.
			StateService.notify(player, `{Theme.Text.SparklePlural} can't be sold.`, "Error")
		elseif onBin and not playerTimers.onBin and data.Carried > 0 then
			-- Ask rather than sell. Selling is destructive and irreversible, and
			-- the bin sits where a player might wander while carrying something
			-- they meant to keep.
			playerTimers.sellPrompt = true
			Net.event("SellPrompt"):FireClient(player, data.Carried, Economy.binValue(data.Carried))
		elseif playerTimers.sellPrompt and (not onBin or data.Carried == 0) then
			playerTimers.sellPrompt = false
			Net.event("SellPrompt"):FireClient(player)
		end
		playerTimers.onBin = onBin
	end
end

local function tick(player: Player, playerTimers: Timers, now: number)
	local data = DataService.get(player)
	if not data then
		return
	end

	if now >= playerTimers.nextIncome then
		-- Catch up after a hitch, but never pay out a burst of missed seconds.
		playerTimers.nextIncome = math.max(playerTimers.nextIncome + 1, now)
		local income = RewardService.incomePerSecond(player)
		data.Cash += income
		data.TotalEarned += income
		data.LastOnline = os.time()
		StateService.markDirty(player)
	end

	-- A full garden leaves the drop "due", so one falls as soon as there's room.
	if now >= playerTimers.nextDrop and Economy.hasRoom(data) then
		if ItemService.dropItem(player, Economy.randomDropTier(data), nil, true) then
			local wait = Economy.randomDropInterval(data, PassService.spawnMultiplier(player))
			playerTimers.nextDrop = now + wait
			playerTimers.dropInterval = wait
		end
	end

	if now >= playerTimers.nextAutoMerge and PassService.has(player, "AutoMerge") then
		playerTimers.nextAutoMerge = now + Config.Balance.Monetisation.AutoMergeInterval
		ItemService.autoMerge(player)
	end

	checkPickup(player, playerTimers)
end

function GameplayService.addPlayer(player: Player)
	local data = DataService.get(player)
	if not data then
		return
	end
	local now = Workspace:GetServerTimeNow()
	local wait = Economy.randomDropInterval(data, PassService.spawnMultiplier(player))
	timers[player] = {
		nextIncome = now + 1,
		nextDrop = now + wait,
		dropInterval = wait,
		nextAutoMerge = now,
		touching = {},
		onBin = false,
		sellPrompt = false,
	}
	-- A carried item dies with the character, so rebuild it on respawn.
	characterConnections[player] = player.CharacterAdded:Connect(function()
		task.defer(ItemService.restoreCarried, player)
	end)
end

function GameplayService.removePlayer(player: Player)
	timers[player] = nil
	local connection = characterConnections[player]
	if connection then
		connection:Disconnect()
		characterConnections[player] = nil
	end
end

-- Restart the drop countdown, e.g. after a rebirth clears the garden.
function GameplayService.resetDropTimer(player: Player)
	local playerTimers = timers[player]
	local data = DataService.get(player)
	if playerTimers and data then
		local wait = Economy.randomDropInterval(data, PassService.spawnMultiplier(player))
		playerTimers.nextDrop = Workspace:GetServerTimeNow() + wait
		playerTimers.dropInterval = wait
	end
end

function GameplayService.init()
	RunService.Heartbeat:Connect(function()
		local now = Workspace:GetServerTimeNow()
		for player, playerTimers in timers do
			tick(player, playerTimers, now)
		end
	end)

	Net.event("DropCarried").OnServerEvent:Connect(function(player)
		local data = DataService.get(player)
		if not data or data.Carried == 0 then
			return
		end
		-- Say why rather than failing silently, so a stuck item is diagnosable.
		local dropped = ItemService.dropCarried(player)
		if not dropped then
			StateService.notify(player, "Couldn't put that down. Are you inside your garden?", "Error")
			return
		end
		-- It lands underfoot, so mark it touched or it's picked straight back up.
		local playerTimers = timers[player]
		if playerTimers then
			playerTimers.touching[dropped] = true
		end
	end)

	-- The answer to the sell confirmation. Everything is re-checked here: the
	-- client can fire this whenever it likes, and the prompt it came from may
	-- be stale by now.
	Net.event("SellCarried").OnServerEvent:Connect(function(player)
		local data = DataService.get(player)
		local playerTimers = timers[player]
		if not (data and playerTimers) or data.Carried == 0 then
			return
		end

		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		local bin = GardenService.binPosition(player)
		if not (root and root:IsA("BasePart") and bin) then
			return
		end
		local delta = bin - root.Position
		if Vector2.new(delta.X, delta.Z).Magnitude > Config.Balance.Bin.Radius then
			StateService.notify(player, `Stand at the {Theme.Text.Bin} to sell.`, "Error")
			return
		end
		if Economy.isSparkle(data.Carried) then
			StateService.notify(player, `{Theme.Text.SparklePlural} can't be sold.`, "Error")
			return
		end

		local tier = ItemService.takeCarried(player)
		if tier then
			local amount = Economy.binValue(tier)
			RewardService.grantCash(player, amount)
			StateService.notify(
				player,
				`{Theme.Units[tier].Name} sold for {Format.number(amount)} {Theme.Text.Currency}.`,
				"Reward"
			)
		end
		playerTimers.sellPrompt = false
		Net.event("SellPrompt"):FireClient(player)
	end)

	Net.event("BuyUnit").OnServerEvent:Connect(function(player)
		local data = DataService.get(player)
		if not data then
			return
		end
		local cost = Economy.buyUnitCost(data)
		if data.Cash < cost then
			StateService.notify(player, `Not enough {Theme.Text.Currency}!`, "Error")
		elseif not Economy.hasRoom(data) then
			StateService.notify(player, "Your garden is full. Merge to make room!", "Error")
		else
			data.Cash -= cost
			data.UnitsBought += 1
			ItemService.dropItem(player, Economy.dropTier(data), nil, true)
		end
	end)

	StateService.addProvider(function(player, snapshot)
		local playerTimers = timers[player]
		local data = DataService.get(player)
		if playerTimers and data then
			snapshot.NextDropAt = playerTimers.nextDrop
			snapshot.DropInterval = playerTimers.dropInterval
			snapshot.IncomePerSecond = RewardService.incomePerSecond(player)
			snapshot.GardenCapacity = Economy.gardenCapacity(data)
		end
	end)
end

return GameplayService
