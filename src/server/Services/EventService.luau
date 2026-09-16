--!strict
-- Live events and announcements, across every server of the game at once.
--
-- An event is a strength and an end time, one per kind (LiveEvents). Three paths
-- carry it between servers, because none of them is enough alone:
--
--   * A DataStore key holds what's running, so a server that starts halfway
--     through an event picks it up, and a server that missed a message catches up.
--   * MessagingService tells every running server the moment one starts or ends,
--     so staff don't press the button and wait a minute to see it happen.
--   * Every server re-reads the key every POLL_SECONDS anyway. MessagingService
--     delivery is best-effort; an event that never arrived must still arrive.
--
-- All three are wrapped so that when they fail -- Studio without API access, a
-- DataStore outage -- the event still runs on the server that started it.
--
-- None of them may ever hold anything up. MessagingService in a place that has
-- never been published doesn't fail, it waits, indefinitely: subscribing inside
-- `init` once stopped the whole server starting -- no world, no gardens, no data --
-- with nothing in the Output to say why. So a place with no id doesn't try at all,
-- and everything that talks to another server runs on its own thread.
--
-- Announcements go by MessagingService only. They're a moment, not a state: one
-- that turns up two minutes late is worse than one that doesn't.

local DataStoreService = game:GetService("DataStoreService")
local MessagingService = game:GetService("MessagingService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextService = game:GetService("TextService")

local Config = require(ReplicatedStorage.Shared.Config)
local LiveEvents = require(ReplicatedStorage.Shared.LiveEvents)
local Net = require(ReplicatedStorage.Shared.Net)
local StateService = require(script.Parent.StateService)

local STORE_KEY = "Active"
local EVENTS_TOPIC = "LiveEvents"
local ANNOUNCE_TOPIC = "Announcements"
local POLL_SECONDS = 60
-- A place that has never been published has id 0, and nothing to reach.
local CROSS_SERVER = game.PlaceId ~= 0

export type Running = {
	Strength: number,
	-- os.time() when it ends.
	EndsAt: number,
	-- The display name of whoever started it, for the staff panel.
	StartedBy: string,
}
type Table = { [string]: Running }

local EventService = {}

local running: Table = {}
local store: DataStore? = nil

local function now(): number
	return os.time()
end

-- Only the kinds that exist, with sane numbers, still running. Everything read
-- from the store or a message goes through here: both outlive the code that wrote
-- them, and an event renamed or removed since must not linger.
local function clean(source: unknown): Table
	local result: Table = {}
	if typeof(source) ~= "table" then
		return result
	end
	for id, entry in source :: { [any]: any } do
		local def = if typeof(id) == "string" then LiveEvents.ById[id] else nil
		if
			def
			and typeof(entry) == "table"
			and typeof(entry.Strength) == "number"
			and typeof(entry.EndsAt) == "number"
			and entry.EndsAt > now()
			and table.find(def.Strengths, entry.Strength)
		then
			result[id] = {
				Strength = entry.Strength,
				EndsAt = entry.EndsAt,
				StartedBy = if typeof(entry.StartedBy) == "string" then entry.StartedBy else "",
			}
		end
	end
	return result
end

local function describe(id: string, entry: Running): string
	local def = LiveEvents.ById[id]
	local minutes = math.max(math.ceil((entry.EndsAt - now()) / 60), 1)
	return `{def.Icon} {def.Name} x{entry.Strength} event for {minutes} minutes!`
end

-- Takes a fresh table as what's running here, telling players about anything
-- that has started or changed since the last one.
local function adopt(fresh: Table)
	for id, entry in fresh do
		local before = running[id]
		if not before or before.Strength ~= entry.Strength or before.EndsAt ~= entry.EndsAt then
			for _, player in Players:GetPlayers() do
				StateService.notify(player, describe(id, entry), "Reward")
			end
		end
	end
	for id in running do
		if not fresh[id] then
			local def = LiveEvents.ById[id]
			for _, player in Players:GetPlayers() do
				StateService.notify(player, `{def.Icon} The {def.Name} event has ended.`, "Info")
			end
		end
	end
	running = fresh
	for _, player in Players:GetPlayers() do
		StateService.markDirty(player)
	end
end

-- Fire and forget, on its own thread, so a slow or stuck publish never delays
-- what this server does with the change.
local function publish(topic: string, message: any)
	if not CROSS_SERVER then
		return
	end
	task.spawn(function()
		local ok, err = pcall(MessagingService.PublishAsync, MessagingService, topic, message)
		if not ok then
			warn(`Couldn't publish to {topic}: {err}`)
		end
	end)
end

-- Changes what's running everywhere: `change` edits the table, the store keeps
-- the result, every server is told, and this one adopts it straight away whether
-- or not any of that worked.
local function update(change: (Table) -> ())
	local result: Table? = nil
	local activeStore = store
	if activeStore then
		local ok, err = pcall(function()
			activeStore:UpdateAsync(STORE_KEY, function(current)
				local events = clean(current)
				change(events)
				result = events
				return events
			end)
		end)
		if not ok then
			warn(`Couldn't save live events: {err}`)
			result = nil
		end
	end
	if not result then
		local here = clean(running)
		change(here)
		result = here
	end
	local final = result :: Table
	adopt(final)
	publish(EVENTS_TOPIC, final)
end

local function poll()
	local activeStore = store
	if not activeStore then
		return
	end
	local ok, value = pcall(activeStore.GetAsync, activeStore, STORE_KEY)
	if ok then
		adopt(clean(value))
	end
end

-- The strength of a running event, or 1 -- which multiplies nothing -- when that
-- kind isn't on. Ended events are dropped here too, rather than waiting on the next
-- poll to notice.
function EventService.strength(id: string): number
	local entry = running[id]
	if not entry then
		return 1
	end
	if entry.EndsAt <= now() then
		local fresh = table.clone(running)
		fresh[id] = nil
		adopt(fresh)
		return 1
	end
	return entry.Strength
end

function EventService.start(starter: Player, id: string, strength: number, minutes: number)
	update(function(events)
		events[id] = { Strength = strength, EndsAt = now() + minutes * 60, StartedBy = starter.DisplayName }
	end)
end

function EventService.stop(id: string)
	update(function(events)
		events[id] = nil
	end)
end

local function deliver(text: string, from: string)
	Net.event("Announcement"):FireAllClients(text, from)
end

-- Filtered before it leaves: staff are players too as far as Roblox's text rules
-- go, and this is shown to every player in the game. Returns why it failed, or
-- nil once it's on its way.
function EventService.announce(sender: Player, text: string): string?
	local ok, filtered = pcall(function()
		local result = TextService:FilterStringAsync(text, sender.UserId, Enum.TextFilterContext.PublicChat)
		return result:GetNonChatStringForBroadcastAsync()
	end)
	if not ok or typeof(filtered) ~= "string" or filtered == "" then
		return "The message couldn't be checked by Roblox's filter. Try again in a moment."
	end
	deliver(filtered, sender.DisplayName)
	publish(ANNOUNCE_TOPIC, { Text = filtered, From = sender.DisplayName, JobId = game.JobId })
	return nil
end

function EventService.init()
	if not CROSS_SERVER then
		-- Said once, quietly, rather than as a warning: in Studio this is expected.
		print("Live events and staff messages stay on this server until the place is published.")
	else
		local ok, result =
			pcall(DataStoreService.GetDataStore, DataStoreService, `{Config.Settings.DataStoreName}_LiveEvents`)
		if ok then
			store = result
		else
			warn(`Live events won't reach other servers: {result}`)
		end

		task.spawn(function()
			local subscribed, err = pcall(function()
				MessagingService:SubscribeAsync(EVENTS_TOPIC, function(message)
					adopt(clean(message.Data))
				end)
				MessagingService:SubscribeAsync(ANNOUNCE_TOPIC, function(message)
					local data = message.Data
					-- The server that sent it has already shown it.
					if typeof(data) ~= "table" or data.JobId == game.JobId then
						return
					end
					if typeof(data.Text) == "string" and typeof(data.From) == "string" then
						deliver(data.Text, data.From)
					end
				end)
			end)
			if not subscribed then
				warn(`Live events won't arrive from other servers straight away: {err}`)
			end
		end)

		task.spawn(function()
			while true do
				poll()
				task.wait(POLL_SECONDS)
			end
		end)
	end

	StateService.addProvider(function(_, snapshot)
		local list = {}
		for id, entry in running do
			if entry.EndsAt > now() then
				table.insert(
					list,
					{ Id = id, Strength = entry.Strength, EndsAt = entry.EndsAt, StartedBy = entry.StartedBy }
				)
			end
		end
		snapshot.Events = list
	end)
end

return EventService
