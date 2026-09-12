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

export type PlayerData = {
	Cash: number,
	-- Premium currency, spent only on the timed earning boost.
	Gems: number,
	-- os.time() the earning boost runs out; 0 when it has never been bought.
	-- Real time, so a boost doesn't pause while the player is away.
	BoostEndsAt: number,
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
