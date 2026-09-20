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
		-- Grass everywhere the paths, gardens and hub aren't. The pale blue this
		-- was read as water from above, which made every gap in the map look
		-- like somewhere you shouldn't stand.
		Ground = Color3.fromRGB(126, 200, 110),
		GroundMaterial = Enum.Material.Grass,
		-- The wall round the edge of the world, papered with the mural in
		-- assets/source/textures/candy-mural.png. The colour is what shows
		-- through where the image doesn't reach, so it matches its sky.
		Wall = Color3.fromRGB(196, 226, 250),
		WallMaterial = Enum.Material.SmoothPlastic,
		WallMural = "rbxassetid://88525227539208",
		-- The garden floor inside the fence.
		PlotBase = Color3.fromRGB(150, 220, 160),
		PlotMaterial = Enum.Material.Grass,
		-- Candy cane: white rails banded in red, and posts alternating between
		-- the two. Wood is gone with it -- a striped plank reads as a deckchair,
		-- and plastic is what a stick of rock is made of. `Fence` is also the
		-- frame round the upgrade board and the name board, so those turn white
		-- with it, which suits them.
		Fence = Color3.fromRGB(255, 250, 250),
		FenceMaterial = Enum.Material.SmoothPlastic,
		FenceStripe = Color3.fromRGB(230, 60, 70),
		-- The stripe itself, uploaded from assets/source/textures/candy-stripe.png
		-- through Open Cloud on 2026-09-20. With this set the rails are one part
		-- each again; FenceStripe stays because it still colours the posts.
		--
		-- This is the *image* id, not the id Open Cloud handed back. Uploading an
		-- image gives you a Decal, which is an XML wrapper naming the image
		-- inside it, and a Texture wants the image. The wrapper's id renders as
		-- nothing at all, which looks exactly like a broken upload. To get the
		-- one you want: fetch
		-- `apis.roblox.com/asset-delivery-api/v1/assetId/<decal id>` with the API
		-- key, follow the `location` it gives back, and read the `<url>` out of
		-- the XML that downloads.
		--
		-- Roblox's *thumbnails* of both ids come back blank, in the Toolbox and
		-- over the API alike, so a white preview says nothing about whether the
		-- image is there. The stored file is the thing to check.
		FenceTexture = "rbxassetid://132356211694074",
		Border = Color3.fromRGB(255, 120, 190),
		-- The hub pad and the walkway ringing it.
		Hub = Color3.fromRGB(95, 70, 135),
		-- The slab under the cobbles, which is what shows between them.
		Path = Color3.fromRGB(150, 130, 200),
		PathMaterial = Enum.Material.SmoothPlastic,
		-- Sweets and squares of chocolate, mixed. The two browns are what keep it
		-- from going to sugar: a path of nothing but pastels reads as a quilt.
		PathTiles = {
			Color3.fromRGB(255, 150, 200),
			Color3.fromRGB(160, 240, 190),
			Color3.fromRGB(255, 235, 140),
			Color3.fromRGB(150, 215, 255),
			Color3.fromRGB(205, 170, 255),
			Color3.fromRGB(255, 190, 160),
			Color3.fromRGB(120, 78, 55),
			Color3.fromRGB(155, 105, 70),
		},
		PathKerb = Color3.fromRGB(95, 60, 42),
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

	-- Night, with stars. Drawn by `scripts/make-sky.py <dir> night` and uploaded
	-- 2026-09-20; these are the image ids, not the decal ids Open Cloud hands
	-- back. The stars are points in space projected onto whichever faces they
	-- land on, so one sitting on an edge appears on both sides of it.
	--
	-- The tent sky this replaced is still in the script under `tent`, and the
	-- big top over the hub is unchanged -- the map is now a fairground at night
	-- rather than a fairground inside a tent.
	Sky = {
		Up = "rbxassetid://131832374471735",
		Dn = "rbxassetid://89731991702198",
		Lf = "rbxassetid://101651100776827",
		Rt = "rbxassetid://77176630302738",
		Ft = "rbxassetid://132540318890581",
		Bk = "rbxassetid://90828553152578",
	},

	-- Lit for a fairground after dark, which is not the same as lit for night.
	-- The point of a fairground at night is that everything on the ground is
	-- bright against a dark sky, so the ambient stays generous and only the sun
	-- comes down: drop the ambient to match the sky and the sweets go grey.
	-- The clock sits at midnight so Roblox draws no daylight of its own.
	Lighting = {
		ClockTime = 0,
		Brightness = 1.1,
		Ambient = Color3.fromRGB(96, 88, 126),
		OutdoorAmbient = Color3.fromRGB(118, 108, 152),
		ColorShiftTop = Color3.fromRGB(186, 196, 255),
		FogColor = Color3.fromRGB(46, 34, 74),
		FogStart = 460,
		FogEnd = 1500,
		ExposureCompensation = 0.25,
	},

	-- The big top over the hub. Pink and cream rather than the fairground's red
	-- and white: the hub pad underneath is purple, and red over purple is the
	-- one pairing in this palette that goes muddy.
	Canopy = {
		Stripe = Color3.fromRGB(255, 120, 190),
		StripeAlt = Color3.fromRGB(255, 250, 245),
		Pole = Color3.fromRGB(255, 252, 250),
		PoleBand = Color3.fromRGB(255, 120, 190),
		Trim = Color3.fromRGB(255, 220, 90),
		-- Read in turn along each string, so the run of colours repeats rather
		-- than landing at random and clumping.
		Bulbs = {
			Color3.fromRGB(255, 150, 200),
			Color3.fromRGB(150, 220, 255),
			Color3.fromRGB(255, 235, 130),
			Color3.fromRGB(160, 240, 190),
			Color3.fromRGB(205, 170, 255),
		},
		Flag = Color3.fromRGB(120, 200, 255),
	},

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
		-- Round the feet of the tent poles. Six of them at the size of a thing
		-- you walk round, kept apart so each reads on its own: these are the
		-- squishies that used to have the middle of the map to themselves, and
		-- crowded together under the roof none of them could be seen properly.
		Ringside = {
			{ Model = "SakuraSquishyBun", Squish = true, Height = 8.5, Color = Color3.fromRGB(255, 160, 190) },
			{ Model = "SakuraSquishyBun", Squish = true, Height = 7, Color = Color3.fromRGB(150, 220, 255) },
			{ Model = "SakuraSquishyBun", Squish = true, Height = 8, Color = Color3.fromRGB(150, 235, 180) },
			{ Model = "SakuraSquishyBun", Squish = true, Height = 7.5, Color = Color3.fromRGB(205, 170, 255) },
			{ Model = "Pinky", Height = 0.65, Color = Color3.fromRGB(255, 170, 205) },
			{ Model = "Bluey", Height = 4, Color = Color3.fromRGB(160, 215, 255) },
		},
		-- Ornament scale, just outside the walkway: things you walk past rather
		-- than stop at, so nothing here is taller than a couple of players. The
		-- butter lies down, because a butter stick stood on its end is a
		-- monolith -- and at a fraction of the size it was, it is a prop again.
		HubEdge = {
			{ Model = "ButterSquishy", Lay = true, Height = 16, Color = Color3.fromRGB(250, 206, 80) },
			{ Model = "SakuraSquishyBun", Squish = true, Height = 6.5, Color = Color3.fromRGB(255, 160, 190) },
			{ Model = "RubixCube", Height = 6, Color = Color3.fromRGB(255, 255, 255) },
			{
				Shape = "Donut",
				Height = 8,
				Color = Color3.fromRGB(235, 195, 145),
				Accent = Color3.fromRGB(255, 140, 200),
			},
			{ Model = "SakuraSquishyBun", Squish = true, Height = 6, Color = Color3.fromRGB(150, 220, 255) },
			{ Model = "Pinky", Height = 0.55, Color = Color3.fromRGB(255, 170, 205) },
		},
		-- Out in the open ground between the walkway and the gardens, at the
		-- size of a thing you'd stop and look at on the way home.
		Approach = {
			{ Model = "SakuraSquishyBun", Squish = true, Height = 10, Color = Color3.fromRGB(255, 200, 120) },
			{ Model = "ButterSquishy", Lay = true, Height = 24, Color = Color3.fromRGB(250, 206, 80) },
			{
				Shape = "Donut",
				Height = 12,
				Color = Color3.fromRGB(235, 195, 145),
				Accent = Color3.fromRGB(160, 230, 255),
			},
			{ Model = "Bluey", Height = 5, Color = Color3.fromRGB(160, 215, 255) },
			{
				Shape = "Stack",
				Height = 11,
				Color = Color3.fromRGB(255, 245, 250),
				Accent = Color3.fromRGB(190, 160, 255),
			},
			{ Model = "RubixCube", Height = 10, Color = Color3.fromRGB(255, 255, 255) },
		},
		-- The landmarks in the gaps between gardens. Big enough to see over the
		-- fences from the hub, small enough to leave the plinths either side of
		-- them in clear view.
		BetweenGardens = {
			{ Model = "SakuraSquishyBun", Squish = true, Height = 16.5, Color = Color3.fromRGB(190, 160, 255) },
			{ Model = "SakuraSquishyBun", Squish = true, Height = 15.5, Color = Color3.fromRGB(140, 230, 150) },
			{ Model = "ButterSquishy", Lay = true, Height = 36, Color = Color3.fromRGB(250, 206, 80) },
			{
				Shape = "Donut",
				Height = 18,
				Color = Color3.fromRGB(235, 195, 145),
				Accent = Color3.fromRGB(255, 170, 210),
			},
			{ Model = "RubixCube", Height = 15, Color = Color3.fromRGB(255, 255, 255) },
			{ Model = "Pinky", Height = 1.2, Color = Color3.fromRGB(255, 170, 205) },
		},
		-- The skyline, out past the gardens. Tall enough to read from the hub.
		Outer = {
			{
				Shape = "Donut",
				Height = 26,
				Color = Color3.fromRGB(235, 195, 145),
				Accent = Color3.fromRGB(150, 225, 255),
			},
			{ Model = "SakuraSquishyBun", Squish = true, Height = 18, Color = Color3.fromRGB(255, 180, 210) },
			{ Model = "ButterSquishy", Lay = true, Height = 48, Color = Color3.fromRGB(250, 206, 80) },
			{
				Shape = "Stack",
				Height = 24,
				Color = Color3.fromRGB(255, 245, 250),
				Accent = Color3.fromRGB(255, 170, 200),
			},
			{ Model = "Bluey", Height = 8, Color = Color3.fromRGB(160, 215, 255) },
			{ Shape = "Sphere", Height = 14, Color = Color3.fromRGB(180, 245, 225) },
			{ Model = "RubixCube", Height = 22, Color = Color3.fromRGB(255, 255, 255) },
		},
	},

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
