--!strict
-- Income queries and reward granting (cash scaled to income, bonus items).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local DataService = require(script.Parent.DataService)
local Economy = require(ReplicatedStorage.Shared.Economy)
local Format = require(ReplicatedStorage.Shared.Format)
local ItemService = require(script.Parent.ItemService)
local PassService = require(script.Parent.PassService)
local PetService = require(script.Parent.PetService)
local StateService = require(script.Parent.StateService)
local Types = require(ReplicatedStorage.Shared.Types)

local Theme = Config.Theme

-- When a bonus item won't fit, the player gets this many seconds of its income instead.
local FULL_GARDEN_SECONDS = 600

local RewardService = {}

-- `boostMultiplier` overrides the player's timed boost; offline earnings pass
-- 1 so a boost can't be banked against hours of away time.
function RewardService.incomePerSecond(player: Player, boostMultiplier: number?): number
	local data = DataService.get(player)
	if not data then
		return 0
	end
	-- The pass and the equipped pet multiply together. The pet's share is a nudge by
	-- design -- 3% to 15% across the whole rarity ladder -- so this can't run away.
	local multiplier = PassService.cashMultiplier(player) * PetService.cashMultiplier(player)
	return Economy.incomePerSecond(data, multiplier, boostMultiplier)
end

function RewardService.grantGems(player: Player, amount: number)
	local data = DataService.get(player)
	if not data then
		return
	end
	data.Gems += amount
	StateService.markDirty(player)
end

function RewardService.grantCash(player: Player, amount: number)
	local data = DataService.get(player)
	if not data then
		return
	end
	data.Cash += amount
	data.TotalEarned += amount
	StateService.markDirty(player)
end

-- What a bundle actually handed over. The description is for the player; this
-- is for anything that has to act on the amounts -- analytics, and later the
-- quests that count them.
export type Granted = {
	Cash: number,
	Gems: number,
	-- The unit index of a bonus unit, when one fitted in the garden.
	Tier: number?,
}

-- Grants a reward bundle and returns a description like "1.2K Goo + a Mochi",
-- alongside what was handed over.
function RewardService.grant(player: Player, reward: Types.Reward): (string, Granted)
	local granted: Granted = { Cash = 0, Gems = 0 }
	local data = DataService.get(player)
	if not data then
		return "", granted
	end
	local parts = {}

	if reward.IncomeMinutes or reward.MinCash then
		local amount =
			Economy.incomeReward(RewardService.incomePerSecond(player), reward.IncomeMinutes or 0, reward.MinCash or 0)
		RewardService.grantCash(player, amount)
		granted.Cash += amount
		table.insert(parts, `{Format.number(amount)} {Theme.Text.Currency}`)
	end

	if reward.Gems then
		RewardService.grantGems(player, reward.Gems)
		granted.Gems += reward.Gems
		table.insert(parts, `{reward.Gems} Gems`)
	end

	if reward.UnitTierBonus then
		local tier = math.min(Economy.dropTier(data) + reward.UnitTierBonus, Config.MaxTier)
		local spaces = PassService.extraGardenSpaces(player) + PetService.extraSpaces(player)
		if Economy.hasRoom(data, spaces) and ItemService.dropItem(player, tier, nil, true) then
			granted.Tier = tier
			table.insert(parts, `a {Config.Units[tier].Name}`)
		else
			local multiplier =
				Economy.cashMultiplier(data, PassService.cashMultiplier(player) * PetService.cashMultiplier(player))
			local amount = math.floor(Economy.tierIncome(tier) * multiplier * FULL_GARDEN_SECONDS)
			RewardService.grantCash(player, amount)
			granted.Cash += amount
			table.insert(parts, `{Format.number(amount)} {Theme.Text.Currency} (garden full)`)
		end
	end

	return table.concat(parts, " + "), granted
end

return RewardService
