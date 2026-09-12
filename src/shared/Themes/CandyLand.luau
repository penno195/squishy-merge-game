--!strict
-- Candy Land. A full reskin of the Squishies reference theme: nothing outside
-- this file and Settings.Theme changes to switch between them.

local Types = require(script.Parent.Parent.Types)

local theme: Types.Theme = {
	Id = "CandyLand",
	DisplayName = "Candy Land Merge",

	Text = {
		Currency = "Sprinkles",
		Unit = "Candy",
		UnitPlural = "Candies",
		Rebirth = "Rebirth",
		Bin = "Wrapper Bin",
	},

	Icons = {
		Currency = "🍬",
		Gems = "💎",
		Boost = "🔥",
		SpawnTier = "⭐",
		SpawnSpeed = "⚡",
		GardenSpace = "🧁",
		Luck = "🍀",
		Income = "💰",
	},

	Font = Font.fromEnum(Enum.Font.FredokaOne),

	Palette = {
		Primary = Color3.fromRGB(255, 105, 180),
		Secondary = Color3.fromRGB(120, 215, 235),
		Accent = Color3.fromRGB(255, 215, 100),
		Background = Color3.fromRGB(70, 30, 75),
		Surface = Color3.fromRGB(112, 52, 118),
		Text = Color3.fromRGB(255, 252, 255),
		TextMuted = Color3.fromRGB(232, 196, 232),
		Positive = Color3.fromRGB(125, 230, 160),
		Negative = Color3.fromRGB(255, 95, 125),
	},

	World = {
		-- Whipped-cream ground, with a strawberry-and-mint hub on top of it.
		Ground = Color3.fromRGB(255, 232, 242),
		GroundMaterial = Enum.Material.SmoothPlastic,
		PlotBase = Color3.fromRGB(186, 240, 214),
		PlotMaterial = Enum.Material.Sand,
		Fence = Color3.fromRGB(255, 138, 168),
		FenceMaterial = Enum.Material.SmoothPlastic,
		Border = Color3.fromRGB(235, 70, 130),
		Hub = Color3.fromRGB(150, 90, 165),
		Path = Color3.fromRGB(255, 175, 205),
		PathMaterial = Enum.Material.SmoothPlastic,
	},

	Sounds = {},

	-- Scenery, keyed by the zones in Balance.PropZones. Each slot picks one of
	-- its zone's entries at random. Swap any entry for `Model = "SomeModel"` to
	-- use a real asset from ThemeAssets.Props instead of a built shape.
	Props = {
		-- Just outside the walkway: the big landmarks you see from the middle.
		HubEdge = {
			{
				Shape = "Cane",
				Height = 34,
				Color = Color3.fromRGB(235, 60, 90),
				Accent = Color3.fromRGB(255, 250, 250),
			},
			{
				Shape = "Cane",
				Height = 28,
				Color = Color3.fromRGB(120, 215, 235),
				Accent = Color3.fromRGB(255, 250, 250),
			},
			{
				Shape = "Lollipop",
				Height = 26,
				Color = Color3.fromRGB(255, 125, 205),
				Accent = Color3.fromRGB(255, 250, 250),
			},
		},
		-- Filling the wedges between neighbouring gardens.
		BetweenGardens = {
			{
				Shape = "Lollipop",
				Height = 30,
				Color = Color3.fromRGB(255, 185, 100),
				Accent = Color3.fromRGB(255, 250, 250),
			},
			{
				Shape = "Cone",
				Height = 22,
				Color = Color3.fromRGB(150, 230, 165),
				Accent = Color3.fromRGB(255, 250, 250),
			},
		},
		-- The skyline out past the gardens.
		Outer = {
			{
				Shape = "Cone",
				Height = 26,
				Color = Color3.fromRGB(180, 245, 230),
				Accent = Color3.fromRGB(255, 255, 255),
			},
			{
				Shape = "Stack",
				Height = 20,
				Color = Color3.fromRGB(255, 235, 245),
				Accent = Color3.fromRGB(250, 90, 110),
			},
			{ Shape = "Sphere", Height = 14, Color = Color3.fromRGB(175, 90, 255) },
			{
				Shape = "Cane",
				Height = 40,
				Color = Color3.fromRGB(255, 140, 165),
				Accent = Color3.fromRGB(255, 250, 250),
			},
		},
	},

	Units = {
		{ Name = "Sugar Crumb", Color = Color3.fromRGB(255, 250, 235) },
		{ Name = "Jelly Bean", Color = Color3.fromRGB(255, 140, 165) },
		{ Name = "Gumdrop", Color = Color3.fromRGB(150, 230, 165) },
		{ Name = "Lollipop", Color = Color3.fromRGB(255, 185, 100) },
		{ Name = "Candy Cane", Color = Color3.fromRGB(250, 90, 110) },
		{ Name = "Marshmallow", Color = Color3.fromRGB(255, 235, 245) },
		{ Name = "Liquorice Twist", Color = Color3.fromRGB(90, 70, 110) },
		{ Name = "Bubblegum Blob", Color = Color3.fromRGB(255, 125, 205) },
		{ Name = "Toffee Bear", Color = Color3.fromRGB(205, 140, 75) },
		{ Name = "Choc Truffle", Color = Color3.fromRGB(120, 78, 60) },
		{ Name = "Peppermint Swirl", Color = Color3.fromRGB(180, 245, 230) },
		{ Name = "Caramel Cub", Color = Color3.fromRGB(235, 175, 95) },
		{ Name = "Rock Candy Crown", Color = Color3.fromRGB(160, 200, 255) },
		{ Name = "Sherbet Star", Color = Color3.fromRGB(255, 225, 120) },
		{ Name = "Cosmic Gobstopper", Color = Color3.fromRGB(175, 90, 255) },
	},
}

return theme
