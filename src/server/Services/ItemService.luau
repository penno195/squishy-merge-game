--!strict
-- Owns every item in the world: dropping them out of the sky, picking them up,
-- merging them and putting them down again. Player data follows from here.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local DataService = require(script.Parent.DataService)
local GardenService = require(script.Parent.GardenService)
local Net = require(ReplicatedStorage.Shared.Net)
local StateService = require(script.Parent.StateService)
local Types = require(ReplicatedStorage.Shared.Types)
local UnitVisuals = require(ReplicatedStorage.Shared.UnitVisuals)

local Balance = Config.Balance
local Theme = Config.Theme

-- How many random spots to try before giving up on spacing items out.
local PLACEMENT_ATTEMPTS = 12

export type Item = {
	model: Model,
	tier: number,
	position: Vector3,
}

local ItemService = {}

local items: { [Player]: { Item } } = {}
local carried: { [Player]: Model } = {}

-- Data holds only the tiers; the models are the source of truth for position.
local function syncData(player: Player)
	local data = DataService.get(player)
	local list = items[player]
	if not data or not list then
		return
	end
	local tiers = table.create(#list)
	for index, item in list do
		tiers[index] = item.tier
	end
	data.Items = tiers
	StateService.markDirty(player)
end

-- Sparkles sit above the ladder and are never "discovered": they're crafted,
-- announced by CraftService, and counted in their own collection.
local function noteDiscovery(player: Player, tier: number)
	local data = DataService.get(player)
	if data and tier <= Config.MaxTier and tier > data.HighestTier then
		data.HighestTier = tier
		-- Gems are granted here rather than through RewardService, which
		-- requires this module and so can't be required back.
		local gems = Balance.Gems.PerDiscovery
		data.Gems += gems
		StateService.markDirty(player)
		StateService.notify(
			player,
			`New {Theme.Text.Unit} discovered: {Theme.Units[tier].Name}!  +{gems} Gems`,
			"Discovery"
		)
	end
end

-- Prefer a spot that isn't on top of another item.
local function findRestCFrame(player: Player): CFrame?
	local list: { Item } = items[player] or {}
	local fallback: CFrame? = nil
	for _ = 1, PLACEMENT_ATTEMPTS do
		local candidate = GardenService.randomRestCFrame(player)
		if not candidate then
			return nil
		end
		fallback = candidate
		local clear = true
		for _, item in list do
			if (item.position - candidate.Position).Magnitude < Balance.Drop.Spacing then
				clear = false
				break
			end
		end
		if clear then
			return candidate
		end
	end
	return fallback
end

local function animateFall(model: Model, restCFrame: CFrame)
	local drop = Balance.Drop
	local value = Instance.new("CFrameValue")
	value.Value = model:GetPivot()
	value.Changed:Connect(function(current)
		if model.Parent then
			model:PivotTo(current)
		end
	end)
	local tween = TweenService:Create(
		value,
		TweenInfo.new(drop.FallSeconds, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
		{ Value = restCFrame }
	)
	tween.Completed:Connect(function()
		value:Destroy()
		if model.Parent then
			model:SetAttribute("Landed", true)
		end
	end)
	tween:Play()
end

-- Spawns an item in the garden. `falling` drops it from the sky; otherwise it
-- simply appears (used for merge results and for restoring a save).
function ItemService.dropItem(player: Player, tier: number, restCFrame: CFrame?, falling: boolean?): Item?
	local folder = GardenService.itemsFolder(player)
	local list = items[player]
	if not folder or not list then
		return nil
	end
	local rest = restCFrame or findRestCFrame(player)
	if not rest then
		return nil
	end

	local model = UnitVisuals.build(tier)
	-- The client animates items around this pose. Sending it explicitly, before
	-- the model is ever parented, is what stops an item being left hanging in
	-- mid-air: reading the replicated pivot instead can catch a falling item
	-- part-way down, because the landing position and the "Landed" attribute
	-- replicate on separate paths and don't always arrive in that order.
	model:SetAttribute("Rest", rest)
	model:SetAttribute("Landed", not falling)
	model:PivotTo(if falling then rest + Vector3.new(0, Balance.Drop.FallHeight, 0) else rest)
	model.Parent = folder
	if falling then
		animateFall(model, rest)
	end

	local item: Item = { model = model, tier = tier, position = rest.Position }
	table.insert(list, item)
	noteDiscovery(player, tier)
	syncData(player)
	return item
end

local function removeItem(player: Player, item: Item)
	local list = items[player]
	if list then
		local index = table.find(list, item)
		if index then
			table.remove(list, index)
		end
	end
	item.model:Destroy()
end

local function clearCarried(player: Player)
	local model = carried[player]
	if model then
		model:Destroy()
		carried[player] = nil
	end
end

local function attachCarried(player: Player, tier: number)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not (character and root and root:IsA("BasePart")) then
		return
	end
	clearCarried(player)
	local model = UnitVisuals.build(tier)
	model.Parent = character

	-- Held out in front of the chest. The item's own depth decides how far
	-- forward it sits, so big tiers don't clip through the player.
	local _, size = model:GetBoundingBox()
	local offset = CFrame.new(0, Balance.Hold.Height, -(size.Z / 2 + Balance.Hold.Distance))
	UnitVisuals.attachTo(model, root, offset)
	carried[player] = model
end

-- Re-creates the carried item after a respawn, since it dies with the character.
function ItemService.restoreCarried(player: Player)
	local data = DataService.get(player)
	if data and data.Carried > 0 then
		attachCarried(player, data.Carried)
	end
end

-- Every landed item within `radius`, measured on the ground plane. The caller
-- compares this against last frame's set to spot what the player just ran onto.
function ItemService.itemsWithin(player: Player, position: Vector3, radius: number): { Item }
	local list = items[player]
	if not list then
		return {}
	end
	local found = {}
	for _, item in list do
		if item.model:GetAttribute("Landed") then
			local delta = item.position - position
			if Vector2.new(delta.X, delta.Z).Magnitude <= radius then
				table.insert(found, item)
			end
		end
	end
	return found
end

function ItemService.pickUp(player: Player, item: Item)
	local data = DataService.get(player)
	if not data or data.Carried > 0 then
		return
	end
	data.Carried = item.tier
	removeItem(player, item)
	attachCarried(player, item.tier)
	syncData(player)
end

-- Carrying tier N onto a tier N item destroys both and leaves tier N+1 on the
-- ground, to be picked up again. Returns the item it left behind.
function ItemService.mergeWith(player: Player, item: Item): Item?
	local data = DataService.get(player)
	if not data or data.Carried ~= item.tier or item.tier >= Config.MaxTier then
		return nil
	end
	local pivot = item.model:GetPivot()
	local tier = item.tier + 1

	removeItem(player, item)
	clearCarried(player)
	data.Carried = 0
	local created = ItemService.dropItem(player, tier, pivot, false)
	Net.event("MergeEffect"):FireAllClients(pivot.Position, tier)
	return created
end

-- Returns the item now on the ground, so the caller can stop the player from
-- immediately running back over what they just put down.
function ItemService.dropCarried(player: Player): Item?
	local data = DataService.get(player)
	if not data or data.Carried == 0 then
		return nil
	end
	-- No capacity check: the carried item already counts against the garden,
	-- so there is always room for it to go back down.

	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local rest = if root and root:IsA("BasePart")
		then GardenService.restCFrameAt(player, root.Position)
		else findRestCFrame(player)
	if not rest then
		return nil
	end

	local tier = data.Carried
	clearCarried(player)
	data.Carried = 0
	return ItemService.dropItem(player, tier, rest, false)
end

-- Takes whatever the player is carrying out of the world and returns its unit
-- index, for the caller to pay for (the bin) or put somewhere (the crafting
-- station). Paying happens there rather than here because RewardService
-- requires this module and so can't be required back.
function ItemService.takeCarried(player: Player): number?
	local data = DataService.get(player)
	if not data or data.Carried == 0 then
		return nil
	end
	local tier = data.Carried
	clearCarried(player)
	data.Carried = 0
	syncData(player)
	return tier
end

-- Merges the first matching pair lying in the garden (the auto-merge gamepass).
function ItemService.autoMerge(player: Player): boolean
	local list = items[player]
	if not list then
		return false
	end
	local firstByTier: { [number]: Item } = {}
	for _, item in list do
		if item.tier < Config.MaxTier and item.model:GetAttribute("Landed") then
			local first = firstByTier[item.tier]
			if first then
				local pivot = first.model:GetPivot()
				local tier = item.tier + 1
				removeItem(player, first)
				removeItem(player, item)
				ItemService.dropItem(player, tier, pivot, false)
				Net.event("MergeEffect"):FireAllClients(pivot.Position, tier)
				return true
			end
			firstByTier[item.tier] = item
		end
	end
	return false
end

function ItemService.clear(player: Player)
	local folder = GardenService.itemsFolder(player)
	if folder then
		folder:ClearAllChildren()
	end
	items[player] = {}
	clearCarried(player)
end

-- Lays a save back out in the garden: positions aren't saved, so items are
-- scattered fresh each time.
function ItemService.renderFromData(player: Player, data: Types.PlayerData)
	ItemService.clear(player)
	local saved = table.clone(data.Items)
	for _, tier in saved do
		ItemService.dropItem(player, tier, nil, false)
	end
	ItemService.restoreCarried(player)
	syncData(player)
end

return ItemService
