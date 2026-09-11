--!strict
-- Holds the latest state snapshot from the server and notifies the UI.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage.Shared.Net)

export type Snapshot = { [string]: any }

local State = {}

local current: Snapshot? = nil
local listeners: { (Snapshot) -> () } = {}

function State.get(): Snapshot?
	return current
end

-- Called immediately with the current snapshot if one has arrived already.
function State.onChange(listener: (Snapshot) -> ())
	table.insert(listeners, listener)
	if current then
		listener(current)
	end
end

function State.start()
	Net.event("StateUpdate").OnClientEvent:Connect(function(snapshot: Snapshot)
		current = snapshot
		for _, listener in listeners do
			xpcall(listener, function(err)
				warn(`State listener failed: {err}`)
			end, snapshot)
		end
	end)
end

return State
