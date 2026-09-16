--!strict
-- Pets: hatching them at the egg pads in the hub, putting the equipped one out
-- to follow its player, and answering what that one is worth to everybody else.
--
-- One is equipped at a time and the rest wait in the inventory, swappable
-- whenever. That is the decision the whole system turns on: a pet is a tool you
-- pick for what you are about to do, not a number you accumulate. So the perk is
-- the reason to own one and the cash multiplier is a nudge -- see Balance.Pets.
--
-- Nothing here knows what a perk *does*. `PetService.perk` hands back a strength
-- and the service that owns the thing being affected applies it, the same way the
-- gamepasses work: the bin asks for SellBonus, the machine asks for CraftLuck, the
-- drop loop asks for DropLuck and Space. Adding a perk means teaching one service
-- about one number.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local ActionService = require(script.Parent.ActionService)
local Config = require(ReplicatedStorage.Shared.Config)
local DataService = require(script.Parent.DataService)
local Economy = require(ReplicatedStorage.Shared.Economy)
local EventService = require(script.Parent.EventService)
local Format = require(ReplicatedStorage.Shared.Format)
local HubService = require(script.Parent.HubService)
local Net = require(ReplicatedStorage.Shared.Net)
local StateService = require(script.Parent.StateService)
local Types = require(ReplicatedStorage.Shared.Types)
local UnitVisuals = require(ReplicatedStorage.Shared.UnitVisuals)

local Balance = Config.Balance
local Theme = Config.Theme

-- Where pets live in the world. Not inside the character: a pet there was welded
-- to it, which pinned it rigidly to the player -- up with every jump, swung round
-- with every turn. Out here it is anchored, and every client walks every pet
-- along behind its owner itself (PetController), which is smooth for everyone
-- and costs the server nothing per frame.
local FOLDER_NAME = "Pets"

local PetService = {}

-- Each player's pet in the world, so equipping can take the old one off.
local attached: { [Player]: Model } = {}

local function petFolder(): Folder
	local existing = Workspace:FindFirstChild(FOLDER_NAME)
	if existing and existing:IsA("Folder") then
		return existing
	end
	local folder = Instance.new("Folder")
	folder.Name = FOLDER_NAME
	folder.Parent = Workspace
	return folder
end

local function clearPet(player: Player)
	local model = attached[player]
	if model then
		model:Destroy()
		attached[player] = nil
	end
end

-- Rebuilds whatever is equipped. Called on join and on every equip. Not on
-- respawn: the pet isn't part of the character, so it outlives one, and a player
-- with no character yet gets their pet anyway -- the client leaves it where it
-- stands until there is someone to follow.
local function showPet(player: Player)
	clearPet(player)
	local data = DataService.get(player)
	if not data then
		return
	end
	local record = Economy.equippedPet(data)
	if not record then
		return
	end
	local model = UnitVisuals.buildPet(record)
	if not model then
		return
	end
	-- Scenery to physics and to raycasts, so it never trips a player and the
	-- floor check that keeps pets on the ground never lands on another pet.
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.Anchored = true
			descendant.CanCollide = false
			descendant.CanQuery = false
			descendant.CanTouch = false
		end
	end
	-- Started where the player is, so it doesn't glide in from wherever it was
	-- built. The client snaps a pet that far away anyway; this is for the frame
	-- before it does.
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		model:PivotTo(CFrame.new(root.Position))
	end
	model:SetAttribute("OwnerId", player.UserId)
	-- The server never moves it again, so a streaming client must not drop it for
	-- being out of range of where the server left it.
	model.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
	CollectionService:AddTag(model, UnitVisuals.PetTag)
	model.Parent = petFolder()
	attached[player] = model
end

local function atPad(player: Player, eggId: string): boolean
	local position = HubService.eggPosition(eggId)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not (position and root and root:IsA("BasePart")) then
		return false
	end
	local delta = position - root.Position
	return Vector2.new(delta.X, delta.Z).Magnitude <= Balance.Pets.PadRadius
end

local function hatch(player: Player, eggId: unknown)
	local data = DataService.get(player)
	if not data or typeof(eggId) ~= "string" then
		return
	end
	local egg = Economy.eggById(eggId :: string)
	if not egg then
		return
	end
	if #Config.Pets == 0 then
		return
	end
	if Economy.petsFull(data) then
		StateService.notify(player, `You can only keep {Economy.maxOwnedPets()} pets -- release one first.`, "Error")
		return
	end
	if not atPad(player, egg.Id) then
		StateService.notify(player, `Stand at the {egg.Name} to hatch one.`, "Error")
		return
	end
	if data.Cash < egg.Cost then
		StateService.notify(player, `A {egg.Name} costs {Format.number(egg.Cost)} {Theme.Text.Currency}.`, "Error")
		return
	end

	-- Rolled before the cash is taken, so a roll that somehow fails costs nothing.
	-- Config has already refused a theme where a rarity an egg can reach has no
	-- pets, which is the only way this returns nil.
	local record = Economy.rollEgg(egg, data, PetService.dropLuck(player), EventService.strength("HatchLuck"))
	if not record then
		warn(`Egg "{egg.Id}" rolled a rarity with no pet in it`)
		return
	end
	data.Cash -= egg.Cost
	table.insert(data.Pets, record)
	-- Equipped straight away if nothing is, so a first pet is following you
	-- without a trip to the panel. A player who has chosen one keeps it.
	local first = data.EquippedPet == 0
	if first then
		data.EquippedPet = #data.Pets
	end
	StateService.markDirty(player)
	if first then
		showPet(player)
	end

	local def = Economy.petDef(record.Id) :: Types.PetDef
	local rarity = Economy.petRarityOf(record.Id) :: Types.PetRarity
	local perk = Economy.petPerkDef(def.Perk)
	StateService.notify(
		player,
		`{rarity.Name} {Economy.petName(record)}! {if perk then perk.Description else ""}`,
		if record.Variant > 0 then "Discovery" else "Reward"
	)
	Net.event("PetHatched"):FireClient(player, record.Id, record.Variant)
	ActionService.fire(player, "PetHatched", {
		Value = egg.Cost,
		CashSpent = egg.Cost,
		Fields = { Egg = egg.Id, Pet = record.Id, Rarity = def.Rarity },
	})
end

local function equip(player: Player, index: unknown)
	local data = DataService.get(player)
	if not data or typeof(index) ~= "number" then
		return
	end
	local slot = index :: number
	if slot % 1 ~= 0 or slot < 0 or slot > #data.Pets then
		return
	end
	-- 0 is "take it off", which is a thing a player might want: no pet is the only
	-- way to see the garden's own numbers.
	if slot == data.EquippedPet then
		return
	end
	data.EquippedPet = slot
	StateService.markDirty(player)
	showPet(player)
end

local function release(player: Player, index: unknown)
	local data = DataService.get(player)
	if not data or typeof(index) ~= "number" then
		return
	end
	local slot = index :: number
	if slot % 1 ~= 0 or slot < 1 or slot > #data.Pets then
		return
	end
	local record = data.Pets[slot]
	local name = Economy.petName(record)
	table.remove(data.Pets, slot)
	-- The equipped index moves with the list. Releasing the equipped pet leaves
	-- nothing equipped rather than promoting its neighbour, which would put a
	-- different pet following you for pressing Release on this one.
	if data.EquippedPet == slot then
		data.EquippedPet = 0
	elseif data.EquippedPet > slot then
		data.EquippedPet -= 1
	end
	StateService.markDirty(player)
	showPet(player)
	StateService.notify(player, `Released {name}.`, "Info")
	ActionService.fire(player, "PetReleased", { Fields = { Pet = record.Id } })
end

-- What the equipped pet is worth, for the services that own the thing affected.
-- Every one of these answers "nothing" for a player with no pet or the wrong pet,
-- so no caller has to check first.

function PetService.cashMultiplier(player: Player): number
	local data = DataService.get(player)
	return if data then Economy.petCashMultiplier(data) else 1
end

function PetService.perk(player: Player, perkId: string): number
	local data = DataService.get(player)
	return if data then Economy.petPerkValue(data, perkId) else 0
end

function PetService.dropLuck(player: Player): number
	return PetService.perk(player, "DropLuck")
end

-- Whole spaces only: half a space in a garden is not a thing.
function PetService.extraSpaces(player: Player): number
	return math.floor(PetService.perk(player, "Space"))
end

function PetService.addPlayer(player: Player)
	showPet(player)
end

function PetService.removePlayer(player: Player)
	clearPet(player)
end

function PetService.init()
	Net.event("EquipPet").OnServerEvent:Connect(equip)
	Net.event("ReleasePet").OnServerEvent:Connect(release)
	-- Hatching is asked for by the egg panel's button, not by the pad's prompt --
	-- the prompt opens the panel, so the odds and what is inside are seen before any
	-- cash changes hands. The distance check in `hatch` is what still ties it to the
	-- pad: the panel can be left open and walked away from.
	Net.event("HatchEgg").OnServerEvent:Connect(hatch)

	-- Not left to onReleasing alone. A player whose data never loaded never gets
	-- there, and a pet is out in the world now rather than going with the character.
	Players.PlayerRemoving:Connect(clearPet)
end

return PetService
