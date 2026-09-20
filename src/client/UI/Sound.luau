--!strict
-- Plays a themed UI sound. Themes that leave a sound unset are silent.

local Debris = game:GetService("Debris")
local SoundService = game:GetService("SoundService")

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
