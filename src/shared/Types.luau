--!strict
-- Shared type definitions. Every theme in Shared/Themes must satisfy `Theme`;
-- saved player data follows `PlayerData`.

export type UnitDef = {
	Name: string,
	Color: Color3,
	-- Name of a Model under ReplicatedStorage.ThemeAssets.Units. When nil or not
	-- found, a procedural squishy blob in `Color` is built instead.
	Model: string?,
	Scale: number?,
	-- Set by Config on the units it appends for the theme's sparkles, so the
	-- visuals know to build a glowing one. Themes don't set this.
	Sparkle: boolean?,
}

-- A limited-edition unit, made at the crafting station and never dropped or
-- merged. `Band` is the range of ordinary tiers that can be fed in to play for
-- it: feeding the top of that band, and filling every slot, is what takes the
-- odds up to `MaxChance`.
export type SparkleDef = {
	Id: string,
	Name: string,
	Color: Color3,
	Model: string?,
	Scale: number?,
	Band: { number },
	-- Permanent share added to the player's cash multiplier while this one is
	-- lying in their garden. 0.1 is "+10% of everything, forever".
	Bonus: number,
	-- Best odds this one can ever be crafted at. Later bands set this lower, so
	-- the deeper sparkles stay rarer. Defaults to Balance.Craft.MaxChance.
	MaxChance: number?,
}

-- A piece of scenery. Same deal as UnitDef: a theme can point at a real model,
-- and anything it doesn't supply is built from parts in the theme's colours, so
-- a new skin looks right before any asset exists for it.
export type PropDef = {
	-- Name of a Model under ReplicatedStorage.ThemeAssets.Props. When nil or not
	-- found, `Shape` is built instead.
	Model: string?,
	-- One of the shapes PropVisuals knows: Cane, Lollipop, Cone, Stack, Sphere.
	Shape: string?,
	Color: Color3,
	-- Second colour, for stripes and trim. Defaults to white.
	Accent: Color3?,
	-- Studs tall. Ignored by supplied models, which use `Scale` instead.
	Height: number?,
	Scale: number?,
}

export type Palette = {
	Primary: Color3,
	Secondary: Color3,
	Accent: Color3,
	Background: Color3,
	Surface: Color3,
	Text: Color3,
	TextMuted: Color3,
	Positive: Color3,
	Negative: Color3,
}

export type Theme = {
	Id: string,
	DisplayName: string,
	-- Words the UI uses, so a reskin can call cash "Goo" or rebirths "Evolve".
	Text: {
		Currency: string,
		Unit: string,
		UnitPlural: string,
		Rebirth: string,
		Bin: string,
		-- The crafting station in the hub, and what it makes.
		Machine: string,
		Sparkle: string,
		SparklePlural: string,
	},
	-- Short glyphs (emoji work) shown beside stats and on upgrade tiles.
	Icons: {
		Currency: string?,
		Gems: string?,
		Boost: string?,
		SpawnTier: string?,
		SpawnSpeed: string?,
		GardenSpace: string?,
		Luck: string?,
		Income: string?,
		Craft: string?,
	},
	Font: Font,
	-- Optional artwork. Anything left unset is drawn from the palette instead,
	-- so a theme works with no uploaded assets at all.
	Images: {
		-- Face of the prize wheel. Must be a circle divided into as many equal
		-- segments as Balance.Wheel.Prizes, with segment 1 centred at the top.
		Wheel: string?,
	}?,
	Palette: Palette,
	World: {
		-- Ground outside the gardens; PlotBase is the garden floor itself.
		Ground: Color3,
		GroundMaterial: Enum.Material,
		PlotBase: Color3,
		PlotMaterial: Enum.Material,
		Fence: Color3,
		FenceMaterial: Enum.Material,
		Border: Color3,
		-- The hub pad and the moving walkway ringing it.
		Hub: Color3,
		Path: Color3,
		PathMaterial: Enum.Material,
	},
	Sounds: {
		Merge: string?,
		Spawn: string?,
		Purchase: string?,
		Rebirth: string?,
		Error: string?,
		Music: string?,
	},
	-- Index = tier. Tier 1 spawns first; merging two tier N units makes tier N + 1.
	Units: { UnitDef },
	-- The crafting station's prizes, lowest band first. A theme with none still
	-- gets a working machine: it just trades units up a few tiers.
	Sparkles: { SparkleDef }?,
	-- Scenery, keyed by the zone Ids in Balance.PropZones. Each slot in a zone
	-- picks one of that zone's entries at random. A zone the theme says nothing
	-- about is left bare, and a theme with no Props at all dresses no scenery.
	Props: { [string]: { PropDef } }?,
	-- Optional partial overrides of Shared/Balance, deep-merged over the defaults.
	Balance: { [string]: any }?,
}

export type DailyState = {
	Streak: number,
	LastClaimDay: number,
}

-- What's loaded into the crafting station. Inputs sit there until the craft is
-- started, and are locked in once it is. EndsAt is os.time(), not game time, so
-- a craft runs down while the player is away -- which is the whole point of it.
export type CraftState = {
	Inputs: { number },
	EndsAt: number,
}

export type PlayerData = {
	Cash: number,
	-- Premium currency, spent only on the timed earning boost.
	Gems: number,
	-- os.time() the earning boost and the luck charm run out; 0 when they have
	-- never been bought. Real time, so neither pauses while the player is away.
	BoostEndsAt: number,
	LuckEndsAt: number,
	-- Tiers of the items lying in the garden. These earn income; order is not meaningful.
	Items: { number },
	-- Tier the player is carrying, or 0 for empty-handed. Carried items don't earn.
	Carried: number,
	Upgrades: { [string]: number },
	UnitsBought: number,
	Rebirths: number,
	TotalEarned: number,
	HighestTier: number,
	LastOnline: number,
	Daily: DailyState,
	-- Wheel spins bought with gems, and the day the last free spin was taken.
	Spins: number,
	LastFreeSpinDay: number,
	-- Recent developer product receipt IDs, so a retried receipt is never granted twice.
	PurchaseIds: { string },
	Craft: CraftState,
	-- How many of each sparkle the player has ever made, keyed by SparkleDef.Id.
	-- The collection record: what's in the garden can change, this can't.
	Sparkles: { [string]: number },
}

-- A bundle of rewards (daily rewards, dev products). Cash is "minutes of the
-- player's current income", floored at MinCash.
export type Reward = {
	IncomeMinutes: number?,
	MinCash: number?,
	UnitTierBonus: number?,
	Gems: number?,
}

export type WheelPrize = {
	Label: string,
	Weight: number,
	-- Names a Palette entry, so the theme colours the wheel.
	Tone: string,
	Reward: Reward,
}

return nil
