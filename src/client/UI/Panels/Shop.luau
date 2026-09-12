--!strict
-- Robux shop: gamepasses and developer products. Entries whose ID is still 0
-- in Settings are hidden, so a new reskin shows only what it has set up.

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Components = require(script.Parent.Parent.Components)
local Config = require(ReplicatedStorage.Shared.Config)

local LocalPlayer = Players.LocalPlayer
local Monetisation = Config.Balance.Monetisation
local Palette = Components.Palette
local Theme = Config.Theme

local Shop = {}

local function fill(text: string): string
	return (
		text:gsub("{Currency}", Theme.Text.Currency)
			:gsub("{UnitPlural}", Theme.Text.UnitPlural)
			:gsub("{Unit}", Theme.Text.Unit)
	)
end

local function rewardText(key: string): string
	local reward = Monetisation.ProductRewards[key]
	local parts = {}
	if reward.IncomeMinutes then
		table.insert(parts, fill(`{reward.IncomeMinutes} minutes of {Theme.Text.Currency} income`))
	end
	if reward.Gems then
		table.insert(parts, `{reward.Gems} Gems, for earning boosts`)
	end
	if reward.UnitTierBonus then
		-- Plain string: the braces are placeholders for fill(), not interpolation.
		table.insert(parts, fill("a bonus {Unit}, " .. reward.UnitTierBonus .. " tiers above your spawn"))
	end
	return table.concat(parts, " and ")
end

-- Products are keyed by a code name; these are what players actually see.
local PRODUCT_TITLES: { [string]: string } = {
	CashSmall = fill("Pouch of {Currency}"),
	CashLarge = fill("Barrel of {Currency}"),
	UnitBoost = fill("Bonus {Unit}"),
	GemPack = "Gem Pack",
}

local PASSES = {
	{
		Key = "DoubleCash",
		Title = fill("x{Currency} Multiplier"),
		Description = fill(`Earn {Monetisation.DoubleCashMultiplier}x {Theme.Text.Currency}, forever.`),
	},
	{
		Key = "AutoMerge",
		Title = "Auto Merge",
		Description = fill("Your {UnitPlural} merge themselves while you play."),
	},
	{
		Key = "FastSpawn",
		Title = "Fast Spawn",
		Description = fill("{UnitPlural} spawn twice as fast."),
	},
}

function Shop.create(parent: Instance)
	local panel = Components.panel("Shop", UDim2.fromOffset(480, 460), parent)
	local list = Components.scroller({ Size = UDim2.fromScale(1, 1), Parent = panel.Content })
	Components.listLayout({ Padding = UDim.new(0, 8) }).Parent = list

	local passButtons = {}
	local order = 0

	local function addEntry(title: string, description: string, id: number, infoType: Enum.InfoType, onBuy: () -> ())
		order += 1
		local card = Components.card({ Size = UDim2.new(1, -12, 0, 80), LayoutOrder = order, Parent = list })
		Components.label({
			Text = title,
			Size = UDim2.new(0.55, 0, 0, 28),
			Position = UDim2.fromOffset(12, 8),
			TextXAlignment = Enum.TextXAlignment.Left,
			Parent = card,
		})
		Components.label({
			Text = description,
			Size = UDim2.new(0.55, 0, 0, 32),
			Position = UDim2.fromOffset(12, 40),
			TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = Palette.TextMuted,
			Parent = card,
		})
		local button = Components.button({
			Text = "Buy",
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -12, 0.5, 0),
			Size = UDim2.fromOffset(150, 56),
			BackgroundColor3 = Palette.Positive,
			Parent = card,
		}, onBuy)

		-- Show the real Robux price once Roblox answers.
		task.spawn(function()
			local ok, info = pcall(MarketplaceService.GetProductInfo, MarketplaceService, id, infoType)
			if ok and info and info.PriceInRobux then
				button.setText(`R$ {info.PriceInRobux}`)
			end
		end)
		return button
	end

	for _, pass in PASSES do
		local id = Config.Settings.GamePasses[pass.Key]
		if id ~= 0 then
			passButtons[pass.Key] = addEntry(pass.Title, pass.Description, id, Enum.InfoType.GamePass, function()
				MarketplaceService:PromptGamePassPurchase(LocalPlayer, id)
			end)
		end
	end

	for key, id in Config.Settings.Products do
		if id ~= 0 and Monetisation.ProductRewards[key] then
			addEntry(PRODUCT_TITLES[key] or key, rewardText(key), id, Enum.InfoType.Product, function()
				MarketplaceService:PromptProductPurchase(LocalPlayer, id)
			end)
		end
	end

	if order == 0 then
		Components.label({
			Text = "Nothing for sale yet — add your pass and product IDs in Shared/Settings.",
			Size = UDim2.new(1, -24, 0, 80),
			TextColor3 = Palette.TextMuted,
			TextWrapped = true,
			Parent = list,
		})
	end

	local function update(snapshot: { [string]: any })
		local passes = snapshot.Passes or {}
		for key, button in passButtons do
			if passes[key] then
				button.setText("Owned")
				button.setEnabled(false)
			end
		end
	end

	return {
		setOpen = panel.setOpen,
		isOpen = panel.isOpen,
		update = update,
	}
end

return Shop
