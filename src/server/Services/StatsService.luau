--!strict
-- Lifetime tallies: how many times this player has ever merged, sold, crafted,
-- spun. Kept because "have they ever done X" and "how many more until Y" are
-- the questions quests, the tutorial and playtime rewards are all made of, and
-- none of them should have to count for themselves.
--
-- It listens to ActionService and writes nothing else, so counting a new verb
-- is a line in the table below.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ActionService = require(script.Parent.ActionService)
local DataService = require(script.Parent.DataService)
local StateService = require(script.Parent.StateService)
local Types = require(ReplicatedStorage.Shared.Types)

local StatsService = {}

-- Action -> the stat it counts toward. The names on the right are what the rest
-- of the game asks for, so they outlive any renaming of the actions.
local COUNTS: { [string]: string } = {
	Dropped = "Drops",
	Merged = "Merges",
	Sold = "Sales",
	Discovered = "Discoveries",
	Upgraded = "Upgrades",
	Rebirthed = "Rebirths",
	CraftStarted = "Crafts",
	CraftCollected = "CraftsCollected",
	WheelSpun = "Spins",
	DailyClaimed = "DailyClaims",
	QuestClaimed = "QuestsClaimed",
	PlaytimeClaimed = "PlaytimeClaims",
}

function StatsService.get(data: Types.PlayerData, stat: string): number
	return data.Stats[stat] or 0
end

function StatsService.add(player: Player, stat: string, amount: number)
	local data = DataService.get(player)
	if not data then
		return
	end
	data.Stats[stat] = (data.Stats[stat] or 0) + amount
	StateService.markDirty(player)
end

function StatsService.init()
	local function count(action: ActionService.Action)
		ActionService.on(action, function(player)
			StatsService.add(player, COUNTS[action], 1)
		end)
	end

	count("Dropped")
	count("Merged")
	count("Sold")
	count("Discovered")
	count("Upgraded")
	count("Rebirthed")
	count("CraftStarted")
	count("CraftCollected")
	count("WheelSpun")
	count("DailyClaimed")
	count("QuestClaimed")
	count("PlaytimeClaimed")

	-- Playtime comes off the session clock rather than a tally, so it's the one
	-- thing here that isn't a count of something.
	ActionService.on("SessionEnded", function(player, payload)
		local data = DataService.get(player)
		if data and payload.Seconds then
			data.Playtime += payload.Seconds
		end
	end)
end

return StatsService
