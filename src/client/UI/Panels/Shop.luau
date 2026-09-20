--!strict
-- Robux shop: gamepasses and developer products. Entries whose ID is still 0
-- in Settings are hidden, so a new reskin shows only what it has set up.
--
-- Except in Studio, where they're shown greyed out instead. An unpublished place
-- has no IDs at all, so the rule above means this panel reads "nothing for sale
-- yet" for the whole of development and none of its layout is ever seen until the
-- day it goes live. A disabled card is honest about what it is and makes the panel
-- reviewable; nothing about it is reachable on a real server.

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

-- Whether an entry with no ID is drawn at all. See the note at the top.
local SHOW_UNSET = RunService:IsStudio()
local UNSET_TEXT = "No ID yet"

-- A card's text gets everything left of the button. The button is only ever a
-- price or a word, so it's kept narrow and the description -- the part that
-- actually sells the thing -- gets two full lines at a readable size. With the
-- text held to just over half the card it shrank to 10px to fit.
local CARD_HEIGHT = 96
local BUTTON_WIDTH = 120
local TEXT_WIDTH = -(12 + BUTTON_WIDTH + 12 + 12)

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
--
-- Kept to the facts, joined with "+": this is read on a card two lines tall, and
-- the starter pack's bundle written out as prose ran to over a hundred characters.
local function rewardText(reward: Types.Reward): string
	local parts = {}
	if reward.IncomeMinutes then
		local minutes = reward.IncomeMinutes
		local span = if minutes >= 60 and minutes % 60 == 0
			then `{minutes // 60} {if minutes == 60 then "hour" else "hours"}`
			else `{minutes} minutes`
		table.insert(parts, `{span} of {Theme.Text.Currency} income`)
	end
	if reward.Gems then
		table.insert(parts, `{reward.Gems} Gems`)
	end
	if reward.UnitTierBonus then
		-- Plain string: the braces are placeholders for fill(), not interpolation.
		table.insert(parts, fill("a {Unit} " .. reward.UnitTierBonus .. " tiers above your drops"))
	end
	return table.concat(parts, " + ")
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
		Description = "The Lucky Charm, always on — no timer and no Gems.",
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
		Key = "Admin",
		Title = "Admin Panel",
		Description = "Troll the server: squish, freeze, fling and jail other players.",
	},
	{
		Key = "BiggerGarden",
		Title = "Bigger Garden",
		Description = `Room for {Monetisation.BiggerGardenSpaces} more {Theme.Text.UnitPlural}, past the last upgrade.`,
	},
}

-- `openAdmin` opens the admin panel, for the Admin card once it's owned.
function Shop.create(parent: Instance, openAdmin: () -> ())
	local panel = Components.panel("Shop", UDim2.fromOffset(520, 480), parent)
	local list = Components.scroller({ Size = UDim2.fromScale(1, 1), Parent = panel.Content })
	Components.listLayout({ Padding = UDim.new(0, 8) }).Parent = list

	local passButtons = {}
	local order = 0
	-- Whether the server says this player is an admin, which the Admin card asks
	-- before deciding whether a press buys the panel or opens it.
	local isAdmin = false

	local function addEntry(title: string, description: string, id: number, infoType: Enum.InfoType, onBuy: () -> ())
		order += 1
		local card = Components.card({
			Size = UDim2.new(1, -12, 0, CARD_HEIGHT),
			LayoutOrder = order,
			Pattern = true,
			Parent = list,
		})
		Components.label({
			Text = title,
			Size = UDim2.new(1, TEXT_WIDTH, 0, 28),
			Position = UDim2.fromOffset(12, 8),
			TextXAlignment = Enum.TextXAlignment.Left,
			MaxTextSize = 24,
			Parent = card,
		})
		Components.label({
			Text = description,
			Size = UDim2.new(1, TEXT_WIDTH, 0, 46),
			Position = UDim2.fromOffset(12, 40),
			TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Top,
			TextColor3 = Palette.TextMuted,
			TextWrapped = true,
			MaxTextSize = 17,
			Parent = card,
		})
		local button = Components.button({
			Text = "Buy",
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -12, 0.5, 0),
			Size = UDim2.fromOffset(BUTTON_WIDTH, 56),
			BackgroundColor3 = Palette.Positive,
			Parent = card,
		}, onBuy)

		if id == 0 then
			-- Nothing to ask Roblox about and nothing to prompt, so the button
			-- says so rather than opening a purchase for asset 0.
			button.setText(UNSET_TEXT)
			button.setEnabled(false)
			return card, button
		end

		-- Show the real Robux price once Roblox answers.
		task.spawn(function()
			local ok, info = pcall(MarketplaceService.GetProductInfo, MarketplaceService, id, infoType)
			-- An admin's card says Open, and the price arriving late mustn't undo that.
			local ownAdmin = isAdmin and id == Config.Settings.GamePasses.Admin
			if ok and info and info.PriceInRobux and not ownAdmin then
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
		if id ~= 0 or SHOW_UNSET then
			local card, button = addEntry(pass.Title, pass.Description, id, Enum.InfoType.GamePass, function()
				if pass.Key == "Admin" and isAdmin then
					openAdmin()
				elseif id ~= 0 then
					MarketplaceService:PromptGamePassPurchase(LocalPlayer, id)
				end
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
				card.Size = UDim2.new(1, -12, 0, CARD_HEIGHT + 26)
				card.BackgroundColor3 = Palette.Secondary
				offerNote = Components.label({
					Text = "",
					Size = UDim2.new(1, TEXT_WIDTH, 0, 22),
					Position = UDim2.fromOffset(12, CARD_HEIGHT - 4),
					TextXAlignment = Enum.TextXAlignment.Left,
					TextColor3 = Palette.Accent,
					MaxTextSize = 18,
					Parent = card,
				})
			end
		end
	end

	for key, id in Config.Settings.Products do
		if (id ~= 0 or SHOW_UNSET) and Monetisation.ProductRewards[key] then
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
		isAdmin = snapshot.IsAdmin == true
		for key, button in passButtons do
			-- Owning the panel is a way in, not a sold-out sign. It opens for anyone
			-- the server calls an admin -- the pass, the creator, or Studio -- which
			-- is also how it's tested before its ID exists.
			if key == "Admin" then
				if isAdmin then
					button.setText("Open")
					button.setEnabled(true)
				end
			-- "Owned" would be a lie on an entry with no ID -- in Studio that's
			-- Settings.StudioPasses talking, not a purchase.
			elseif passes[key] and Config.Settings.GamePasses[key] ~= 0 then
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
