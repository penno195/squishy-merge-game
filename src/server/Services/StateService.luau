--!strict
-- Pushes each player's state to their client. Services call markDirty after a
-- change; one snapshot per player is sent at most once per frame. Services add
-- their own fields to the snapshot with addProvider.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local DataService = require(script.Parent.DataService)
local Net = require(ReplicatedStorage.Shared.Net)

type Snapshot = { [string]: any }
type Provider = (Player, Snapshot) -> ()

local StateService = {}

local dirty: { [Player]: boolean } = {}
local providers: { Provider } = {}
-- Players whose UI is listening. Messages sent before that (offline earnings,
-- daily streaks) wait in a queue rather than vanishing.
local ready: { [Player]: boolean } = {}
local queued: { [Player]: { { message: string, kind: string } } } = {}

function StateService.markDirty(player: Player)
	dirty[player] = true
end

function StateService.addProvider(provider: Provider)
	table.insert(providers, provider)
end

-- `kind` lets the client style the toast: Info, Error, Reward, Discovery, Offline, Rebirth.
function StateService.notify(player: Player, message: string, kind: string?)
	if ready[player] then
		Net.event("Notify"):FireClient(player, message, kind or "Info")
		return
	end
	local pending = queued[player]
	if not pending then
		pending = {}
		queued[player] = pending
	end
	table.insert(pending, { message = message, kind = kind or "Info" })
end

function StateService.init()
	local stateUpdate = Net.event("StateUpdate")
	local notify = Net.event("Notify")

	Net.event("Ready").OnServerEvent:Connect(function(player)
		ready[player] = true
		local pending = queued[player]
		if pending then
			for _, entry in pending do
				notify:FireClient(player, entry.message, entry.kind)
			end
			queued[player] = nil
		end
		StateService.markDirty(player)
	end)

	Players.PlayerRemoving:Connect(function(player)
		ready[player] = nil
		queued[player] = nil
		dirty[player] = nil
	end)

	RunService.Heartbeat:Connect(function()
		if next(dirty) == nil then
			return
		end
		for player in dirty do
			local data = DataService.get(player)
			if data and player.Parent then
				local snapshot: Snapshot = {
					Data = data,
					Now = os.time(),
					ServerTime = Workspace:GetServerTimeNow(),
				}
				for _, provider in providers do
					provider(player, snapshot)
				end
				stateUpdate:FireClient(player, snapshot)
			end
		end
		table.clear(dirty)
	end)
end

return StateService
