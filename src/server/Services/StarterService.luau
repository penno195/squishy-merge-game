--!strict
-- The starter pack: one bundle of cash, gems and a good unit, offered only for a
-- player's first day.
--
-- Sold as a gamepass rather than a developer product, because "one-time" has to
-- mean it when real money is involved: Roblox will not sell a pass twice, and
-- refuses the prompt outright for someone who already owns it. A product would
-- take two purchases and leave the second one to be explained away afterwards.
--
-- Owning the pass and having the goods are separate things. A purchase can land
-- on a server that dies before it saves, so ownership is re-checked on every
-- join and the save's own `StarterClaimed` is what stops a second helping. That
-- also means the window only ever governs the *offer*: a pass bought in the last
-- second of it is still honoured, whenever the player next appears.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local ActionService = require(script.Parent.ActionService)
local Config = require(ReplicatedStorage.Shared.Config)
local DataService = require(script.Parent.DataService)
local Economy = require(ReplicatedStorage.Shared.Economy)
local PassService = require(script.Parent.PassService)
local RewardService = require(script.Parent.RewardService)
local StateService = require(script.Parent.StateService)

local PASS = "StarterPack"

local StarterService = {}

local function grant(player: Player)
	local data = DataService.get(player)
	if not data or data.StarterClaimed or not PassService.has(player, PASS) then
		return
	end
	-- Flagged before the bundle is handed over, not after. Nothing in the grant
	-- yields today, but if anything ever does, the flag is what stands between a
	-- second join and a second pack -- and a player who somehow got the flag
	-- without the goods has lost a bundle, where the other way round has lost us
	-- one every time they log in.
	data.StarterClaimed = true
	local description, granted = RewardService.grant(player, Config.Balance.Monetisation.StarterPack.Reward)
	StateService.markDirty(player)
	StateService.notify(player, `Starter pack unlocked! You received {description}.`, "Reward")
	ActionService.fire(player, "StarterClaimed", {
		Cash = granted.Cash,
		Gems = granted.Gems,
		Sku = PASS,
		Fields = { Made = tostring(granted.Tier) },
	})
end

-- Called on join, after ownership has been read.
function StarterService.addPlayer(player: Player)
	grant(player)
end

function StarterService.init()
	PassService.onPurchased(function(player, name)
		if name == PASS then
			grant(player)
		end
	end)

	-- What the shop needs to draw the offer, and to count it down. Sent as game
	-- time like the craft clock, so it doesn't rely on the player's own clock
	-- being right -- and the expiry is the server's to decide either way.
	StateService.addProvider(function(player, snapshot)
		local data = DataService.get(player)
		if not data then
			return
		end
		local remaining = Economy.starterRemaining(data, os.time())
		snapshot.StarterEndsAt = Workspace:GetServerTimeNow() + remaining
		snapshot.StarterOffered = remaining > 0
	end)
end

return StarterService
