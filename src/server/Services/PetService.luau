--!strict
-- Pets: hatching them at the egg pads in the hub, keeping one on the player's
-- shoulder, and answering what that one is worth to everybody else.
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

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ActionService = require(script.Parent.ActionService)
local Config = require(ReplicatedStorage.Shared.Config)
local DataService = require(script.Parent.DataService)
local Economy = require(ReplicatedStorage.Shared.Economy)
local Format = require(ReplicatedStorage.Shared.Format)
local HubService = require(script.Parent.HubService)
local Net = require(ReplicatedStorage.Shared.Net)
local StateService = require(script.Parent.StateService)
local Types = require(ReplicatedStorage.Shared.Types)
local UnitVisuals = require(ReplicatedStorage.Shared.UnitVisuals)

local Balance = Config.Balance
local Theme = Config.Theme

-- Where the pet sits: up on the right shoulder and a little forward, so it reads
-- against the sky rather than against the player's own back. Built on the server
-- and welded, so every player sees everybody's pet with nothing to keep in sync.
local SHOULDER_OFFSET = CFrame.new(1.5, 1.6, -0.2)

local PetService = {}

-- The model on each player's shoulder, so equipping can take the old one off.
local attached: { [Player]: Model } = {}
local characterConnections: { [Player]: RBXScriptConnection } = {}

local function clearPet(player: Player)
	local model = attached[player]
	if model then
		model:Destroy()
		attached[player] = nil
	end
end

-- Rebuilds whatever is equipped onto the player's current character. Called on
-- join, on every equip, and on respawn -- a welded model dies with the character
-- it was welded to, the same way a carried unit does.
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
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not (root and root:IsA("BasePart")) then
		return
	end
	local model = UnitVisuals.buildPet(record)
	if not model then
		return
	end
	-- Parented before welding, like a carried unit: a model welded while still
	-- outside the DataModel keeps the pose it was built at rather than the one it
	-- was welded to.
	model.Parent = character
	UnitVisuals.attachTo(model, root, SHOULDER_OFFSET)
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
	local record = Economy.rollEgg(egg, data, PetService.dropLuck(player))
	if not record then
		warn(`Egg "{egg.Id}" rolled a rarity with no pet in it`)
		return
	end
	data.Cash -= egg.Cost
	table.insert(data.Pets, record)
	-- Equipped straight away if nothing is, so a first pet is on your shoulder
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
	-- different pet on your shoulder for pressing Release on this one.
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
	-- A welded model dies with the character, so it is rebuilt on respawn -- the
	-- same reason ItemService restores a carried unit.
	characterConnections[player] = player.CharacterAdded:Connect(function()
		task.defer(showPet, player)
	end)
end

function PetService.removePlayer(player: Player)
	clearPet(player)
	local connection = characterConnections[player]
	if connection then
		connection:Disconnect()
		characterConnections[player] = nil
	end
end

function PetService.init()
	Net.event("EquipPet").OnServerEvent:Connect(equip)
	Net.event("ReleasePet").OnServerEvent:Connect(release)
	-- The panel can ask too, but the pad's prompt is the ordinary way in.
	Net.event("HatchEgg").OnServerEvent:Connect(hatch)
	for eggId, prompt in HubService.eggPrompts() do
		prompt.Triggered:Connect(function(player)
			hatch(player, eggId)
		end)
	end

	Players.PlayerRemoving:Connect(function(player)
		attached[player] = nil
		local connection = characterConnections[player]
		if connection then
			connection:Disconnect()
			characterConnections[player] = nil
		end
	end)
end

return PetService
