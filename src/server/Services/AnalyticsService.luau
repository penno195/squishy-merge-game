--!strict
-- Reports what players do to Roblox's analytics, so the questions the roadmap
-- keeps asking -- where do first sessions end, which upgrade do people stall
-- on, does anyone reach a craft -- have answers before there's a feature
-- riding on the answer.
--
-- Nothing here affects gameplay. Every call into Roblox is wrapped, because
-- analytics throws until it's switched on for the universe, and a game that
-- can't be played because a dashboard is off would be a poor trade.
--
-- It listens to ActionService rather than being called directly, so measuring
-- something new is a line in this file rather than an edit to the gameplay.

local AnalyticsService = {}

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RobloxAnalytics = game:GetService("AnalyticsService")

local ActionService = require(script.Parent.ActionService)
local Config = require(ReplicatedStorage.Shared.Config)
local DataService = require(script.Parent.DataService)

-- Currencies are named for the dashboard, not for the player: a reskin that
-- calls cash "Goo" still reports "Cash", so one dashboard reads every game
-- built from this base.
local CASH = "Cash"
local GEMS = "Gems"

-- Which Roblox transaction type each action counts as. An action missing from
-- here still fires its custom event; it just isn't treated as a purchase.
local TRANSACTION_TYPES: { [string]: string } = {
	Dropped = "Shop", -- only ever carries currency when the unit was bought
	Discovered = "Gameplay",
	Sold = "Gameplay",
	Upgraded = "Shop",
	Rebirthed = "Gameplay",
	BoostBought = "Shop",
	LuckBought = "Shop",
	CraftSkipped = "Shop",
	WheelSpun = "Gameplay",
	SpinBought = "Shop",
	DailyClaimed = "TimedReward",
	QuestClaimed = "Gameplay",
	OfflineEarned = "TimedReward",
	ProductPurchased = "IAP",
}

-- Actions rare enough to be worth their own event. Drops and merges happen
-- every few seconds per player, which would be both noisy and a waste of the
-- universe's custom-event budget, so they're counted in the session totals
-- below and reported once when the player leaves.
local CUSTOM_EVENTS: { [string]: boolean } = {
	Discovered = true,
	Rebirthed = true,
	CraftStarted = true,
	CraftCollected = true,
	CraftSkipped = true,
	WheelSpun = true,
	SpinBought = true,
	DailyClaimed = true,
	QuestClaimed = true,
	PlaytimeClaimed = true,
	PrizeClaimed = true,
	ProductPurchased = true,
	SessionEnded = true,
}

-- What the session totals count. Each is a payload-free tally of an action.
local COUNTED: { [string]: string } = {
	Dropped = "Drops",
	Merged = "Merges",
	Sold = "Sales",
	Upgraded = "Upgrades",
}

type Session = {
	startedAt: number,
	counts: { [string]: number },
}

local sessions: { [Player]: Session } = {}
-- Analytics is off until it's enabled for the universe, and every call throws
-- until it is. Say so once rather than once per event.
local warned = false

local function call(method: string, ...: any)
	local ok, err = pcall(function(...)
		local fn = (RobloxAnalytics :: any)[method]
		fn(RobloxAnalytics, ...)
	end, ...)
	if not ok and not warned then
		warned = true
		warn(`Analytics is not reporting ({method}: {err}). Enable it for this experience in the Creator Dashboard.`)
	end
end

-- Custom fields are capped at three by Roblox and have to be strings, so take
-- the first three in a stable order and stringify whatever they are.
local function customFields(fields: { [string]: any }?): { [string]: string }?
	if not fields then
		return nil
	end
	local keys = {}
	for key in fields do
		table.insert(keys, key)
	end
	if #keys == 0 then
		return nil
	end
	table.sort(keys)

	local packed: { [string]: string } = {}
	local slots = { "CustomField01", "CustomField02", "CustomField03" }
	for position, key in keys do
		local slot = slots[position]
		if not slot then
			break
		end
		packed[(Enum.AnalyticsCustomFieldKeys :: any)[slot].Name] = `{key}:{tostring(fields[key])}`
	end
	return packed
end

function AnalyticsService.economy(
	player: Player,
	source: boolean,
	currency: string,
	amount: number,
	endingBalance: number,
	transactionType: string,
	sku: string?
)
	if amount <= 0 then
		return
	end
	local flow = if source then Enum.AnalyticsEconomyFlowType.Source else Enum.AnalyticsEconomyFlowType.Sink
	call("LogEconomyEvent", player, flow, currency, amount, math.max(endingBalance, 0), transactionType, sku)
end

function AnalyticsService.custom(player: Player, name: string, value: number?, fields: { [string]: any }?)
	call("LogCustomEvent", player, name, value or 1, customFields(fields))
end

-- The onboarding funnel, for the tutorial. Roblox keeps one built-in funnel per
-- experience for exactly this, and it's the one the dashboard charts retention
-- against, so the tutorial should use it rather than a funnel of its own.
function AnalyticsService.onboarding(player: Player, step: number, stepName: string)
	call("LogOnboardingFunnelStepEvent", player, step, stepName)
end

function AnalyticsService.progression(player: Player, path: string, status: string, level: number, levelName: string)
	local enum = (Enum.AnalyticsProgressionType :: any)[status]
	call("LogProgressionEvent", player, path, enum, nil, level, levelName)
end

-- Currency movements follow one convention across every action: Cash/Gems/
-- Robux are what the player was given, CashSpent/GemsSpent what was taken. An
-- action can carry both -- a paid wheel spin does -- and each is logged
-- separately.
local function logCurrency(player: Player, action: string, payload: ActionService.Payload)
	local transaction = TRANSACTION_TYPES[action]
	local data = DataService.get(player)
	if not transaction or not data then
		return
	end
	local sku = payload.Sku

	if payload.Cash then
		AnalyticsService.economy(player, true, CASH, payload.Cash, data.Cash, transaction, sku)
	end
	if payload.CashSpent then
		AnalyticsService.economy(player, false, CASH, payload.CashSpent, data.Cash, transaction, sku)
	end
	if payload.Gems then
		AnalyticsService.economy(player, true, GEMS, payload.Gems, data.Gems, transaction, sku)
	end
	if payload.GemsSpent then
		AnalyticsService.economy(player, false, GEMS, payload.GemsSpent, data.Gems, transaction, sku)
	end
end

local function onAction(player: Player, action: string, payload: ActionService.Payload)
	logCurrency(player, action, payload)

	local counted = COUNTED[action]
	local session = sessions[player]
	if counted and session then
		session.counts[counted] = (session.counts[counted] or 0) + 1
	end

	if CUSTOM_EVENTS[action] then
		AnalyticsService.custom(player, action, payload.Value, payload.Fields)
	end
end

function AnalyticsService.init()
	-- One subscription per action, all landing in the same place. Naming them
	-- one at a time rather than looping a list is what keeps the Action type
	-- doing its job: a typo here is a type error, and an action nobody has
	-- named here is an action nobody is measuring.
	local function measure(action: ActionService.Action)
		ActionService.on(action, function(player, payload)
			onAction(player, action, payload)
		end)
	end

	measure("Dropped")
	measure("Merged")
	measure("Sold")
	measure("Discovered")
	measure("Upgraded")
	measure("Rebirthed")
	measure("BoostBought")
	measure("LuckBought")
	measure("CraftStarted")
	measure("CraftSkipped")
	measure("CraftCollected")
	measure("WheelSpun")
	measure("SpinBought")
	measure("DailyClaimed")
	measure("QuestClaimed")
	measure("PlaytimeClaimed")
	measure("PrizeClaimed")
	measure("OfflineEarned")
	measure("ProductPurchased")
	measure("SessionStarted")
	measure("SessionEnded")

	-- A discovery is the clearest measure of progress the game has: it's the
	-- first time a player has ever seen that tier.
	ActionService.on("Discovered", function(player, payload)
		local tier = payload.Value or 0
		local unit = Config.Units[tier]
		if unit then
			AnalyticsService.progression(player, "MergeLadder", "Complete", tier, unit.Name)
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		sessions[player] = nil
	end)
end

function AnalyticsService.addPlayer(player: Player)
	sessions[player] = { startedAt = os.clock(), counts = {} }
	ActionService.fire(player, "SessionStarted")
end

-- Fired before the profile is released, so the totals a session produced go out
-- with it rather than being lost. The counted actions are too frequent to
-- report one by one; this is where they land instead.
function AnalyticsService.removePlayer(player: Player)
	local session = sessions[player]
	if not session then
		return
	end
	local seconds = os.clock() - session.startedAt
	ActionService.fire(player, "SessionEnded", {
		-- Minutes for the dashboard, seconds for whoever is adding it up.
		Value = math.floor(seconds / 60),
		Seconds = math.floor(seconds),
		Fields = session.counts,
	})
	sessions[player] = nil
end

return AnalyticsService
