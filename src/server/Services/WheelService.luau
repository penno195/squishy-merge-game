--!strict
-- The prize wheel: one free spin a day, extra spins bought with gems. Prizes
-- are ordinary reward bundles, so RewardService grants them with no special
-- cases and the wheel can be re-themed by editing Balance alone.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ActionService = require(script.Parent.ActionService)
local Config = require(ReplicatedStorage.Shared.Config)
local DataService = require(script.Parent.DataService)
local Economy = require(ReplicatedStorage.Shared.Economy)
local Net = require(ReplicatedStorage.Shared.Net)
local RewardService = require(script.Parent.RewardService)
local StateService = require(script.Parent.StateService)
local Types = require(ReplicatedStorage.Shared.Types)

local Wheel = Config.Balance.Wheel

local WheelService = {}

-- Spends a spin: the free daily one first, then any bought. Returns false when
-- there's nothing to spend.
local function takeSpin(data: Types.PlayerData, now: number): boolean
	if Economy.freeSpinAvailable(data, now) then
		data.LastFreeSpinDay = Economy.currentDay(now)
		return true
	end
	if data.Spins > 0 then
		data.Spins -= 1
		return true
	end
	return false
end

local function spin(player: Player)
	local data = DataService.get(player)
	if not data then
		return
	end
	if not takeSpin(data, os.time()) then
		StateService.notify(player, `No spins left! One is free each day, or {Economy.spinCost()} Gems.`, "Error")
		return
	end

	local index = Economy.rollPrize()
	local prize = Wheel.Prizes[index]
	local description, granted = RewardService.grant(player, prize.Reward)
	StateService.markDirty(player)
	ActionService.fire(player, "WheelSpun", {
		Value = index,
		Cash = granted.Cash,
		Gems = granted.Gems,
		Fields = { Prize = prize.Label },
	})
	-- The client animates the wheel to this segment and then announces it, so
	-- no toast here: it would spoil the result before the wheel stops.
	Net.event("SpinResult"):FireClient(player, index, description)
end

local function buySpin(player: Player)
	local data = DataService.get(player)
	if not data then
		return
	end
	local cost = Economy.spinCost()
	if data.Gems < cost then
		StateService.notify(player, `You need {cost} Gems for another spin!`, "Error")
		return
	end
	data.Gems -= cost
	data.Spins += 1
	StateService.markDirty(player)
	ActionService.fire(player, "SpinBought", { Value = data.Spins, GemsSpent = cost })
end

function WheelService.init()
	Net.event("Spin").OnServerEvent:Connect(spin)
	Net.event("BuySpin").OnServerEvent:Connect(buySpin)

	StateService.addProvider(function(player, snapshot)
		local data = DataService.get(player)
		if data then
			snapshot.SpinsAvailable = Economy.spinsAvailable(data, os.time())
		end
	end)
end

return WheelService
