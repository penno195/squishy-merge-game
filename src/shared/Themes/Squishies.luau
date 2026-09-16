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
		Bin = "Compost Heap",
		Machine = "Sparkle Machine",
		Sparkle = "Sparkle",
		SparklePlural = "Sparkles",
	},

	Icons = {
		Currency = "💧",
		Gems = "💎",
		Boost = "🔥",
		SpawnTier = "⭐",
		SpawnSpeed = "⚡",
		GardenSpace = "📦",
		Luck = "🍀",
		AutoMerge = "🔁",
		Income = "💰",
		Craft = "✨",
	},

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
		-- The hub pad and the walkway ringing it.
		Hub = Color3.fromRGB(95, 70, 135),
		Path = Color3.fromRGB(150, 130, 200),
		PathMaterial = Enum.Material.SmoothPlastic,
	},

	Sounds = {},

	-- Scenery, keyed by the zones in Balance.PropZones. Nothing here is required:
	-- a theme that omits `Props` simply gets a bare map. Giant versions of the
	-- toys the game is made of -- butter sticks, blobs and donuts -- so the
	-- skyline is obviously part of the same world as the things in the gardens.
	--
	-- The squishies among them are the same bun the gardens are full of, in the
	-- colours the blobs had. A bun is wider for its height than a blob, so each
	-- is about a sixth shorter than the blob it replaced, which keeps the same
	-- footprint and the same clearance round it.
	-- They squash on the spot like the ones in the gardens, only slower.
	Props = {
		-- Ornament scale, in front of the gardens: these are things you walk
		-- past on the way in, so nothing here is taller than a couple of
		-- players. A Butter is 1.55 times as wide as it is tall, so 7 high is
		-- already 11 studs across.
		HubEdge = {
			{
				Shape = "Butter",
				Height = 7,
				Color = Color3.fromRGB(255, 226, 150),
				Accent = Color3.fromRGB(255, 252, 240),
			},
			{ Model = "SakuraSquishyBun", Squish = true, Height = 6.5, Color = Color3.fromRGB(255, 160, 190) },
			{ Model = "SakuraSquishyBun", Squish = true, Height = 6, Color = Color3.fromRGB(150, 220, 255) },
			{
				Shape = "Donut",
				Height = 8,
				Color = Color3.fromRGB(235, 195, 145),
				Accent = Color3.fromRGB(255, 140, 200),
			},
			-- Sized by `Scale` rather than `Height`, off whatever it was
			-- modelled at, which for this one is 6.4 studs long.
			{ Model = "ButterSquishy", Scale = 1.6, Color = Color3.fromRGB(250, 206, 80) },
		},
		-- Out in the open ground between the walkway and the gardens, at the
		-- size of a thing you'd stop and look at on the way home.
		Approach = {
			{ Model = "SakuraSquishyBun", Squish = true, Height = 10, Color = Color3.fromRGB(255, 200, 120) },
			{
				Shape = "Butter",
				Height = 10,
				Color = Color3.fromRGB(255, 226, 150),
				Accent = Color3.fromRGB(255, 252, 240),
			},
			{
				Shape = "Donut",
				Height = 12,
				Color = Color3.fromRGB(235, 195, 145),
				Accent = Color3.fromRGB(160, 230, 255),
			},
			{
				Shape = "Stack",
				Height = 11,
				Color = Color3.fromRGB(255, 245, 250),
				Accent = Color3.fromRGB(190, 160, 255),
			},
			{ Model = "ButterSquishy", Scale = 3, Color = Color3.fromRGB(250, 206, 80) },
		},
		-- The landmarks in the gaps between gardens. Big enough to see over the
		-- fences from the hub, small enough to leave the plinths either side of
		-- them in clear view.
		BetweenGardens = {
			{
				Shape = "Butter",
				Height = 18,
				Color = Color3.fromRGB(255, 222, 130),
				Accent = Color3.fromRGB(255, 250, 235),
			},
			{ Model = "SakuraSquishyBun", Squish = true, Height = 16.5, Color = Color3.fromRGB(190, 160, 255) },
			{ Model = "SakuraSquishyBun", Squish = true, Height = 15.5, Color = Color3.fromRGB(140, 230, 150) },
		},
		-- The skyline out past the gardens, where only the silhouette carries
		-- and nothing is in anyone's way. Capped at about 26 studs across so
		-- neighbours in the ring don't grow into each other: 24 slots out there
		-- is 34 studs of arc each.
		Outer = {
			{
				Shape = "Donut",
				Height = 26,
				Color = Color3.fromRGB(235, 195, 145),
				Accent = Color3.fromRGB(150, 225, 255),
			},
			{ Model = "SakuraSquishyBun", Squish = true, Height = 18, Color = Color3.fromRGB(255, 180, 210) },
			{
				Shape = "Butter",
				Height = 16,
				Color = Color3.fromRGB(255, 230, 160),
				Accent = Color3.fromRGB(255, 252, 240),
			},
			{
				Shape = "Stack",
				Height = 24,
				Color = Color3.fromRGB(255, 245, 250),
				Accent = Color3.fromRGB(255, 170, 200),
			},
			{ Shape = "Sphere", Height = 14, Color = Color3.fromRGB(180, 245, 225) },
		},
	},

	-- Every squishy is the one bun from the design, in its own colour and wearing
	-- its own features. Delete this line and they are all blobs again.
	CreatureModel = "SakuraSquishyBun",

	-- `Features` dresses the body from the vocabulary in UnitVisuals, so a thing
	-- called a Pup has ears and a snout and a thing called an Octo has arms. The
	-- first rungs are named after sweets rather than animals, and they stay plain
	-- on purpose: it's what makes the first animal, six merges in, feel
	-- like it was worth getting to.
	Units = {
		{ Name = "Droplet", Color = Color3.fromRGB(150, 220, 255) },
		{ Name = "Jellybean", Color = Color3.fromRGB(255, 150, 170) },
		{ Name = "Gumdrop", Color = Color3.fromRGB(140, 230, 150) },
		{ Name = "Mochi", Color = Color3.fromRGB(255, 240, 245) },
		{ Name = "Marshmallow", Color = Color3.fromRGB(255, 205, 150) },
		{
			Name = "Puddle Pup",
			Color = Color3.fromRGB(190, 160, 255),
			Features = { "DogEars", "Snout", "Tail" },
		},
		{
			Name = "Squish Cat",
			Color = Color3.fromRGB(255, 180, 90),
			Features = { "CatEars", "Whiskers", "Tail" },
		},
		{ Name = "Bouncy Bunny", Color = Color3.fromRGB(255, 130, 210), Features = { "BunnyEars", "Tail" } },
		{ Name = "Jelly Frog", Color = Color3.fromRGB(100, 210, 120), Features = { "Legs", "WideMouth" } },
		{ Name = "Squidge Octo", Color = Color3.fromRGB(240, 100, 130), Features = { "Tentacles" } },
		{
			Name = "Blobfish King",
			Color = Color3.fromRGB(255, 160, 180),
			Features = { "Crown", "Fins", "WideMouth" },
		},
		{ Name = "Cloud Sheep", Color = Color3.fromRGB(235, 245, 255), Features = { "Fluff", "RoundEars" } },
		{ Name = "Moon Mochi", Color = Color3.fromRGB(255, 235, 140) },
		{ Name = "Star Jelly", Color = Color3.fromRGB(120, 140, 255), Features = { "Star" } },
		{ Name = "Cosmic Squish", Color = Color3.fromRGB(170, 80, 255), Features = { "Ring" } },
		{ Name = "Nebula Slime", Color = Color3.fromRGB(120, 90, 220) },
		{
			Name = "Comet Kitten",
			Color = Color3.fromRGB(190, 225, 255),
			Features = { "CatEars", "Whiskers", "Tail", "Star" },
		},
		{
			Name = "Aurora Axolotl",
			Color = Color3.fromRGB(110, 255, 210),
			Features = { "Frills", "WideMouth" },
		},
		{ Name = "Meteor Mallow", Color = Color3.fromRGB(255, 140, 80) },
		{ Name = "Galaxy Gummy", Color = Color3.fromRGB(90, 60, 180), Features = { "Ring" } },
		{
			Name = "Quasar Quokka",
			Color = Color3.fromRGB(255, 105, 245),
			Features = { "RoundEars", "Snout", "WideMouth" },
		},
		{
			Name = "Eclipse Owl",
			Color = Color3.fromRGB(70, 60, 100),
			Features = { "CatEars", "Beak", "Wings" },
		},
		{
			Name = "Pulsar Panda",
			Color = Color3.fromRGB(235, 245, 255),
			Features = { "RoundEars", "Patches", "Snout" },
		},
		{
			Name = "Supernova Seal",
			Color = Color3.fromRGB(255, 200, 120),
			Features = { "Fins", "Snout", "Whiskers" },
		},
		-- The accretion disc, which is the one prop in the vocabulary that was
		-- drawn for a planet and turned out to suit this better.
		{ Name = "Black Hole Blob", Color = Color3.fromRGB(35, 25, 55), Features = { "Ring" } },
		{
			Name = "Stardust Sphinx",
			Color = Color3.fromRGB(215, 195, 255),
			Features = { "CatEars", "Whiskers", "Crown" },
		},
		{ Name = "Celestial Whale", Color = Color3.fromRGB(95, 150, 255), Features = { "Fluke", "Fins" } },
		{ Name = "Infinity Jelly", Color = Color3.fromRGB(150, 255, 245) },
		{ Name = "Eternal Squish", Color = Color3.fromRGB(255, 235, 170) },
		{
			Name = "Squish Singularity",
			Color = Color3.fromRGB(255, 255, 255),
			Features = { "Ring", "Star", "Crown" },
		},
	},

	-- Crafting prizes: one per band of three tiers, all the way up the ladder.
	-- Each is rarer than the last and worth more to keep -- the ceiling on the
	-- odds comes down as the bands climb, and the permanent bonus goes up.
	-- How this skin dresses the variants in Balance.Variants. A tint over the
	-- unit's own colour rather than a colour of its own, so a Golden Mochi still
	-- reads as a Mochi; only the rarest gets the glow, or it stops meaning much.
	Variants = {
		Shiny = { Prefix = "Shiny", Color = Color3.fromRGB(190, 240, 255), Tint = 0.4 },
		Golden = { Prefix = "Golden", Color = Color3.fromRGB(255, 205, 70), Tint = 0.62 },
		Rainbow = { Prefix = "Rainbow", Color = Color3.fromRGB(255, 130, 240), Tint = 0.7, Shine = true },
	},

	-- Pets. Each one names a rarity and a perk from Balance.Pets and is otherwise
	-- pure dressing -- a colour and a few features off the UnitVisuals vocabulary,
	-- so none of them needs a model made. The perk is the reason to own one, so the
	-- six of them are spread across the rarities rather than stacked at the top:
	-- a Common Gardener is still the pet you put on when the garden is full.
	Pets = {
		{
			Id = "Pebble",
			Name = "Pebble Pup",
			Color = Color3.fromRGB(170, 180, 195),
			Rarity = "Common",
			Perk = "MergeCash",
			Features = { "DogEars", "Snout", "Tail" },
		},
		{
			Id = "Sprout",
			Name = "Sprout Cat",
			Color = Color3.fromRGB(150, 215, 130),
			Rarity = "Common",
			Perk = "Space",
			Features = { "CatEars", "Whiskers", "Tail" },
		},
		{
			Id = "Coin",
			Name = "Coin Bun",
			Color = Color3.fromRGB(240, 210, 120),
			Rarity = "Common",
			Perk = "SellBonus",
			Features = { "BunnyEars", "Fluff" },
		},
		{
			Id = "Bubble",
			Name = "Bubble Fish",
			Color = Color3.fromRGB(150, 220, 240),
			Rarity = "Common",
			Perk = "GemFind",
			Features = { "Fins", "Fluke" },
		},
		{
			Id = "Clover",
			Name = "Clover Fox",
			Color = Color3.fromRGB(120, 200, 140),
			Rarity = "Rare",
			Perk = "DropLuck",
			Features = { "DogEars", "Snout", "Tail", "Legs" },
		},
		{
			Id = "Kettle",
			Name = "Kettle Owl",
			Color = Color3.fromRGB(200, 170, 230),
			Rarity = "Rare",
			Perk = "CraftLuck",
			Features = { "RoundEars", "Beak", "Wings" },
		},
		{
			Id = "Marble",
			Name = "Marble Mole",
			Color = Color3.fromRGB(190, 160, 140),
			Rarity = "Rare",
			Perk = "Space",
			Features = { "RoundEars", "Snout", "Legs" },
		},
		{
			Id = "Gumdrop",
			Name = "Gumdrop Frog",
			Color = Color3.fromRGB(240, 150, 190),
			Rarity = "Rare",
			Perk = "MergeCash",
			Features = { "WideMouth", "Legs", "Patches" },
		},
		{
			Id = "Prism",
			Name = "Prism Moth",
			Color = Color3.fromRGB(180, 200, 255),
			Rarity = "Epic",
			Perk = "GemFind",
			Features = { "Wings", "Whiskers", "Frills" },
		},
		{
			Id = "Ember",
			Name = "Ember Squirrel",
			Color = Color3.fromRGB(250, 150, 90),
			Rarity = "Epic",
			Perk = "CraftLuck",
			Features = { "RoundEars", "Snout", "Tail", "Fluff" },
		},
		{
			Id = "Tide",
			Name = "Tide Otter",
			Color = Color3.fromRGB(130, 180, 220),
			Rarity = "Epic",
			Perk = "SellBonus",
			Features = { "RoundEars", "Whiskers", "Fluke", "Legs" },
		},
		{
			Id = "Comet",
			Name = "Comet Stag",
			Color = Color3.fromRGB(150, 140, 230),
			Rarity = "Legendary",
			Perk = "DropLuck",
			Features = { "Crown", "Snout", "Legs", "Tail" },
		},
		{
			Id = "Orbit",
			Name = "Orbit Whale",
			Color = Color3.fromRGB(120, 150, 240),
			Rarity = "Legendary",
			Perk = "MergeCash",
			Features = { "Ring", "Fluke", "Fins" },
		},
	},

	Sparkles = {
		{
			Id = "RedSparkle",
			Name = "Red Sparkle",
			Color = Color3.fromRGB(255, 80, 95),
			Band = { 1, 3 },
			Bonus = 0.1,
			MaxChance = 0.5,
		},
		{
			Id = "AmberSparkle",
			Name = "Amber Sparkle",
			Color = Color3.fromRGB(255, 170, 60),
			Band = { 4, 6 },
			Bonus = 0.12,
			MaxChance = 0.48,
		},
		{
			Id = "GoldSparkle",
			Name = "Gold Sparkle",
			Color = Color3.fromRGB(255, 215, 90),
			Band = { 7, 9 },
			Bonus = 0.15,
			MaxChance = 0.45,
		},
		{
			Id = "GreenSparkle",
			Name = "Green Sparkle",
			Color = Color3.fromRGB(110, 240, 140),
			Band = { 10, 12 },
			Bonus = 0.18,
			MaxChance = 0.42,
		},
		{
			Id = "TealSparkle",
			Name = "Teal Sparkle",
			Color = Color3.fromRGB(90, 235, 220),
			Band = { 13, 15 },
			Bonus = 0.22,
			MaxChance = 0.4,
		},
		{
			Id = "BlueSparkle",
			Name = "Blue Sparkle",
			Color = Color3.fromRGB(105, 170, 255),
			Band = { 16, 18 },
			Bonus = 0.26,
			MaxChance = 0.38,
		},
		{
			Id = "IndigoSparkle",
			Name = "Indigo Sparkle",
			Color = Color3.fromRGB(120, 110, 255),
			Band = { 19, 21 },
			Bonus = 0.3,
			MaxChance = 0.36,
		},
		{
			Id = "VioletSparkle",
			Name = "Violet Sparkle",
			Color = Color3.fromRGB(200, 110, 255),
			Band = { 22, 24 },
			Bonus = 0.35,
			MaxChance = 0.34,
		},
		{
			Id = "RoseSparkle",
			Name = "Rose Sparkle",
			Color = Color3.fromRGB(255, 120, 190),
			Band = { 25, 27 },
			Bonus = 0.42,
			MaxChance = 0.32,
		},
		{
			Id = "PrismSparkle",
			Name = "Prism Sparkle",
			Color = Color3.fromRGB(255, 255, 255),
			Band = { 28, 30 },
			Bonus = 0.5,
			MaxChance = 0.3,
		},
	},
}

return theme
