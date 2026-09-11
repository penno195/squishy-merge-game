--!strict
-- Dropping the carried item with Q or G on a keyboard, or X on a gamepad.
-- The keys are always live and the server ignores the request when the player
-- isn't carrying anything. That's simpler, and far harder to get wrong, than
-- binding and unbinding the action as items change hands. The HUD's Drop
-- button covers touch, where there are no keys at all.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Net = require(ReplicatedStorage.Shared.Net)

local DROP_KEYS: { [Enum.KeyCode]: boolean } = {
	[Enum.KeyCode.Q] = true,
	[Enum.KeyCode.G] = true,
	[Enum.KeyCode.ButtonX] = true,
}

local CarryController = {}

function CarryController.start()
	UserInputService.InputBegan:Connect(function(input, processed)
		-- `processed` is true while the player is typing in chat.
		if not processed and DROP_KEYS[input.KeyCode] then
			Net.event("DropCarried"):FireServer()
		end
	end)
end

return CarryController
