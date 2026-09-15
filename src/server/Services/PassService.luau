--!strict
-- Gamepass ownership (checked on join, updated on in-game purchase) and the
-- multipliers the passes grant.

local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ActionService = require(script.Parent.ActionService)
local Config = require(ReplicatedStorage.Shared.Config)
local Economy = require(ReplicatedStorage.Shared.Economy)
local StateService = require(script.Parent.StateService)

local Monetisation = Config.Balance.Monetisation

local PassService = {}

local owned: { [Player]: { [string]: boolean } } = {}
-- Told whenever a pass is bought in-game, so a pass that hands something over
-- can act on it without a second connection to MarketplaceService -- and without
-- this module having to require the services that do the handing over.
local purchaseCallbacks: { (Player, string) -> () } = {}
-- Robux prices, looked up once per pass. A pass's price is a constant, and the
-- only reason it isn't known here already is that Settings stores the ID.
local priceById: { [number]: number } = {}
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

-- The permanent charm, expressed as the bias override every luck-sensitive
-- Economy function already takes. nil means "whatever the player's own timed
-- charm says", which for everyone without the pass is the honest answer -- and
-- for someone with it, the pass and a charm are worth the same tilt, so there is
-- nothing to stack.
function PassService.luckBias(player: Player): number?
	return Economy.luckPassBias(PassService.has(player, "LuckCharm"))
end

function PassService.extraCraftSlots(player: Player): number
	return if PassService.has(player, "CraftSlot") then Monetisation.ExtraCraftSlots else 0
end

-- How many crafts this player may have running. The form every caller in
-- CraftService wants, since none of them care about the pass as such.
function PassService.craftSlots(player: Player): number
	return Economy.craftSlots(PassService.extraCraftSlots(player))
end

function PassService.extraGardenSpaces(player: Player): number
	return Economy.gardenPassSpaces(PassService.has(player, "BiggerGarden"))
end

function PassService.autoCollect(player: Player): boolean
	return PassService.has(player, "AutoCollect")
end

function PassService.onPurchased(callback: (Player, string) -> ())
	table.insert(purchaseCallbacks, callback)
end

-- Reports the sale. Spawned and not inline because the price has to be asked
-- for: passes are bought through a Roblox prompt rather than a receipt, so
-- unlike a developer product nothing hands the server the amount spent. A
-- lookup that fails still fires the action -- a sale with no price attached is
-- worth measuring, and dropping it would understate the count as well.
local function report(player: Player, name: string, id: number)
	task.spawn(function()
		local price = priceById[id]
		if not price then
			local ok, info = pcall(MarketplaceService.GetProductInfo, MarketplaceService, id, Enum.InfoType.GamePass)
			price = if ok and info and info.PriceInRobux then info.PriceInRobux else 0
			priceById[id] = price
		end
		ActionService.fire(player, "PassPurchased", {
			Value = price,
			Robux = price,
			Sku = name,
			Fields = { Pass = name },
		})
	end)
end

function PassService.init()
	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, purchased)
		local name = nameById[passId]
		local passes = owned[player]
		if purchased and name and passes then
			passes[name] = true
			StateService.markDirty(player)
			StateService.notify(player, "Thanks for your purchase!", "Reward")
			report(player, name, passId)
			for _, callback in purchaseCallbacks do
				-- One pass that fails to hand its goods over mustn't stop the
				-- next, and mustn't swallow the purchase either.
				xpcall(callback, function(err)
					warn(`Pass purchase callback for {name} failed: {err}`)
				end, player, name)
			end
		end
	end)

	StateService.addProvider(function(player, snapshot)
		snapshot.Passes = owned[player] or {}
	end)
end

return PassService
