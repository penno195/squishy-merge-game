--!strict
-- Robux shop: gamepasses and developer products. Entries whose ID is still 0
-- in Settings are hidden, so a new reskin shows only what it has set up.

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Components = require(script.Parent.Parent.Components)
local Config = require(ReplicatedStorage.Shared.Config)
local Economy = require(ReplicatedStorage.Shared.Economy)
local Format = require(ReplicatedStorage.Shared.Format)
local Types = require(ReplicatedStorage.Shared.Types)

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

-- Takes the bundle rather than a product key, because the starter pack's bundle
-- lives under Monetisation.StarterPack and is described the same way.
local function rewardText(reward: Types.Reward): string
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

-- The offline deal with the pass and without it, pulled out so the line selling
-- it can put the two side by side rather than asserting that one is better.
local OFFLINE_HOURS, OFFLINE_RATE = Economy.offlineHours(false), Economy.offlineRate(false)
local AUTO_HOURS, AUTO_RATE = Economy.offlineHours(true), Economy.offlineRate(true)

-- `Offer` marks a pass that is only on sale for a while. There is one, and the
-- server decides whether it is still on: the panel never works the window out
-- for itself, or a clock an hour out would keep selling something expired.
--
-- Annotated because the entries differ in shape, and Luau would otherwise infer
-- the whole list from the first one -- which is the one with the Offer on it.
type PassEntry = {
	Key: string,
	Title: string,
	Description: string,
	Offer: boolean?,
}

local PASSES: { PassEntry } = {
	{
		Key = "StarterPack",
		Title = "Starter Pack",
		Description = rewardText(Monetisation.StarterPack.Reward),
		Offer = true,
	},
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
	{
		Key = "LuckCharm",
		Title = "Lucky Forever",
		Description = "The lucky charm, permanently — better drops with no clock and no Gems.",
	},
	{
		Key = "AutoCollect",
		Title = "Auto Collect",
		Description = `Away time pays {AUTO_RATE}x for up to {AUTO_HOURS}h, not {OFFLINE_RATE}x for {OFFLINE_HOURS}h.`,
	},
	{
		Key = "CraftSlot",
		Title = "Second Slot",
		Description = `Run {Economy.craftSlots(Monetisation.ExtraCraftSlots)} crafts at once instead of {Economy.craftSlots()}.`,
	},
	{
		Key = "BiggerGarden",
		Title = "Bigger Garden",
		Description = `Room for {Monetisation.BiggerGardenSpaces} more {Theme.Text.UnitPlural}, past the last upgrade.`,
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
		local card =
			Components.card({ Size = UDim2.new(1, -12, 0, 80), LayoutOrder = order, Pattern = true, Parent = list })
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
		return card, button
	end

	-- The timed offer's card and the line that counts it down, kept so `update`
	-- can show, hide and re-time it. nil when the pass has no ID set up.
	local offerCard: Frame? = nil
	local offerNote: TextLabel? = nil

	for _, pass in PASSES do
		local id = Config.Settings.GamePasses[pass.Key]
		if id ~= 0 then
			local card, button = addEntry(pass.Title, pass.Description, id, Enum.InfoType.GamePass, function()
				MarketplaceService:PromptGamePassPurchase(LocalPlayer, id)
			end)
			passButtons[pass.Key] = button
			if pass.Offer then
				offerCard = card
				-- Hidden until the server says the offer is live, rather than
				-- shown and then withdrawn: a card that appears for one frame and
				-- vanishes reads as a bug, and an expired offer must never be
				-- clickable at all. A UIListLayout skips invisible children, so
				-- hiding it closes the gap too.
				card.Visible = false
				card.Size = UDim2.new(1, -12, 0, 104)
				card.BackgroundColor3 = Palette.Secondary
				offerNote = Components.label({
					Text = "",
					Size = UDim2.new(1, -24, 0, 24),
					Position = UDim2.fromOffset(12, 74),
					TextXAlignment = Enum.TextXAlignment.Left,
					TextColor3 = Palette.Accent,
					MaxTextSize = 18,
					Parent = card,
				})
			end
		end
	end

	for key, id in Config.Settings.Products do
		if id ~= 0 and Monetisation.ProductRewards[key] then
			local text = rewardText(Monetisation.ProductRewards[key])
			addEntry(PRODUCT_TITLES[key] or key, text, id, Enum.InfoType.Product, function()
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

	local latest: { [string]: any }? = nil

	-- The offer's own clock. Counted down from the server's end time in game
	-- time, so the player's clock being wrong can't extend or shorten it, and the
	-- card disappears the moment the window closes even if no snapshot lands.
	local function renderOffer()
		local snapshot = latest
		local card, note = offerCard, offerNote
		if not (snapshot and card and note) then
			return
		end
		local remaining = math.max((snapshot.StarterEndsAt or 0) - Workspace:GetServerTimeNow(), 0)
		card.Visible = snapshot.StarterOffered == true and remaining > 0
		note.Text = `Your first day only — {Format.time(math.ceil(remaining))} left!`
	end

	local function update(snapshot: { [string]: any })
		latest = snapshot
		local passes = snapshot.Passes or {}
		for key, button in passButtons do
			if passes[key] then
				button.setText("Owned")
				button.setEnabled(false)
			end
		end
		renderOffer()
	end

	-- Once a second, not every frame: the only thing moving is a clock measured
	-- in hours, and the panel is often open with nothing else changing.
	if offerCard then
		local elapsed = 0
		local connection: RBXScriptConnection
		connection = RunService.Heartbeat:Connect(function(delta)
			if not panel.Content.Parent then
				connection:Disconnect()
				return
			end
			elapsed += delta
			if elapsed >= 1 and panel.isOpen() then
				elapsed = 0
				renderOffer()
			end
		end)
	end

	return {
		setOpen = panel.setOpen,
		isOpen = panel.isOpen,
		update = update,
	}
end

return Shop
