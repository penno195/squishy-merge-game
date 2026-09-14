--!strict
-- Playtime rewards: a ladder of claims through one sitting.
--
-- The ladder is deliberately *not* saved. It measures the current session and
-- resets when the player leaves, which is what makes it a reason to stay for
-- another ten minutes rather than a second daily reward -- that one already
-- exists, and pays for coming back. `data.Playtime` keeps the lifetime total
-- for anything that wants to ask how long someone has played; it isn't what
-- this ladder counts.
--
-- So a session lives in memory here and nowhere else, and a server restart
-- costing someone an unclaimed rung is the right trade for never having to
-- migrate or reconcile it.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local ActionService = require(script.Parent.ActionService)
local Config = require(ReplicatedStorage.Shared.Config)
local DataService = require(script.Parent.DataService)
local Economy = require(ReplicatedStorage.Shared.Economy)
local Format = require(ReplicatedStorage.Shared.Format)
local Net = require(ReplicatedStorage.Shared.Net)
local RewardService = require(script.Parent.RewardService)
local StateService = require(script.Parent.StateService)

-- Server time rather than os.clock, because the client counts the same ladder
-- down against Workspace:GetServerTimeNow() and the two have to agree.
type Session = {
	startedAt: number,
	-- Keyed by rung index. Absent is unclaimed, so a fresh session is `{}`.
	claimed: { [number]: boolean },
	-- How many rungs had come up last time the ticker looked. Only a change
	-- is worth a toast, and only a change is worth waking the client for.
	announced: number,
}

local PlaytimeService = {}

local sessions: { [Player]: Session } = {}

-- A ladder whose rungs are half an hour apart can't be watched arriving, so in
-- Studio the clock runs fast. Read once: a live server is always at 1, and the
-- client is sent this rather than deciding for itself, since a Studio playtest
-- has a Studio client too and only the server's clock is the authority.
local SPEED = if RunService:IsStudio() then math.max(Config.Settings.StudioPlaytimeSpeed, 1) else 1

-- Seconds into this session. Zero for anyone the ladder isn't running for,
-- which reads as "no rung is ready" everywhere it's used.
function PlaytimeService.elapsed(player: Player): number
	local session = sessions[player]
	return if session then (Workspace:GetServerTimeNow() - session.startedAt) * SPEED else 0
end

function PlaytimeService.addPlayer(player: Player)
	sessions[player] = { startedAt = Workspace:GetServerTimeNow(), claimed = {}, announced = 0 }
	StateService.markDirty(player)
end

function PlaytimeService.removePlayer(player: Player)
	sessions[player] = nil
end

local function claim(player: Player, index: any)
	local session = sessions[player]
	local data = DataService.get(player)
	if not (session and data) or typeof(index) ~= "number" then
		return
	end
	local rung = Economy.playtimeRungs()[index]
	if not rung then
		return
	end

	-- Re-checked here rather than trusted from the button: the client can fire
	-- this whenever it likes, and its own clock is not the one that counts.
	local elapsed = PlaytimeService.elapsed(player)
	if session.claimed[index] then
		StateService.notify(player, "You've already claimed that one.", "Error")
		return
	end
	if not Economy.playtimeReached(elapsed, index) then
		local done, target = Economy.playtimeProgress(elapsed, index)
		StateService.notify(player, `Not yet — {Format.time(target - done)} to go.`, "Error")
		return
	end

	session.claimed[index] = true
	-- Claiming one is the only thing that can take the ready count down, so the
	-- ticker is told where it stands or it would re-announce the rest.
	session.announced = Economy.playtimeReadyCount(elapsed, session.claimed)

	local description, granted = RewardService.grant(player, rung.Reward)
	StateService.markDirty(player)
	StateService.notify(player, `{rung.Minutes} minutes played: {description}!`, "Reward")
	ActionService.fire(player, "PlaytimeClaimed", {
		Value = rung.Minutes,
		Cash = granted.Cash,
		Gems = granted.Gems,
		Fields = { Rung = tostring(index) },
	})
end

-- A rung coming up is the one thing here the player didn't ask for, so it has
-- to announce itself. Checked on a slow timer rather than every frame: the
-- rungs are minutes apart and nothing is watching the seconds but the panel,
-- which runs its own clock off the session start.
local CHECK_SECONDS = 2

function PlaytimeService.init()
	Net.event("ClaimPlaytime").OnServerEvent:Connect(claim)

	Players.PlayerRemoving:Connect(PlaytimeService.removePlayer)

	StateService.addProvider(function(player, snapshot)
		local session = sessions[player]
		if session then
			snapshot.SessionStartedAt = session.startedAt
			snapshot.PlaytimeSpeed = SPEED
			-- Sent as one flag per rung rather than as the sparse map it's kept
			-- as. A table with holes in it is the shape that goes over a remote
			-- least predictably, and a dense array of the ladder's own length
			-- is what the panel wants to read anyway.
			local claimed = table.create(#Economy.playtimeRungs(), false)
			for index = 1, #claimed do
				claimed[index] = session.claimed[index] == true
			end
			snapshot.PlaytimeClaimed = claimed
		end
	end)

	local since = 0
	RunService.Heartbeat:Connect(function(delta)
		since += delta
		if since < CHECK_SECONDS then
			return
		end
		since = 0

		local now = Workspace:GetServerTimeNow()
		for player, session in sessions do
			local ready = Economy.playtimeReadyCount((now - session.startedAt) * SPEED, session.claimed)
			if ready > session.announced then
				session.announced = ready
				StateService.markDirty(player)
				StateService.notify(player, "A playtime reward is ready to claim!", "Reward")
			end
		end
	end)
end

return PlaytimeService
