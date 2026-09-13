--!strict
-- Quests: three a day and one a week, handed out per player and measured off
-- the lifetime tallies StatsService already keeps.
--
-- Nothing here counts anything itself. A quest records where its counter stood
-- when it was handed out, and progress is the counter now minus that -- so
-- adding a quest for a verb the game already announces costs a line in
-- Balance and nothing else.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ActionService = require(script.Parent.ActionService)
local Config = require(ReplicatedStorage.Shared.Config)
local DataService = require(script.Parent.DataService)
local Economy = require(ReplicatedStorage.Shared.Economy)
local Net = require(ReplicatedStorage.Shared.Net)
local RewardService = require(script.Parent.RewardService)
local StateService = require(script.Parent.StateService)
local Types = require(ReplicatedStorage.Shared.Types)

local QuestService = {}

-- Seeded per player and per period, so a rejoin brings back the same set rather
-- than rerolling until the player likes it.
local function seedFor(player: Player, period: number, weekly: boolean): number
	return player.UserId % 1000000 * 97 + period * 31 + (if weekly then 7 else 0)
end

local function makeSlot(data: Types.PlayerData, quest: Economy.QuestDef, weekly: boolean): Types.QuestSlot
	return {
		Id = quest.Id,
		-- Where the counter stands right now. Everything past this point counts.
		Base = data.Stats[quest.Stat] or 0,
		Claimed = false,
		Weekly = weekly,
	}
end

-- Hands out a new set when the day or the week has turned over. Dailies and the
-- weekly roll independently, so a weekly in progress survives the daily reset.
function QuestService.refresh(player: Player)
	local data = DataService.get(player)
	if not data then
		return
	end
	local now = os.time()
	local today = Economy.currentDay(now)
	local thisWeek = Economy.currentWeek(now)
	local quests = data.Quests
	if quests.Day == today and quests.Week == thisWeek then
		return
	end

	local kept: { Types.QuestSlot } = {}
	for _, slot in quests.Active do
		-- A weekly outlives the day's reset, and vice versa.
		local stillCurrent = if slot.Weekly then quests.Week == thisWeek else quests.Day == today
		if stillCurrent then
			table.insert(kept, slot)
		end
	end

	if quests.Day ~= today then
		for _, quest in Economy.pickQuests(seedFor(player, today, false), Config.Balance.Quests.DailyCount, false) do
			table.insert(kept, makeSlot(data, quest, false))
		end
		quests.Day = today
	end
	if quests.Week ~= thisWeek then
		for _, quest in Economy.pickQuests(seedFor(player, thisWeek, true), 1, true) do
			table.insert(kept, makeSlot(data, quest, true))
		end
		quests.Week = thisWeek
	end

	quests.Active = kept
	StateService.markDirty(player)
end

local function claim(player: Player, index: any)
	local data = DataService.get(player)
	if not data or typeof(index) ~= "number" then
		return
	end
	-- Rolled over first: a claim arriving just after midnight should be judged
	-- against today's set, not yesterday's.
	QuestService.refresh(player)

	local slot = data.Quests.Active[index]
	if not slot then
		return
	end
	local quest = Economy.questById(slot.Id)
	if not quest then
		return
	end
	if slot.Claimed then
		StateService.notify(player, "You've already claimed that one.", "Error")
		return
	end
	if not Economy.questComplete(data, slot) then
		local done, target = Economy.questProgress(data, slot)
		StateService.notify(player, `Not finished yet — {done} of {target}.`, "Error")
		return
	end

	slot.Claimed = true
	local description, granted = RewardService.grant(player, quest.Reward)
	StateService.markDirty(player)
	StateService.notify(player, `{quest.Text}: {description}!`, "Reward")
	ActionService.fire(player, "QuestClaimed", {
		Value = quest.Target,
		Cash = granted.Cash,
		Gems = granted.Gems,
		Fields = { Quest = quest.Id },
	})
end

function QuestService.init()
	Net.event("ClaimQuest").OnServerEvent:Connect(claim)

	-- Rolled over whenever the client asks for a fresh view, which covers a
	-- session that runs across midnight without a timer of its own.
	Net.event("Ready").OnServerEvent:Connect(QuestService.refresh)
end

return QuestService
