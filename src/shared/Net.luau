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
	-- Fired once the client's UI is listening, so nothing sent at join is lost.
	"Ready",
	-- Server -> client
	"StateUpdate",
	"Notify",
	"MergeEffect",
	"SpinResult",
	"SellPrompt",
	"CraftResult",
	"PetHatched",
	"Leaderboard",
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
