--!strict
-- Events staff can run from the staff panel. Shared, so the panel offers exactly
-- the strengths and durations the server will accept, and the HUD can name
-- whatever is running.
--
-- An event runs on every server at once and on any server that starts while it's
-- on (EventService). What each one does is applied where the thing it changes is
-- decided: drops in GameplayService, income in RewardService, hatching in
-- PetService, crafting in CraftService. Each asks EventService for a strength,
-- which is 1 when nothing is running -- so with no event on, the game is exactly
-- the game.

export type EventDef = {
	Id: string,
	Name: string,
	Icon: string,
	Description: string,
	-- The multipliers the panel offers. Each is shown as "x2", "x3" and so on.
	Strengths: { number },
}

local LiveEvents = {}

LiveEvents.List = {
	{
		Id = "DropLuck",
		Name = "Drop Luck",
		Icon = "🍀",
		-- x2 is worth one Lucky Charm for everyone, x3 two of them, and so on.
		Description = "Drops roll higher tiers",
		Strengths = { 2, 3, 5 },
	},
	{
		Id = "VariantLuck",
		Name = "Variant Luck",
		Icon = "🌈",
		Description = "Variants drop this many times as often",
		Strengths = { 2, 5, 10 },
	},
	{
		Id = "HatchLuck",
		Name = "Hatch Luck",
		Icon = "🥚",
		Description = "Each rarer pet is this much more likely",
		Strengths = { 2, 3, 5 },
	},
	{
		Id = "CraftLuck",
		Name = "Craft Luck",
		Icon = "✨",
		Description = "Better sparkle odds at the machine",
		Strengths = { 2, 3, 5 },
	},
	{
		Id = "Cash",
		Name = "Cash Boost",
		Icon = "💰",
		Description = "Everyone earns this many times as much",
		Strengths = { 2, 3, 5 },
	},
	{
		Id = "FastDrops",
		Name = "Fast Drops",
		Icon = "⚡",
		Description = "Drops arrive this many times as often",
		Strengths = { 2, 3 },
	},
} :: { EventDef }

-- Minutes the panel offers.
LiveEvents.Durations = { 15, 30, 60, 120, 240 }

-- The longest message staff can send to every server.
LiveEvents.AnnouncementLength = 200

-- Reasons staff can give for a kick or a ban. A fixed list rather than free text:
-- the player reads it, and anything typed would have to go through Roblox's text
-- filter first.
LiveEvents.ModerationReasons = {
	"Exploiting",
	"Harassing other players",
	"Inappropriate behaviour",
	"Breaking the rules",
}

-- Ban lengths the panel offers, in days. 0 is permanent.
LiveEvents.BanDays = { 1, 7, 0 }

LiveEvents.ById = {} :: { [string]: EventDef }
for _, def in LiveEvents.List do
	LiveEvents.ById[def.Id] = def
end

return LiveEvents
