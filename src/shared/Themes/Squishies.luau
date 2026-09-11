--!strict
-- Reference theme. Copy this file to start a new skin, then set Settings.Theme.

local Types = require(script.Parent.Parent.Types)

local theme: Types.Theme = {
	Id = "Squishies",
	DisplayName = "Squishy Merge",

	Text = {
		Currency = "Goo",
		Unit = "Squishy",
		UnitPlural = "Squishies",
		Rebirth = "Rebirth",
	},

	Icons = {},

	Font = Font.fromEnum(Enum.Font.FredokaOne),

	Palette = {
		Primary = Color3.fromRGB(255, 120, 190),
		Secondary = Color3.fromRGB(120, 200, 255),
		Accent = Color3.fromRGB(255, 220, 90),
		Background = Color3.fromRGB(45, 30, 70),
		Surface = Color3.fromRGB(70, 50, 105),
		Text = Color3.fromRGB(255, 255, 255),
		TextMuted = Color3.fromRGB(200, 185, 225),
		Positive = Color3.fromRGB(110, 230, 140),
		Negative = Color3.fromRGB(255, 95, 110),
	},

	World = {
		Ground = Color3.fromRGB(190, 230, 245),
		GroundMaterial = Enum.Material.SmoothPlastic,
		-- The garden floor inside the fence.
		PlotBase = Color3.fromRGB(150, 220, 160),
		PlotMaterial = Enum.Material.Grass,
		Fence = Color3.fromRGB(225, 160, 120),
		FenceMaterial = Enum.Material.Wood,
		Border = Color3.fromRGB(255, 120, 190),
	},

	Sounds = {},

	Units = {
		{ Name = "Droplet", Color = Color3.fromRGB(150, 220, 255) },
		{ Name = "Jellybean", Color = Color3.fromRGB(255, 150, 170) },
		{ Name = "Gumdrop", Color = Color3.fromRGB(140, 230, 150) },
		{ Name = "Mochi", Color = Color3.fromRGB(255, 240, 245) },
		{ Name = "Marshmallow", Color = Color3.fromRGB(255, 205, 150) },
		{ Name = "Puddle Pup", Color = Color3.fromRGB(190, 160, 255) },
		{ Name = "Squish Cat", Color = Color3.fromRGB(255, 180, 90) },
		{ Name = "Bouncy Bunny", Color = Color3.fromRGB(255, 130, 210) },
		{ Name = "Jelly Frog", Color = Color3.fromRGB(100, 210, 120) },
		{ Name = "Squidge Octo", Color = Color3.fromRGB(240, 100, 130) },
		{ Name = "Blobfish King", Color = Color3.fromRGB(255, 160, 180) },
		{ Name = "Cloud Sheep", Color = Color3.fromRGB(235, 245, 255) },
		{ Name = "Moon Mochi", Color = Color3.fromRGB(255, 235, 140) },
		{ Name = "Star Jelly", Color = Color3.fromRGB(120, 140, 255) },
		{ Name = "Cosmic Squish", Color = Color3.fromRGB(170, 80, 255) },
	},
}

return theme
