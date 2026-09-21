--!strict
-- Plays a themed UI sound. Themes that leave a sound unset are silent.

local Debris = game:GetService("Debris")
local SoundService = game:GetService("SoundService")
local Workspace = game:GetService("Workspace")

local Sound = {}

function Sound.play(soundId: string?)
	if not soundId then
		return
	end
	local sound = Instance.new("Sound")
	sound.SoundId = soundId
	sound.Parent = SoundService
	sound:Play()
	Debris:AddItem(sound, 5)
end

-- A sound at a point in the world rather than in the player's ears, on a part
-- of its own that clears itself up afterwards. What a merge, a landing unit or
-- a bounce wants: it falls off with distance, so a garden full of them across
-- the map doesn't drown out the one at your feet.
function Sound.at(position: Vector3, soundId: string?)
	if not soundId or soundId == "" then
		return
	end
	local origin = Instance.new("Part")
	origin.Anchored = true
	origin.CanCollide = false
	origin.CanQuery = false
	origin.Transparency = 1
	origin.Size = Vector3.one
	origin.CFrame = CFrame.new(position)
	origin.Parent = Workspace

	local sound = Instance.new("Sound")
	sound.SoundId = soundId
	sound.RollOffMaxDistance = 120
	sound.Parent = origin
	sound:Play()

	Debris:AddItem(origin, 3)
end

-- A sound that plays until it's stopped -- an event song, not a UI click. Returns
-- the Sound so the caller can end it; nil when the theme leaves the id unset, so
-- callers must check before stopping it.
function Sound.loop(soundId: string?, volume: number?): Sound?
	if not soundId or soundId == "" then
		return nil
	end
	local sound = Instance.new("Sound")
	sound.SoundId = soundId
	sound.Looped = true
	sound.Volume = volume or 0.5
	sound.Parent = SoundService
	sound:Play()
	return sound
end

return Sound
