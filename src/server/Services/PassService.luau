--!strict
-- Gamepass ownership (checked on join, updated on in-game purchase) and the
-- multipliers the passes grant.

local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local StateService = require(script.Parent.StateService)

local Monetisation = Config.Balance.Monetisation

local PassService = {}

local owned: { [Player]: { [string]: boolean } } = {}
local nameById: { [number]: string } = {}
for name, id in Config.Settings.GamePasses do
	if id ~= 0 then
		nameById[id] = name
	end
end

-- Yields while ownership is checked.
function PassService.load(player: Player)
	local passes = {}
	owned[player] = passes
	for name, id in Config.Settings.GamePasses do
		if id ~= 0 then
			local ok, result = pcall(MarketplaceService.UserOwnsGamePassAsync, MarketplaceService, player.UserId, id)
			passes[name] = ok and result == true
		end
	end
end

function PassService.unload(player: Player)
	owned[player] = nil
end

function PassService.has(player: Player, name: string): boolean
	local passes = owned[player]
	return passes ~= nil and passes[name] == true
end

function PassService.cashMultiplier(player: Player): number
	return if PassService.has(player, "DoubleCash") then Monetisation.DoubleCashMultiplier else 1
end

function PassService.spawnMultiplier(player: Player): number
	return if PassService.has(player, "FastSpawn") then Monetisation.FastSpawnMultiplier else 1
end

function PassService.init()
	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, purchased)
		local name = nameById[passId]
		local passes = owned[player]
		if purchased and name and passes then
			passes[name] = true
			StateService.markDirty(player)
			StateService.notify(player, "Thanks for your purchase!", "Reward")
		end
	end)

	StateService.addProvider(function(player, snapshot)
		snapshot.Passes = owned[player] or {}
	end)
end

return PassService
