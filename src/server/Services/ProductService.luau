--!strict
-- Developer product receipts. A product is granted once per receipt ID, and
-- only reported to Roblox as granted once that receipt ID has actually saved,
-- so a server crash mid-purchase never charges a player for nothing.

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local DataService = require(script.Parent.DataService)
local RewardService = require(script.Parent.RewardService)
local StateService = require(script.Parent.StateService)

local MAX_STORED_RECEIPTS = 50
local SAVE_TIMEOUT = 30

local ProductService = {}

local nameById: { [number]: string } = {}
for name, id in Config.Settings.Products do
	if id ~= 0 then
		nameById[id] = name
	end
end

local function grantAndSave(player: Player, profile: any, receipt: { [string]: any }): boolean
	local data = profile.Data
	local purchaseId = tostring(receipt.PurchaseId)

	if not table.find(data.PurchaseIds, purchaseId) then
		local name = nameById[receipt.ProductId]
		local reward = if name then Config.Balance.Monetisation.ProductRewards[name] else nil
		if not reward then
			warn(`No reward configured for developer product {receipt.ProductId}`)
			return false
		end
		table.insert(data.PurchaseIds, purchaseId)
		while #data.PurchaseIds > MAX_STORED_RECEIPTS do
			table.remove(data.PurchaseIds, 1)
		end
		local description = RewardService.grant(player, reward)
		StateService.notify(player, `Thanks! You received {description}.`, "Reward")
	end

	local function isSaved(): boolean
		local saved = profile.LastSavedData
		return saved ~= nil and table.find(saved.PurchaseIds, purchaseId) ~= nil
	end

	if isSaved() then
		return true
	end
	profile:Save()
	local deadline = os.clock() + SAVE_TIMEOUT
	while os.clock() < deadline do
		if isSaved() then
			return true
		end
		if not profile:IsActive() then
			return false
		end
		task.wait(0.5)
	end
	return false
end

local function processReceipt(receipt: { [string]: any }): Enum.ProductPurchaseDecision
	local player = Players:GetPlayerByUserId(receipt.PlayerId)
	if not player then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local profile = DataService.getProfile(player)
	if not profile or not profile:IsActive() then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	local ok, granted = pcall(grantAndSave, player, profile, receipt)
	if not ok then
		warn(`Failed to process receipt for {player.Name}: {granted}`)
	end
	return if ok and granted
		then Enum.ProductPurchaseDecision.PurchaseGranted
		else Enum.ProductPurchaseDecision.NotProcessedYet
end

function ProductService.init()
	MarketplaceService.ProcessReceipt = processReceipt
end

return ProductService
