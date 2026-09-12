--!strict
-- Daily login rewards (a 7-day streak that resets if a day is missed) and
-- offline earnings granted on join.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local DataService = require(script.Parent.DataService)
local Economy = require(ReplicatedStorage.Shared.Economy)
local Format = require(ReplicatedStorage.Shared.Format)
local Net = require(ReplicatedStorage.Shared.Net)
local RewardService = require(script.Parent.RewardService)
local StateService = require(script.Parent.StateService)
local Types = require(ReplicatedStorage.Shared.Types)

local Theme = Config.Theme

local DailyService = {}

function DailyService.applyOffline(player: Player, data: Types.PlayerData)
	if data.LastOnline <= 0 then
		return
	end
	local away = os.time() - data.LastOnline
	local amount = Economy.offlineEarnings(RewardService.incomePerSecond(player, 1), away)
	if amount > 0 then
		RewardService.grantCash(player, amount)
		StateService.notify(
			player,
			`While you were away for {Format.time(away)}, your {Theme.Text.UnitPlural} made {Format.number(amount)} {Theme.Text.Currency}!`,
			"Offline"
		)
	end
end

function DailyService.init()
	Net.event("ClaimDaily").OnServerEvent:Connect(function(player)
		local data = DataService.get(player)
		if not data then
			return
		end
		local now = os.time()
		local available, streak = Economy.dailyStatus(data, now)
		if not available then
			StateService.notify(player, "Come back tomorrow for your next reward!", "Error")
			return
		end
		data.Daily.Streak = streak
		data.Daily.LastClaimDay = Economy.currentDay(now)
		local description = RewardService.grant(player, Config.Balance.DailyRewards[streak])
		StateService.notify(player, `Day {streak} reward: {description}!`, "Reward")
		StateService.markDirty(player)
	end)
end

return DailyService
