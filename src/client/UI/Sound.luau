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

return Sound
