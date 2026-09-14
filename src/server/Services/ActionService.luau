--!strict
-- Announces what players do. Services fire an action at the moment it happens;
-- anything that wants to react subscribes to it by name.
--
-- This exists so a verb is tapped once rather than once per feature. Analytics
-- listens today, and quests, playtime rewards and the tutorial listen later --
-- none of which the code that fires an action has to know about. A listener
-- that throws is warned about and ignored, so a broken feature can never break
-- the gameplay that reported to it.
--
-- Requires nothing, so any service can require it without a cycle. Keep it that
-- way: listeners read whatever they need through DataService themselves.

local ActionService = {}

-- Every action the game fires. Listed here rather than passed as free strings
-- so a typo is a type error, and so this doubles as the list of what the game
-- can measure.
export type Action =
	-- The garden
	"Dropped" -- a unit arrived: falling from the sky, bought, or a reward
	| "Merged" -- two units became one
	| "Sold" -- a unit went in the bin
	| "Discovered" -- a unit index was seen for the first time
	-- Spending and progress
	| "Upgraded"
	| "Rebirthed"
	| "BoostBought"
	| "LuckBought"
	-- The crafting station
	| "CraftStarted"
	| "CraftSkipped"
	| "CraftCollected"
	-- Handouts
	| "WheelSpun"
	| "SpinBought"
	| "DailyClaimed"
	| "QuestClaimed"
	| "PlaytimeClaimed"
	| "PrizeClaimed"
	| "OfflineEarned"
	| "ProductPurchased"
	-- Session bookends
	| "SessionStarted"
	| "SessionEnded"

-- Loosely typed on purpose: each action carries its own fields, documented at
-- the site that fires it. Amounts are named Cash/Gems/Robux so a listener can
-- treat any action as a currency movement without knowing which one it is.
export type Payload = { [string]: any }

type Listener = (Player, Payload) -> ()

local listeners: { [string]: { Listener } } = {}

function ActionService.on(action: Action, listener: Listener)
	local forAction = listeners[action]
	if not forAction then
		forAction = {}
		listeners[action] = forAction
	end
	table.insert(forAction, listener)
end

function ActionService.fire(player: Player, action: Action, payload: Payload?)
	local forAction = listeners[action]
	if not forAction then
		return
	end
	local fields = payload or {}
	for _, listener in forAction do
		xpcall(listener, function(err)
			warn(`Listener for action "{action}" failed for {player.Name}: {err}`)
		end, player, fields)
	end
end

return ActionService
