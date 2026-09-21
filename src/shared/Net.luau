--!strict
-- Remote definitions. The server creates them on first require; clients wait.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local FOLDER_NAME = "Remotes"

local EVENTS = {
	-- Client -> server
	"DropCarried",
	"SellCarried",
	"BuyUnit",
	"BuyUpgrade",
	"BuyBoost",
	"BuyLuck",
	"BuyAutoMerge",
	"Spin",
	"BuySpin",
	"Rebirth",
	"ClaimDaily",
	"ClaimQuest",
	"ClaimPlaytime",
	"ClaimPrize",
	-- The crafting station in the hub.
	"CraftAdd",
	"CraftTakeBack",
	"CraftStart",
	"CraftSkip",
	"CraftCollect",
	-- Pets. Hatching happens at a pad in the hub; the rest is the panel.
	"HatchEgg",
	"EquipPet",
	"ReleasePet",
	-- The admin panel: a command id, and the user id of whoever it's aimed at.
	"AdminCommand",
	-- The staff panel: a command name and a table of its arguments.
	"StaffCommand",
	-- Fired once the client's UI is listening, so nothing sent at join is lost.
	"Ready",
	-- Server -> client
	"StateUpdate",
	"Notify",
	"MergeEffect",
	-- A unit dropping in: where it lands, and its index in Config.Units, so the
	-- client knows whether it was a plain one or something off the ladder.
	"SpawnEffect",
	"SpinResult",
	"SellPrompt",
	"CraftResult",
	"PetHatched",
	"Leaderboard",
	-- An admin command the receiving client carries out on itself: a shove on its
	-- own character, or the rain everyone gets.
	"AdminEffect",
	-- A staff message to every player in the game: the text, and who sent it.
	"Announcement",
}

local folder: Instance
if RunService:IsServer() then
	folder = Instance.new("Folder")
	folder.Name = FOLDER_NAME
	for _, name in EVENTS do
		local remote = Instance.new("RemoteEvent")
		remote.Name = name
		remote.Parent = folder
	end
	folder.Parent = ReplicatedStorage
else
	folder = ReplicatedStorage:WaitForChild(FOLDER_NAME)
end

local Net = {}

function Net.event(name: string): RemoteEvent
	assert(table.find(EVENTS, name), `Unknown remote "{name}"`)
	return folder:WaitForChild(name) :: RemoteEvent
end

return Net
