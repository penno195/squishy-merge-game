--!strict
-- The staff panel: the game's own admins, not the Admin pass. Staff run events on
-- every server, send a message to every player in the game, hand out any unit or
-- currency, and kick or ban.
--
-- Who is staff is decided here and nowhere else:
--   * the experience's creator, when a person owns it;
--   * anyone at or above Settings.StaffGroupRank in the owning group, when a group
--     owns it (255, the owner, unless it's lowered);
--   * anyone listed in Settings.StaffUserIds;
--   * everyone in Studio, where there is no one else to test it with.
--
-- The panel is only a way of asking. Every command is re-checked here, argument by
-- argument, because a client can fire this remote with anything at all.

local GroupService = game:GetService("GroupService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local ActionService = require(script.Parent.ActionService)
local Config = require(ReplicatedStorage.Shared.Config)
local DataService = require(script.Parent.DataService)
local Economy = require(ReplicatedStorage.Shared.Economy)
local EventService = require(script.Parent.EventService)
local Format = require(ReplicatedStorage.Shared.Format)
local ItemService = require(script.Parent.ItemService)
local LiveEvents = require(ReplicatedStorage.Shared.LiveEvents)
local Net = require(ReplicatedStorage.Shared.Net)
local PassService = require(script.Parent.PassService)
local PetService = require(script.Parent.PetService)
local RewardService = require(script.Parent.RewardService)
local StateService = require(script.Parent.StateService)

-- Most units staff can drop into one garden in one press, and the most currency in
-- one gift. Both are there to catch a typo, not to limit events.
local MAX_SPAWN = 25
local MAX_GIFT = 1e15

local StaffService = {}

-- Group rank, looked up once per player: it's a web call, and the answer doesn't
-- change during a visit that matters.
local groupStaff: { [Player]: boolean } = {}

function StaffService.isStaff(player: Player): boolean
	if RunService:IsStudio() then
		return true
	end
	if game.CreatorType == Enum.CreatorType.User and player.UserId == game.CreatorId then
		return true
	end
	if table.find(Config.Settings.StaffUserIds, player.UserId) then
		return true
	end
	return groupStaff[player] == true
end

local function checkGroup(player: Player)
	if game.CreatorType ~= Enum.CreatorType.Group then
		return
	end
	-- Every group the player is in, with their rank in each. The player methods
	-- that ask about one group are deprecated.
	local ok, groups = pcall(GroupService.GetGroupsAsync, GroupService, player.UserId)
	if not ok or typeof(groups) ~= "table" then
		return
	end
	for _, group in groups do
		if group.Id == game.CreatorId and (group.Rank or 0) >= Config.Settings.StaffGroupRank then
			groupStaff[player] = true
			StateService.markDirty(player)
		end
	end
end

local function reply(staff: Player, message: string, kind: string?)
	StateService.notify(staff, message, kind or "Info")
end

local function isWhole(value: unknown, low: number, high: number): boolean
	return typeof(value) == "number" and value % 1 == 0 and value >= low and value <= high
end

-- A target is "Me", "Server" (everyone here) or a user id in this server.
local function targetsOf(staff: Player, target: unknown): { Player }
	if target == "Me" then
		return { staff }
	elseif target == "Server" then
		return Players:GetPlayers()
	elseif typeof(target) == "number" then
		local player = Players:GetPlayerByUserId(target)
		return if player then { player } else {}
	end
	return {}
end

local function spaceFor(player: Player): number
	return PassService.extraGardenSpaces(player) + PetService.extraSpaces(player)
end

-- Commands --------------------------------------------------------------------

local function startEvent(staff: Player, args: { [string]: any })
	local def = if typeof(args.Id) == "string" then LiveEvents.ById[args.Id] else nil
	if
		not def
		or not table.find(def.Strengths, args.Strength)
		or not table.find(LiveEvents.Durations, args.Minutes)
	then
		return
	end
	EventService.start(staff, def.Id, args.Strength, args.Minutes)
	ActionService.fire(staff, "StaffCommand", {
		Value = args.Strength,
		Fields = { Command = "StartEvent", Event = def.Id, Minutes = args.Minutes },
	})
end

local function stopEvent(staff: Player, args: { [string]: any })
	if typeof(args.Id) ~= "string" or not LiveEvents.ById[args.Id] then
		return
	end
	EventService.stop(args.Id)
	ActionService.fire(staff, "StaffCommand", { Fields = { Command = "StopEvent", Event = args.Id } })
end

local function announce(staff: Player, args: { [string]: any })
	local text = args.Text
	if typeof(text) ~= "string" then
		return
	end
	text = text:gsub("^%s+", ""):gsub("%s+$", "")
	if text == "" then
		return
	end
	if utf8.len(text) == nil or (utf8.len(text) :: number) > LiveEvents.AnnouncementLength then
		reply(staff, `Keep it under {LiveEvents.AnnouncementLength} characters.`, "Error")
		return
	end
	local failed = EventService.announce(staff, text)
	if failed then
		reply(staff, failed, "Error")
		return
	end
	reply(staff, "Sent to every server.", "Reward")
	ActionService.fire(staff, "StaffCommand", { Fields = { Command = "Announce" } })
end

local function spawnItems(staff: Player, args: { [string]: any })
	if not isWhole(args.Index, 1, #Config.Units) or not isWhole(args.Count, 1, MAX_SPAWN) then
		return
	end
	local index, count = args.Index :: number, args.Count :: number
	local landed, full = 0, 0
	for _, player in targetsOf(staff, args.Target) do
		local data = DataService.get(player)
		if data then
			-- Up to the room there is, not past it: a garden packed beyond its
			-- capacity has nowhere to put the next drop, and merging is how it
			-- would have to be dug out.
			local given = 0
			for _ = 1, count do
				if
					not Economy.hasRoom(data, spaceFor(player)) or not ItemService.dropItem(player, index, nil, true)
				then
					break
				end
				given += 1
				ActionService.fire(player, "Dropped", { Value = index, Fields = { Source = "Staff" } })
			end
			if given > 0 then
				landed += given
				StateService.markDirty(player)
				if player ~= staff then
					StateService.notify(
						player,
						`A gift from {staff.DisplayName}: {given}x {Config.Units[index].Name}!`,
						"Reward"
					)
				end
			end
			if given < count then
				full += 1
			end
		end
	end
	local note = if full > 0 then ` ({full} garden{if full == 1 then " was" else "s were"} full)` else ""
	reply(staff, `Spawned {landed}x {Config.Units[index].Name}{note}.`, if landed > 0 then "Reward" else "Error")
	ActionService.fire(staff, "StaffCommand", {
		Value = landed,
		Fields = { Command = "Spawn", Unit = index, Target = tostring(args.Target) },
	})
end

local function give(staff: Player, args: { [string]: any })
	local currency = args.Currency
	local amount = args.Amount
	if (currency ~= "Cash" and currency ~= "Gems") or typeof(amount) ~= "number" then
		return
	end
	amount = math.floor(amount)
	if amount < 1 or amount > MAX_GIFT or amount ~= amount then
		reply(staff, `Give between 1 and {Format.number(MAX_GIFT)}.`, "Error")
		return
	end
	local name = if currency == "Cash" then Config.Theme.Text.Currency else "Gems"
	local players = targetsOf(staff, args.Target)
	for _, player in players do
		if currency == "Cash" then
			RewardService.grantCash(player, amount)
		else
			RewardService.grantGems(player, amount)
		end
		if player ~= staff then
			StateService.notify(player, `A gift from {staff.DisplayName}: {Format.number(amount)} {name}!`, "Reward")
		end
	end
	reply(
		staff,
		`Gave {Format.number(amount)} {name} to {#players} player{if #players == 1 then "" else "s"}.`,
		"Reward"
	)
	ActionService.fire(staff, "StaffCommand", {
		Value = amount,
		Fields = { Command = "Give", Currency = currency, Target = tostring(args.Target) },
	})
end

-- The player being acted on, if they're here and fair game. Staff can't kick,
-- ban, bring or visit themselves, and can't kick or ban each other: a falling-out
-- between admins is settled by whoever owns the game, not by the panel.
local function otherPlayer(staff: Player, userId: unknown, moderating: boolean): Player?
	if typeof(userId) ~= "number" then
		return nil
	end
	local target = Players:GetPlayerByUserId(userId)
	if not target or target == staff then
		return nil
	end
	if moderating and StaffService.isStaff(target) then
		reply(staff, "You can't do that to other staff.", "Error")
		return nil
	end
	return target
end

local function reasonOf(value: unknown): string?
	return if typeof(value) == "string" and table.find(LiveEvents.ModerationReasons, value) then value else nil
end

local function kick(staff: Player, args: { [string]: any })
	local target = otherPlayer(staff, args.UserId, true)
	local reason = reasonOf(args.Reason)
	if not (target and reason) then
		return
	end
	local name = target.DisplayName
	target:Kick(`You were removed from this server: {reason}.`)
	reply(staff, `Kicked {name}.`, "Reward")
	ActionService.fire(staff, "StaffCommand", { Fields = { Command = "Kick", Reason = reason } })
end

local function ban(staff: Player, args: { [string]: any })
	local target = otherPlayer(staff, args.UserId, true)
	local reason = reasonOf(args.Reason)
	if not (target and reason) or not table.find(LiveEvents.BanDays, args.Days) then
		return
	end
	local days = args.Days :: number
	local name, userId = target.DisplayName, target.UserId
	-- Every server of the game, and alt accounts too, which is the point of a ban
	-- over a kick. Undone from the Creator Hub, under the experience's Moderation.
	local ok, err = pcall(function()
		(Players :: any):BanAsync({
			UserIds = { userId },
			ApplyToUniverse = true,
			Duration = if days > 0 then days * 86400 else -1,
			DisplayReason = reason,
			PrivateReason = `Banned by {staff.Name} ({staff.UserId}) from the staff panel`,
			ExcludeAltAccounts = false,
		})
	end)
	if not ok then
		reply(staff, `Couldn't ban {name}: {err}`, "Error")
		return
	end
	local length = if days > 0 then `{days} day{if days == 1 then "" else "s"}` else "good"
	reply(staff, `Banned {name} for {length}.`, "Reward")
	ActionService.fire(staff, "StaffCommand", { Value = days, Fields = { Command = "Ban", Reason = reason } })
end

local function rootOf(player: Player): BasePart?
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	return if root and root:IsA("BasePart") then root else nil
end

-- Go to them, or bring them to you. Stood a few studs in front rather than on top.
local function move(staff: Player, args: { [string]: any }, bring: boolean)
	local target = otherPlayer(staff, args.UserId, false)
	if not target then
		return
	end
	local mover, anchor = if bring then target else staff, if bring then staff else target
	local moverRoot, anchorRoot = rootOf(mover), rootOf(anchor)
	local character = mover.Character
	if not (moverRoot and anchorRoot and character) then
		reply(staff, `{target.DisplayName} can't be reached right now.`, "Error")
		return
	end
	character:PivotTo(anchorRoot.CFrame * CFrame.new(0, 0, -4) * CFrame.Angles(0, math.pi, 0))
	if bring then
		StateService.notify(target, `{staff.DisplayName} brought you to them.`, "Info")
	end
	ActionService.fire(staff, "StaffCommand", { Fields = { Command = if bring then "Bring" else "GoTo" } })
end

local COMMANDS: { [string]: (Player, { [string]: any }) -> () } = {
	StartEvent = startEvent,
	StopEvent = stopEvent,
	Announce = announce,
	Spawn = spawnItems,
	Give = give,
	Kick = kick,
	Ban = ban,
	GoTo = function(staff, args)
		move(staff, args, false)
	end,
	Bring = function(staff, args)
		move(staff, args, true)
	end,
}

function StaffService.init()
	Net.event("StaffCommand").OnServerEvent:Connect(function(player, command, args)
		if not StaffService.isStaff(player) or typeof(command) ~= "string" or typeof(args) ~= "table" then
			return
		end
		local run = COMMANDS[command]
		if run then
			run(player, args)
		end
	end)

	Players.PlayerAdded:Connect(checkGroup)
	for _, player in Players:GetPlayers() do
		task.spawn(checkGroup, player)
	end
	Players.PlayerRemoving:Connect(function(player)
		groupStaff[player] = nil
	end)

	StateService.addProvider(function(player, snapshot)
		snapshot.IsStaff = StaffService.isStaff(player)
	end)
end

return StaffService
