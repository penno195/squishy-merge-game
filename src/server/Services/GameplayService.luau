--!strict
-- The core loop: timed drops from the sky, per-second income from items lying
-- in the garden, run-over pickup and merging, and auto merge -- the pass, or
-- the gem-bought clock.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local ActionService = require(script.Parent.ActionService)
local Config = require(ReplicatedStorage.Shared.Config)
local DataService = require(script.Parent.DataService)
local Economy = require(ReplicatedStorage.Shared.Economy)
local EventService = require(script.Parent.EventService)
local Format = require(ReplicatedStorage.Shared.Format)
local GardenService = require(script.Parent.GardenService)
local ItemService = require(script.Parent.ItemService)
local Net = require(ReplicatedStorage.Shared.Net)
local PassService = require(script.Parent.PassService)
local PetService = require(script.Parent.PetService)
local PlinthService = require(script.Parent.PlinthService)
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
			Net.event("SellPrompt")
				:FireClient(player, data.Carried, Economy.binValue(data.Carried, PetService.perk(player, "SellBonus")))
		elseif playerTimers.sellPrompt and (not onBin or data.Carried == 0) then
			playerTimers.sellPrompt = false
			Net.event("SellPrompt"):FireClient(player)
		end
		playerTimers.onBin = onBin
	end
end

-- Room beyond what the Garden Space upgrade gives: the Bigger Garden pass plus a
-- Gardener pet. Both are the same kind of thing to Economy, which only wants a
-- number, so they are added here rather than threaded separately.
local function spacesFor(player: Player): number
	return PassService.extraGardenSpaces(player) + PetService.extraSpaces(player)
end

-- How fast drops come: the pass, sped up again by a Fast Drops event.
local function dropSpeed(player: Player): number
	return PassService.spawnMultiplier(player) / EventService.strength("FastDrops")
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
	if now >= playerTimers.nextDrop and Economy.hasRoom(data, spacesFor(player)) then
		-- Every source of luck at once -- the charm, the pass, a Charmed pet and
		-- whatever event staff have running.
		local bias = Economy.totalLuckBias(data, os.time(), PassService.has(player, "LuckCharm"))
			+ Economy.eventLuckBias(EventService.strength("DropLuck"))
		local tier = Economy.randomDropIndex(data, bias, EventService.strength("VariantLuck"))
		if ItemService.dropItem(player, tier, nil, true) then
			local wait = Economy.randomDropInterval(data, dropSpeed(player))
			playerTimers.nextDrop = now + wait
			playerTimers.dropInterval = wait
			ActionService.fire(player, "Dropped", { Value = tier, Fields = { Source = "Sky" } })
		end
	end

	local autoMerging = PassService.has(player, "AutoMerge") or Economy.autoMergeRemaining(data) > 0
	if now >= playerTimers.nextAutoMerge and autoMerging then
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
	local wait = Economy.randomDropInterval(data, dropSpeed(player))
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
		local wait = Economy.randomDropInterval(data, dropSpeed(player))
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
			local amount = Economy.binValue(tier, PetService.perk(player, "SellBonus"))
			RewardService.grantCash(player, amount)
			StateService.notify(
				player,
				`{Config.Units[tier].Name} sold for {Format.number(amount)} {Theme.Text.Currency}.`,
				"Reward"
			)
			ActionService.fire(player, "Sold", { Value = tier, Cash = amount })
		end
		playerTimers.sellPrompt = false
		Net.event("SellPrompt"):FireClient(player)
	end)

	-- A sparkle carried onto a plinth: the trophy, and the permanent bonus with
	-- it. Anywhere on the plot will do -- the plinths stand outside the fence
	-- where nothing can be carried, so asking the player to stand at one would
	-- be asking for something the garden does not allow.
	Net.event("SendToPlinth").OnServerEvent:Connect(function(player)
		local data = DataService.get(player)
		if not data or data.Carried == 0 then
			return
		end
		if not Economy.isSparkle(data.Carried) then
			StateService.notify(player, `Only {Theme.Text.SparklePlural} go on a plinth.`, "Error")
			return
		end
		local index = ItemService.takeCarried(player)
		if not index then
			return
		end
		local first, owned = PlinthService.award(player, index)
		local sparkle = Economy.sparkleAt(index)
		StateService.notify(
			player,
			if first and sparkle
				then `{sparkle.Name} on its plinth: +{math.floor(sparkle.Bonus * 100)}% {Theme.Text.Currency} for good.`
				else `Your plinth now shows {owned}.`,
			"Discovery"
		)
		ActionService.fire(player, "SparkleBanked", { Value = index, Fields = { Owned = tostring(owned) } })
	end)

	Net.event("BuyUnit").OnServerEvent:Connect(function(player)
		local data = DataService.get(player)
		if not data then
			return
		end
		local cost = Economy.buyUnitCost(data)
		if data.Cash < cost then
			StateService.notify(player, `Not enough {Theme.Text.Currency}!`, "Error")
		elseif not Economy.hasRoom(data, spacesFor(player)) then
			StateService.notify(player, "Your garden is full. Merge to make room!", "Error")
		else
			data.Cash -= cost
			data.UnitsBought += 1
			local tier = Economy.dropTier(data)
			ItemService.dropItem(player, tier, nil, true)
			ActionService.fire(player, "Dropped", { Value = tier, CashSpent = cost, Fields = { Source = "Bought" } })
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
