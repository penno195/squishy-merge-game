--!strict
-- The admin panel's commands. Sold as the Admin pass; the creator of the
-- experience always has it, and so does everyone in Studio, where there is no
-- pass to buy and the panel still needs testing.
--
-- Everything is checked here, because the panel is only a suggestion: who is
-- asking, whether they're an admin, whether they're cooling down, and whether the
-- player they picked is protected. What the commands may do is in AdminCommands,
-- and none of it reaches saved data -- every effect is on a character, and every
-- one is undone on a timer or by the character going away.
--
-- A shove has to come from the player's own client, which owns their character's
-- physics, so Fling, Rocket and Trip are sent to the target to perform on
-- themselves (AdminController). Everything else happens here, where it replicates
-- to everyone.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local ActionService = require(script.Parent.ActionService)
local AdminCommands = require(ReplicatedStorage.Shared.AdminCommands)
local Config = require(ReplicatedStorage.Shared.Config)
local Net = require(ReplicatedStorage.Shared.Net)
local PassService = require(script.Parent.PassService)
local PropVisuals = require(ReplicatedStorage.Shared.PropVisuals)
local StaffService = require(script.Parent.StaffService)
local StateService = require(script.Parent.StateService)

local Theme = Config.Theme

local FOLDER_NAME = "AdminEffects"
-- The squishy that lands on a Squish: how big, how far it falls and how fast.
local SQUISH_HEIGHT = 9
local SQUISH_DROP = 40
local SQUISH_FALL_SECONDS = 0.35

local AdminService = {}

-- One effect per slot per character. A second command in the same slot undoes
-- the first before applying, so a Giant admin who is shrunk by another admin's
-- Tiny ends up tiny rather than somewhere in between -- and so every undo puts
-- back what was there before any of them.
type Active = { Token: number, Revert: () -> () }
local active: { [Model]: { [string]: Active } } = {}
local nextToken = 0

local lastCommandAt: { [Player]: number } = {}
local protectedUntil: { [Player]: number } = {}
local everyoneReadyAt = 0

function AdminService.isAdmin(player: Player): boolean
	if RunService:IsStudio() or PassService.has(player, "Admin") or StaffService.isStaff(player) then
		return true
	end
	return game.CreatorType == Enum.CreatorType.User and player.UserId == game.CreatorId
end

local function effectsFolder(): Folder
	local existing = Workspace:FindFirstChild(FOLDER_NAME)
	if existing and existing:IsA("Folder") then
		return existing
	end
	local folder = Instance.new("Folder")
	folder.Name = FOLDER_NAME
	folder.Parent = Workspace
	return folder
end

-- Runs `apply`, which returns how to undo itself, and undoes it after `seconds`
-- unless something else has taken the slot since.
local function inSlot(character: Model, slot: string, seconds: number, apply: () -> () -> ())
	local slots = active[character]
	if not slots then
		slots = {}
		active[character] = slots
		-- A character that goes away takes its effects with it; the next one is
		-- built fresh, with none of them on it.
		character.AncestryChanged:Connect(function()
			if not character:IsDescendantOf(game) then
				local gone = active[character]
				active[character] = nil
				if gone then
					for _, effect in gone do
						effect.Revert()
					end
				end
			end
		end)
	end
	local current = slots[slot]
	if current then
		slots[slot] = nil
		current.Revert()
	end
	nextToken += 1
	local token = nextToken
	slots[slot] = { Token = token, Revert = apply() }
	task.delay(seconds, function()
		local owner = active[character]
		local effect = owner and owner[slot]
		if owner and effect and effect.Token == token then
			owner[slot] = nil
			effect.Revert()
		end
	end)
end

-- R15 bodies scale through these values on the humanoid. An R6 body has none of
-- them and is left its own size -- which is why this isn't Model:ScaleTo, which
-- would also scale whatever unit the player is carrying, and then scale the next
-- one they pick up back the other way when it undid itself.
local SCALE_VALUES = { "BodyHeightScale", "BodyWidthScale", "BodyDepthScale", "HeadScale" }

local function scaleBody(humanoid: Humanoid, factors: { [string]: number }): () -> ()
	local original: { [NumberValue]: number } = {}
	for _, name in SCALE_VALUES do
		local value = humanoid:FindFirstChild(name)
		if value and value:IsA("NumberValue") then
			original[value] = value.Value
			value.Value *= factors[name] or 1
		end
	end
	return function()
		for value, before in original do
			value.Value = before
		end
	end
end

local function uniform(scale: number): { [string]: number }
	return { BodyHeightScale = scale, BodyWidthScale = scale, BodyDepthScale = scale, HeadScale = scale }
end

local function glassPart(size: Vector3, cframe: CFrame, color: Color3, parent: Instance): Part
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanQuery = false
	part.CanTouch = false
	part.Size = size
	part.CFrame = cframe
	part.Color = color
	part.Material = Enum.Material.Glass
	part.Transparency = 0.45
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = parent
	return part
end

local function freeze(character: Model, root: BasePart, seconds: number)
	inSlot(character, "Hold", seconds, function()
		local boxCFrame, boxSize = character:GetBoundingBox()
		local ice = glassPart(boxSize + Vector3.new(1, 1, 1), boxCFrame, Color3.fromRGB(170, 225, 255), effectsFolder())
		ice.Name = "Ice"
		ice.Material = Enum.Material.Ice
		ice.CanCollide = false
		root.Anchored = true
		return function()
			ice:Destroy()
			if root.Parent then
				root.Anchored = false
			end
		end
	end)
end

local function jail(character: Model, root: BasePart, seconds: number)
	inSlot(character, "Hold", seconds, function()
		local _, boxSize = character:GetBoundingBox()
		local floorY = root.Position.Y - boxSize.Y / 2
		local width, height, thickness = 9, math.max(boxSize.Y + 4, 10), 0.6
		local centre = CFrame.new(root.Position.X, floorY + height / 2, root.Position.Z)
		local cage = Instance.new("Model")
		cage.Name = "Jail"
		local tint = Color3.fromRGB(200, 230, 255)
		for _, side in { Vector3.xAxis, -Vector3.xAxis, Vector3.zAxis, -Vector3.zAxis } do
			local size = if side.X ~= 0
				then Vector3.new(thickness, height, width)
				else Vector3.new(width, height, thickness)
			glassPart(size, centre * CFrame.new(side * width / 2), tint, cage)
		end
		glassPart(Vector3.new(width, thickness, width), centre * CFrame.new(0, height / 2, 0), tint, cage)
		cage.Parent = effectsFolder()
		return function()
			cage:Destroy()
		end
	end)
end

local function squish(character: Model, root: BasePart, humanoid: Humanoid, seconds: number)
	-- A squishy from the theme, falling onto them. Built from the theme's own
	-- creature so a reskin squishes with whatever its gardens are full of, and as a
	-- blob when there isn't one.
	local palette = Theme.Palette
	local colors = { palette.Primary, palette.Secondary, palette.Accent, palette.Positive }
	local landing = CFrame.new(root.Position - Vector3.new(0, 3, 0))
	local squishy = PropVisuals.build({
		Model = Theme.CreatureModel,
		Shape = "Blob",
		Height = SQUISH_HEIGHT,
		Color = colors[math.random(#colors)],
	}, landing + Vector3.new(0, SQUISH_DROP, 0), effectsFolder())
	for _, descendant in squishy:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.CanCollide = false
			descendant.CanQuery = false
		end
	end

	local driver = Instance.new("CFrameValue")
	driver.Value = squishy:GetPivot()
	driver.Changed:Connect(function(value)
		if squishy.Parent then
			squishy:PivotTo(value)
		end
	end)
	local tween = TweenService:Create(
		driver,
		TweenInfo.new(SQUISH_FALL_SECONDS, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
		{ Value = squishy:GetPivot() - Vector3.new(0, SQUISH_DROP, 0) }
	)
	tween.Completed:Connect(function()
		driver:Destroy()
		task.delay(0.8, function()
			squishy:Destroy()
		end)
		if not character:IsDescendantOf(game) then
			return
		end
		inSlot(character, "Scale", seconds, function()
			return scaleBody(humanoid, {
				BodyHeightScale = AdminCommands.SquishHeight,
				BodyWidthScale = AdminCommands.SquishSpread,
				BodyDepthScale = AdminCommands.SquishSpread,
			})
		end)
	end)
	tween:Play()
end

local function withSpeed(character: Model, humanoid: Humanoid, seconds: number, multiplier: number?, speed: number?)
	inSlot(character, "Speed", seconds, function()
		local before = humanoid.WalkSpeed
		humanoid.WalkSpeed = speed or before * (multiplier or 1)
		return function()
			humanoid.WalkSpeed = before
		end
	end)
end

local function superJump(character: Model, humanoid: Humanoid, seconds: number)
	inSlot(character, "Jump", seconds, function()
		local power, height = humanoid.JumpPower, humanoid.JumpHeight
		humanoid.JumpPower = power * AdminCommands.JumpMultiplier
		humanoid.JumpHeight = height * AdminCommands.JumpMultiplier
		return function()
			humanoid.JumpPower = power
			humanoid.JumpHeight = height
		end
	end)
end

-- Rocket's trail, on the server so everyone watching sees the launch.
local function rocketTrail(root: BasePart, seconds: number)
	local fire = Instance.new("Fire")
	fire.Size = 6
	fire.Heat = 12
	fire.Parent = root
	task.delay(seconds, function()
		fire:Destroy()
	end)
end

local function sticky(character: Model, root: BasePart, humanoid: Humanoid, seconds: number)
	withSpeed(character, humanoid, seconds, nil, AdminCommands.StickySpeed)
	local goo = Instance.new("ParticleEmitter")
	goo.Color = ColorSequence.new(Color3.fromRGB(255, 190, 70))
	goo.Size = NumberSequence.new(0.8, 0)
	goo.Lifetime = NumberRange.new(0.5, 0.9)
	goo.Rate = 20
	goo.Speed = NumberRange.new(1, 2)
	goo.Acceleration = Vector3.new(0, -12, 0)
	goo.Parent = root
	task.delay(seconds, function()
		goo:Destroy()
	end)
end

type Body = { Character: Model, Root: BasePart, Humanoid: Humanoid }

local function bodyOf(player: Player): Body?
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if character and root and root:IsA("BasePart") and humanoid and humanoid.Health > 0 then
		return { Character = character, Root = root, Humanoid = humanoid }
	end
	return nil
end

local function onPlayer(command: AdminCommands.Command, body: Body, target: Player)
	local seconds = command.Seconds
	if command.Id == "Squish" then
		squish(body.Character, body.Root, body.Humanoid, seconds)
	elseif command.Id == "Freeze" then
		freeze(body.Character, body.Root, seconds)
	elseif command.Id == "Jail" then
		jail(body.Character, body.Root, seconds)
	elseif command.Id == "Tiny" then
		inSlot(body.Character, "Scale", seconds, function()
			return scaleBody(body.Humanoid, uniform(AdminCommands.TinyScale))
		end)
	elseif command.Id == "Sticky" then
		sticky(body.Character, body.Root, body.Humanoid, seconds)
	elseif command.Id == "Rocket" then
		rocketTrail(body.Root, seconds)
		Net.event("AdminEffect"):FireClient(target, command.Id, seconds)
	else
		-- Fling and Trip: the target's own client does the shoving.
		Net.event("AdminEffect"):FireClient(target, command.Id, seconds)
	end
end

local function onSelf(command: AdminCommands.Command, body: Body)
	local seconds = command.Seconds
	if command.Id == "Speed" then
		withSpeed(body.Character, body.Humanoid, seconds, AdminCommands.SpeedMultiplier)
	elseif command.Id == "SuperJump" then
		superJump(body.Character, body.Humanoid, seconds)
	elseif command.Id == "Giant" then
		inSlot(body.Character, "Scale", seconds, function()
			return scaleBody(body.Humanoid, uniform(AdminCommands.GiantScale))
		end)
	end
end

local function run(player: Player, commandId: unknown, targetId: unknown)
	if typeof(commandId) ~= "string" then
		return
	end
	local command = AdminCommands.ById[commandId :: string]
	if not command or not AdminService.isAdmin(player) then
		return
	end

	local now = os.clock()
	-- Staff running an event aren't held to the rules that stop a paying admin
	-- pinning a player down. Studio makes everyone staff, so the rules are only
	-- ever felt on a live server -- which is where they matter.
	local staff = StaffService.isStaff(player) and not RunService:IsStudio()
	local wait = (lastCommandAt[player] or -math.huge) + AdminCommands.Cooldown - now
	if wait > 0 and not staff then
		StateService.notify(player, `Wait {math.ceil(wait)}s before your next command.`, "Error")
		return
	end

	if command.Target == "Everyone" then
		if now < everyoneReadyAt and not staff then
			StateService.notify(
				player,
				`{command.Name} is recharging for {math.ceil(everyoneReadyAt - now)}s.`,
				"Error"
			)
			return
		end
		everyoneReadyAt = now + AdminCommands.EveryoneCooldown
		lastCommandAt[player] = now
		Net.event("AdminEffect"):FireAllClients(command.Id, command.Seconds)
		for _, other in Players:GetPlayers() do
			StateService.notify(other, `{player.DisplayName} used {command.Name}!`, "Info")
		end
		ActionService.fire(player, "AdminCommand", { Fields = { Command = command.Id, Target = "Everyone" } })
		return
	end

	if command.Target == "Self" then
		local body = bodyOf(player)
		if not body then
			return
		end
		lastCommandAt[player] = now
		onSelf(command, body)
		ActionService.fire(player, "AdminCommand", { Fields = { Command = command.Id, Target = "Self" } })
		return
	end

	-- On another player. Picked by user id rather than by name: names change and
	-- two display names can match.
	if typeof(targetId) ~= "number" then
		return
	end
	local target = Players:GetPlayerByUserId(targetId :: number)
	if not target or target == player then
		return
	end
	local shieldLeft = (protectedUntil[target] or -math.huge) - now
	if shieldLeft > 0 and not staff then
		StateService.notify(
			player,
			`{target.DisplayName} was just hit -- try again in {math.ceil(shieldLeft)}s.`,
			"Error"
		)
		return
	end
	local body = bodyOf(target)
	if not body then
		StateService.notify(player, `{target.DisplayName} can't be reached right now.`, "Error")
		return
	end
	lastCommandAt[player] = now
	protectedUntil[target] = now + AdminCommands.Protection
	onPlayer(command, body, target)
	-- Named to the target. An anonymous troll is a worse experience than a named
	-- one, and it's what every admin pass in the genre does.
	StateService.notify(target, `{player.DisplayName} used {command.Name} on you!`, "Info")
	StateService.notify(player, `{command.Name} on {target.DisplayName}!`, "Reward")
	ActionService.fire(player, "AdminCommand", { Fields = { Command = command.Id, Target = "Player" } })
end

function AdminService.init()
	Net.event("AdminCommand").OnServerEvent:Connect(run)

	Players.PlayerRemoving:Connect(function(player)
		lastCommandAt[player] = nil
		protectedUntil[player] = nil
	end)

	StateService.addProvider(function(player, snapshot)
		snapshot.IsAdmin = AdminService.isAdmin(player)
	end)
end

return AdminService
