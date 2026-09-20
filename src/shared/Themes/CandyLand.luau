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
		Machine = "Candy Mixer",
		Sparkle = "Sparkle",
		SparklePlural = "Sparkles",
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
		Craft = "✨",
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
		FenceStripe = Color3.fromRGB(255, 252, 255),
		Border = Color3.fromRGB(235, 70, 130),
		Hub = Color3.fromRGB(150, 90, 165),
		Path = Color3.fromRGB(255, 175, 205),
		PathMaterial = Enum.Material.SmoothPlastic,
		PathStones = {
			Color3.fromRGB(255, 145, 185),
			Color3.fromRGB(170, 240, 195),
			Color3.fromRGB(255, 225, 130),
			Color3.fromRGB(120, 215, 235),
			Color3.fromRGB(200, 165, 245),
		},
	},

	Sounds = {
		-- Every one of these is optional; unset is silent. The Taco Rain event's
		-- song is the artist's own upload of it -- Roblox's library, public, so it
		-- is cleared for use. Anything put here has to be, and a reupload of a
		-- commercial track is not.
		TacoRain = "rbxassetid://142376088",
	},

	-- "Taco" by slyslush, a public-domain catalogue model.
	TacoRainModel = 10615433240,

	-- The big top over the hub, in the strawberry and cream the rest of the map
	-- is trimmed in.
	Canopy = {
		Stripe = Color3.fromRGB(235, 70, 130),
		StripeAlt = Color3.fromRGB(255, 252, 255),
		Pole = Color3.fromRGB(255, 252, 255),
		PoleBand = Color3.fromRGB(255, 138, 168),
		Trim = Color3.fromRGB(255, 215, 100),
		Bulbs = {
			Color3.fromRGB(255, 145, 185),
			Color3.fromRGB(120, 215, 235),
			Color3.fromRGB(255, 225, 130),
			Color3.fromRGB(170, 240, 195),
			Color3.fromRGB(200, 165, 245),
		},
		Flag = Color3.fromRGB(120, 215, 235),
	},

	-- Scenery, keyed by the zones in Balance.PropZones. Each slot picks one of
	-- its zone's entries at random. Swap any entry for `Model = "SomeModel"` to
	-- use a real asset from ThemeAssets.Props instead of a built shape.
	Props = {
		-- Round the feet of the tent poles, under the roof with the stations.
		-- Sized and coloured apart so the ring doesn't read as a repeat.
		Ringside = {
			{
				Shape = "Lollipop",
				Height = 9.5,
				Color = Color3.fromRGB(255, 145, 185),
				Accent = Color3.fromRGB(255, 252, 255),
			},
			{
				Shape = "Lollipop",
				Height = 8,
				Color = Color3.fromRGB(120, 215, 235),
				Accent = Color3.fromRGB(255, 252, 255),
			},
			{
				Shape = "Blob",
				Height = 7,
				Color = Color3.fromRGB(200, 165, 245),
				Accent = Color3.fromRGB(255, 252, 255),
			},
			{
				Shape = "Blob",
				Height = 8.5,
				Color = Color3.fromRGB(170, 240, 195),
				Accent = Color3.fromRGB(255, 252, 255),
			},
			{
				Shape = "Donut",
				Height = 9,
				Color = Color3.fromRGB(235, 195, 145),
				Accent = Color3.fromRGB(255, 145, 185),
			},
		},

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
		-- Out in the open ground between the walkway and the gardens.
		Approach = {
			{
				Shape = "Cone",
				Height = 16,
				Color = Color3.fromRGB(150, 230, 165),
				Accent = Color3.fromRGB(255, 250, 250),
			},
			{
				Shape = "Lollipop",
				Height = 18,
				Color = Color3.fromRGB(255, 185, 100),
				Accent = Color3.fromRGB(255, 250, 250),
			},
			{
				Shape = "Stack",
				Height = 14,
				Color = Color3.fromRGB(255, 235, 245),
				Accent = Color3.fromRGB(250, 90, 110),
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

	-- `Features` dresses the blob from the vocabulary in UnitVisuals. This skin
	-- is mostly named after sweets rather than animals, so most rungs stay
	-- plain blobs and the ones that aren't stand out for it.
	Units = {
		{ Name = "Sugar Crumb", Color = Color3.fromRGB(255, 250, 235) },
		{ Name = "Jelly Bean", Color = Color3.fromRGB(255, 140, 165) },
		{ Name = "Gumdrop", Color = Color3.fromRGB(150, 230, 165) },
		{ Name = "Lollipop", Color = Color3.fromRGB(255, 185, 100) },
		{ Name = "Candy Cane", Color = Color3.fromRGB(250, 90, 110) },
		{ Name = "Marshmallow", Color = Color3.fromRGB(255, 235, 245) },
		{ Name = "Liquorice Twist", Color = Color3.fromRGB(90, 70, 110) },
		{ Name = "Bubblegum Blob", Color = Color3.fromRGB(255, 125, 205) },
		{ Name = "Toffee Bear", Color = Color3.fromRGB(205, 140, 75), Features = { "RoundEars", "Snout" } },
		{ Name = "Choc Truffle", Color = Color3.fromRGB(120, 78, 60) },
		{ Name = "Peppermint Swirl", Color = Color3.fromRGB(180, 245, 230) },
		{
			Name = "Caramel Cub",
			Color = Color3.fromRGB(235, 175, 95),
			Features = { "RoundEars", "Snout", "Tail" },
		},
		{ Name = "Rock Candy Crown", Color = Color3.fromRGB(160, 200, 255), Features = { "Crown" } },
		{ Name = "Sherbet Star", Color = Color3.fromRGB(255, 225, 120), Features = { "Star" } },
		{ Name = "Cosmic Gobstopper", Color = Color3.fromRGB(175, 90, 255), Features = { "Ring" } },
		{ Name = "Candy Floss Cloud", Color = Color3.fromRGB(255, 200, 235), Features = { "Fluff" } },
		{
			Name = "Fudge Fox",
			Color = Color3.fromRGB(170, 105, 65),
			Features = { "CatEars", "Snout", "Tail" },
		},
		{
			Name = "Praline Panda",
			Color = Color3.fromRGB(240, 215, 180),
			Features = { "RoundEars", "Patches", "Snout" },
		},
		{ Name = "Nougat Knight", Color = Color3.fromRGB(235, 225, 195) },
		{ Name = "Macaron Moth", Color = Color3.fromRGB(255, 175, 210), Features = { "Wings" } },
		{
			Name = "Honeycomb Hart",
			Color = Color3.fromRGB(255, 200, 70),
			Features = { "RoundEars", "Snout", "Tail" },
		},
		{ Name = "Sherbet Serpent", Color = Color3.fromRGB(150, 255, 215) },
		{ Name = "Brittle Basilisk", Color = Color3.fromRGB(215, 150, 70) },
		{ Name = "Truffle Titan", Color = Color3.fromRGB(95, 60, 50) },
		{ Name = "Gobstopper Golem", Color = Color3.fromRGB(150, 175, 255) },
		{ Name = "Sugarplum Seraph", Color = Color3.fromRGB(220, 150, 255), Features = { "Wings" } },
		{
			Name = "Candy Crown Dragon",
			Color = Color3.fromRGB(255, 90, 140),
			Features = { "Crown", "Wings", "Tail" },
		},
		{ Name = "Eternal Eclair", Color = Color3.fromRGB(255, 230, 190) },
		{ Name = "Infinity Icing", Color = Color3.fromRGB(235, 250, 255) },
		{
			Name = "Confection Singularity",
			Color = Color3.fromRGB(255, 255, 255),
			Features = { "Ring", "Star", "Crown" },
		},
	},

	-- What the mixer makes: one per band of three tiers, all the way up the
	-- ladder. Each is rarer and worth more to keep than the last.
	-- How this skin dresses the variants in Balance.Variants. A tint over the
	-- unit's own colour rather than a colour of its own, so a Golden Mochi still
	-- reads as a Mochi; only the rarest gets the glow, or it stops meaning much.
	Variants = {
		Shiny = { Prefix = "Shiny", Color = Color3.fromRGB(190, 240, 255), Tint = 0.4 },
		Golden = { Prefix = "Golden", Color = Color3.fromRGB(255, 205, 70), Tint = 0.62 },
		Rainbow = { Prefix = "Rainbow", Color = Color3.fromRGB(255, 130, 240), Tint = 0.7, Shine = true },
	},

	-- The same six perks, dressed as sweets. Kept to one pet per rarity-and-perk
	-- pairing the other skin has, so the two can be compared while playing: if a
	-- perk feels wrong it is the perk, not this list.
	Pets = {
		{
			Id = "Drop",
			Name = "Gumdrop Pup",
			Color = Color3.fromRGB(245, 140, 170),
			Rarity = "Common",
			Perk = "MergeCash",
			Features = { "DogEars", "Snout", "Tail" },
		},
		{
			Id = "Jelly",
			Name = "Jelly Cat",
			Color = Color3.fromRGB(180, 230, 160),
			Rarity = "Common",
			Perk = "Space",
			Features = { "CatEars", "Whiskers", "Tail" },
		},
		{
			Id = "Toffee",
			Name = "Toffee Bun",
			Color = Color3.fromRGB(215, 165, 105),
			Rarity = "Common",
			Perk = "SellBonus",
			Features = { "BunnyEars", "Fluff" },
		},
		{
			Id = "Fizz",
			Name = "Fizz Fish",
			Color = Color3.fromRGB(160, 225, 245),
			Rarity = "Common",
			Perk = "GemFind",
			Features = { "Fins", "Fluke" },
		},
		{
			Id = "Mint",
			Name = "Mint Fox",
			Color = Color3.fromRGB(150, 235, 200),
			Rarity = "Rare",
			Perk = "DropLuck",
			Features = { "DogEars", "Snout", "Tail", "Legs" },
		},
		{
			Id = "Praline",
			Name = "Praline Owl",
			Color = Color3.fromRGB(225, 190, 150),
			Rarity = "Rare",
			Perk = "CraftLuck",
			Features = { "RoundEars", "Beak", "Wings" },
		},
		{
			Id = "Nougat",
			Name = "Nougat Mole",
			Color = Color3.fromRGB(235, 220, 180),
			Rarity = "Rare",
			Perk = "Space",
			Features = { "RoundEars", "Snout", "Legs" },
		},
		{
			Id = "Sherbet",
			Name = "Sherbet Frog",
			Color = Color3.fromRGB(255, 180, 120),
			Rarity = "Rare",
			Perk = "MergeCash",
			Features = { "WideMouth", "Legs", "Patches" },
		},
		{
			Id = "Sugarglass",
			Name = "Sugarglass Moth",
			Color = Color3.fromRGB(215, 205, 255),
			Rarity = "Epic",
			Perk = "GemFind",
			Features = { "Wings", "Whiskers", "Frills" },
		},
		{
			Id = "Cinder",
			Name = "Cinder Squirrel",
			Color = Color3.fromRGB(255, 165, 110),
			Rarity = "Epic",
			Perk = "CraftLuck",
			Features = { "RoundEars", "Snout", "Tail", "Fluff" },
		},
		{
			Id = "Syrup",
			Name = "Syrup Otter",
			Color = Color3.fromRGB(205, 145, 95),
			Rarity = "Epic",
			Perk = "SellBonus",
			Features = { "RoundEars", "Whiskers", "Fluke", "Legs" },
		},
		{
			Id = "Liquorice",
			Name = "Liquorice Stag",
			Color = Color3.fromRGB(120, 110, 150),
			Rarity = "Legendary",
			Perk = "DropLuck",
			Features = { "Crown", "Snout", "Legs", "Tail" },
		},
		{
			Id = "Candyfloss",
			Name = "Candyfloss Whale",
			Color = Color3.fromRGB(255, 190, 235),
			Rarity = "Legendary",
			Perk = "MergeCash",
			Features = { "Ring", "Fluke", "Fins" },
		},
	},

	Sparkles = {
		{
			Id = "CherrySparkle",
			Name = "Cherry Sparkle",
			Color = Color3.fromRGB(255, 70, 110),
			Band = { 1, 3 },
			Bonus = 0.1,
			MaxChance = 0.5,
		},
		{
			Id = "ToffeeSparkle",
			Name = "Toffee Sparkle",
			Color = Color3.fromRGB(255, 175, 70),
			Band = { 4, 6 },
			Bonus = 0.12,
			MaxChance = 0.48,
		},
		{
			Id = "HoneySparkle",
			Name = "Honey Sparkle",
			Color = Color3.fromRGB(255, 210, 95),
			Band = { 7, 9 },
			Bonus = 0.15,
			MaxChance = 0.45,
		},
		{
			Id = "AppleSparkle",
			Name = "Apple Sparkle",
			Color = Color3.fromRGB(140, 240, 150),
			Band = { 10, 12 },
			Bonus = 0.18,
			MaxChance = 0.42,
		},
		{
			Id = "MintSparkle",
			Name = "Mint Sparkle",
			Color = Color3.fromRGB(150, 250, 215),
			Band = { 13, 15 },
			Bonus = 0.22,
			MaxChance = 0.4,
		},
		{
			Id = "BlueberrySparkle",
			Name = "Blueberry Sparkle",
			Color = Color3.fromRGB(120, 165, 255),
			Band = { 16, 18 },
			Bonus = 0.26,
			MaxChance = 0.38,
		},
		{
			Id = "GrapeSparkle",
			Name = "Grape Sparkle",
			Color = Color3.fromRGB(155, 110, 250),
			Band = { 19, 21 },
			Bonus = 0.3,
			MaxChance = 0.36,
		},
		{
			Id = "PlumSparkle",
			Name = "Plum Sparkle",
			Color = Color3.fromRGB(190, 90, 190),
			Band = { 22, 24 },
			Bonus = 0.35,
			MaxChance = 0.34,
		},
		{
			Id = "BubblegumSparkle",
			Name = "Bubblegum Sparkle",
			Color = Color3.fromRGB(255, 130, 200),
			Band = { 25, 27 },
			Bonus = 0.42,
			MaxChance = 0.32,
		},
		{
			Id = "RainbowSparkle",
			Name = "Rainbow Sparkle",
			Color = Color3.fromRGB(255, 255, 255),
			Band = { 28, 30 },
			Bonus = 0.5,
			MaxChance = 0.3,
		},
	},
}

return theme
