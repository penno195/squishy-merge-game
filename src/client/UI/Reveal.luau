--!strict
-- The two moments the game stops and shows you what you just got: the prize off
-- the wheel, and the pet out of an egg.
--
-- Both are the same shape -- a dimmed screen, a card that pops in, and a button
-- to take it away -- because they are the same beat, and a game that celebrates
-- two things two different ways reads as two games. The pop is a Back ease on a
-- UIScale rather than on the card's size: scaling the frame itself relays every
-- child on every frame of the tween, and the text inside jitters as it goes.
--
-- The egg is the one that has to be worked for. It takes three taps, it moves
-- when hit and it cracks a little further each time, because an egg that opens
-- the moment you buy it is a receipt; the taps are what turn it into an event.
-- Nothing here decides anything: the server has already chosen the pet and said
-- so, and this is a ceremony performed over an answer that is in already.

local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Components = require(script.Parent.Components)
local Config = require(ReplicatedStorage.Shared.Config)
local Sound = require(script.Parent.Sound)
local Types = require(ReplicatedStorage.Shared.Types)
local UnitVisuals = require(ReplicatedStorage.Shared.UnitVisuals)

local Palette = Config.Theme.Palette
local Theme = Config.Theme

-- How long a prize card sits there before it takes itself away. Long enough to
-- read twice, short enough that nobody reaches for the button.
local PRIZE_SECONDS = 4.5
-- Taps to open an egg, and how far it lurches when one lands.
local TAPS = 3
local LURCH = 14
local POP = TweenInfo.new(0.34, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
local SHAKE = TweenInfo.new(0.09, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

local Reveal = {}

local screen: ScreenGui? = nil
-- One at a time. A second wheel spin while the first card is still up would
-- otherwise stack two cards nobody asked for, and the egg would be tappable
-- underneath.
local showing: Frame? = nil

-- A dimmed screen with an empty card on it, popped in. Returns the card and the
-- way to take it all away again.
local function stage(width: number, height: number): (Frame, () -> ())
	local parent = screen
	assert(parent, "Reveal.mount was never called")

	if showing then
		showing:Destroy()
	end

	local backdrop: Frame = Components.new("Frame", {
		Name = "Reveal",
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0.45,
		Size = UDim2.fromScale(1, 1),
		ZIndex = Components.Layer.Dialog,
		Parent = parent,
	})
	showing = backdrop

	local card: Frame = Components.card({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(width, height),
		BackgroundColor3 = Palette.Surface,
		ZIndex = Components.Layer.Dialog,
		Parent = backdrop,
	})
	Components.stroke(Palette.Accent, 3).Parent = card

	local scale: UIScale = Components.new("UIScale", { Scale = 0.55, Parent = card })
	TweenService:Create(scale, POP, { Scale = 1 }):Play()

	local function close()
		if showing == backdrop then
			showing = nil
		end
		backdrop:Destroy()
	end

	return card, close
end

-- What the wheel landed on. `description` is the server's own wording for what
-- was paid out, so the card says the same thing the toast does.
function Reveal.prize(label: string, description: string)
	local card, close = stage(360, 250)

	Components.label({
		Text = "YOU WON",
		Position = UDim2.fromOffset(0, 22),
		Size = UDim2.new(1, 0, 0, 24),
		TextColor3 = Palette.TextMuted,
		MaxTextSize = 20,
		Parent = card,
	})
	Components.label({
		Text = label,
		Position = UDim2.fromOffset(12, 54),
		Size = UDim2.new(1, -24, 0, 56),
		TextColor3 = Palette.Accent,
		Stroke = 3,
		MaxTextSize = 44,
		Parent = card,
	})
	if description ~= "" then
		Components.label({
			Text = description,
			Position = UDim2.fromOffset(16, 114),
			Size = UDim2.new(1, -32, 0, 46),
			TextWrapped = true,
			MaxTextSize = 24,
			Parent = card,
		})
	end

	Components.button({
		Text = "Collect",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -18),
		Size = UDim2.new(1, -48, 0, 54),
		BackgroundColor3 = Palette.Positive,
		Parent = card,
	}, close)

	Sound.play(Theme.Sounds.Purchase)
	-- Takes itself away, because the next spin is behind it.
	task.delay(PRIZE_SECONDS, function()
		if card.Parent then
			close()
		end
	end)
end

-- One crack across the shell, at a different angle each time so three of them
-- read as damage rather than as a pattern.
local function crack(egg: GuiObject, index: number)
	local angles = { -24, 38, 8 }
	local spots = { UDim2.fromScale(0.34, 0.3), UDim2.fromScale(0.62, 0.5), UDim2.fromScale(0.44, 0.66) }
	for step = 1, 3 do
		Components.new("Frame", {
			Name = "Crack",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = spots[index] + UDim2.fromOffset((step - 2) * 9, (step - 2) * 13),
			Size = UDim2.fromOffset(5, 20),
			BackgroundColor3 = Palette.Background,
			BorderSizePixel = 0,
			Rotation = angles[index] + (step - 2) * 26,
			ZIndex = Components.Layer.Dialog + 1,
			Parent = egg,
		})
	end
end

-- The pet itself, turning, in a ViewportFrame.
--
-- A viewport renders whatever is parented into it through a camera of its own,
-- which is how a 3D model gets into a 2D menu. Three things it needs that are
-- easy to miss: a Camera parented to the viewport *and* named as its
-- CurrentCamera, a light setting of its own since it sees none of the world's,
-- and the model placed at the origin rather than wherever it was built -- the
-- pet is made in world space and would otherwise be rendered from the far side
-- of the map.
--
-- The model turns rather than the camera. Spinning the camera round a model
-- swings its lighting with it and the pet appears to strobe; turning the model
-- under a fixed light is what makes it read as an object on a stand.
local function spinningPet(parent: Frame, record: Types.PetRecord): Model?
	local model = UnitVisuals.buildPet(record)
	if not model then
		return nil
	end

	local viewport: ViewportFrame = Components.new("ViewportFrame", {
		Name = "Pet",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 44),
		Size = UDim2.fromOffset(168, 168),
		BackgroundTransparency = 1,
		ZIndex = Components.Layer.Dialog,
		Parent = parent,
	})
	-- Its own light, brighter than the world's: the card behind it is dark and a
	-- pet lit for a night map would be a silhouette on it.
	viewport.Ambient = Color3.fromRGB(190, 180, 205)
	viewport.LightColor = Color3.fromRGB(255, 250, 245)
	viewport.LightDirection = Vector3.new(-0.4, -1, -0.6)

	local camera = Instance.new("Camera")
	camera.Parent = viewport
	viewport.CurrentCamera = camera

	model.Parent = viewport
	-- Sat on the origin, and framed by its own size so a big pet and a small one
	-- both fill the box.
	local _, size = model:GetBoundingBox()
	local reach = math.max(size.X, size.Y, size.Z)
	model:PivotTo(CFrame.new(0, 0, 0))
	camera.CFrame = CFrame.lookAt(Vector3.new(0, reach * 0.35, reach * 2.1), Vector3.new(0, 0, 0))

	local angle = 0
	local spin = RunService.RenderStepped:Connect(function(delta: number)
		angle = (angle + delta * 0.9) % (math.pi * 2)
		model:PivotTo(CFrame.Angles(0, angle, 0))
	end)
	-- The card is destroyed out from under this, so the loop has to let go with
	-- it or it runs for the rest of the session turning nothing.
	viewport.Destroying:Connect(function()
		spin:Disconnect()
	end)
	return model
end

-- The pet, once the shell is off it.
local function revealPet(card: Frame, record: Types.PetRecord, close: () -> ())
	for _, child in card:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end

	local pet = Config.PetById[record.Id]
	local rarity = pet and Config.PetRarityById[pet.Rarity]
	local tone = if rarity then (Palette :: any)[rarity.Tone] else nil

	Components.label({
		Text = "YOU HATCHED",
		Position = UDim2.fromOffset(0, 18),
		Size = UDim2.new(1, 0, 0, 22),
		TextColor3 = Palette.TextMuted,
		MaxTextSize = 18,
		Parent = card,
	})

	-- A ring behind the pet, in its rarity's colour, so the rarity is read
	-- before the label naming it is.
	local halo: Frame = Components.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 52),
		Size = UDim2.fromOffset(152, 152),
		BackgroundColor3 = if tone then tone:Lerp(Palette.Surface, 0.55) else Palette.Surface,
		BorderSizePixel = 0,
		ZIndex = Components.Layer.Dialog - 1,
		Parent = card,
	})
	Components.corner(76).Parent = halo
	Components.stroke(tone or Palette.Text, 3).Parent = halo

	if not spinningPet(card, record) then
		-- No model for this pet: the ring stands in for it rather than leaving a
		-- hole where the thing you just hatched should be.
		halo.BackgroundColor3 = if pet then pet.Color else Palette.Primary
	end

	local scale: UIScale = Components.new("UIScale", { Scale = 0.3, Parent = halo })
	TweenService:Create(scale, POP, { Scale = 1 }):Play()

	Components.label({
		Text = if pet then pet.Name else "A pet",
		Position = UDim2.fromOffset(12, 218),
		Size = UDim2.new(1, -24, 0, 40),
		TextColor3 = Palette.Accent,
		Stroke = 3,
		MaxTextSize = 34,
		Parent = card,
	})
	Components.label({
		Text = if rarity then rarity.Name else "",
		Position = UDim2.fromOffset(12, 258),
		Size = UDim2.new(1, -24, 0, 26),
		TextColor3 = tone or Palette.TextMuted,
		MaxTextSize = 22,
		Parent = card,
	})

	Components.button({
		Text = "Keep",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -18),
		Size = UDim2.new(1, -48, 0, 54),
		BackgroundColor3 = Palette.Positive,
		Parent = card,
	}, close)

	Sound.play(Theme.Sounds.Rebirth or Theme.Sounds.Purchase)
end

-- An egg to tap open. The pet is already decided; this is the ceremony.
function Reveal.egg(petId: string, variant: number?)
	local record: Types.PetRecord = { Id = petId, Variant = variant or 0 }
	local card, close = stage(330, 386)

	local prompt = Components.label({
		Text = "Tap the egg!",
		Position = UDim2.fromOffset(0, 20),
		Size = UDim2.new(1, 0, 0, 26),
		TextColor3 = Palette.TextMuted,
		MaxTextSize = 22,
		Parent = card,
	})

	local egg: TextButton = Components.new("TextButton", {
		Name = "Egg",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.56),
		Size = UDim2.fromOffset(150, 186),
		BackgroundColor3 = Color3.fromRGB(255, 250, 240),
		BorderSizePixel = 0,
		AutoButtonColor = false,
		Text = "",
		ZIndex = Components.Layer.Dialog,
		Parent = card,
	})
	-- Rounder at the bottom than the top, which is the whole difference between
	-- an egg and a pill.
	Components.corner(70).Parent = egg
	Components.stroke(Palette.Background, 3).Parent = egg
	Components.new("UIGradient", {
		Color = ColorSequence.new(Color3.fromRGB(255, 252, 248), Color3.fromRGB(236, 220, 232)),
		Rotation = 90,
		Parent = egg,
	})

	local taps = 0
	egg.Activated:Connect(function()
		if taps >= TAPS then
			return
		end
		taps += 1
		crack(egg, taps)
		Sound.play(Theme.Sounds.Merge)

		-- Knocked sideways and back, so each tap lands on something.
		local side = if taps % 2 == 0 then 1 else -1
		local knocked = TweenService:Create(egg, SHAKE, {
			Position = UDim2.new(0.5, side * LURCH, 0.56, 0),
			Rotation = side * 9,
		})
		knocked:Play()
		knocked.Completed:Connect(function()
			if egg.Parent then
				TweenService:Create(egg, SHAKE, { Position = UDim2.fromScale(0.5, 0.56), Rotation = 0 }):Play()
			end
		end)

		if taps < TAPS then
			prompt.Text = if TAPS - taps == 1 then "One more!" else `{TAPS - taps} more!`
			return
		end

		-- Open: the shell falls apart and the pet is underneath it.
		prompt.Text = ""
		local burst = TweenService:Create(
			egg,
			TweenInfo.new(0.22, Enum.EasingStyle.Back, Enum.EasingDirection.In),
			{ Size = UDim2.fromOffset(20, 24), Rotation = 24 }
		)
		burst:Play()
		burst.Completed:Connect(function()
			if card.Parent then
				revealPet(card, record, close)
			end
		end)
	end)
end

function Reveal.mount(gui: ScreenGui)
	screen = gui
end

return Reveal
