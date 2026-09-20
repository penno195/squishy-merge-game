--!nocheck
-- Camera framings for the game page's icon and thumbnails.
--
-- Roblox's own guidance for a game page is that the images look like the game
-- being played, so these are shots of the real world rather than artwork: the
-- garden full of squishies, the hub from above, and the player with their pet.
--
-- How to use it:
--   1. Press Play in Studio and wait for the world to build.
--   2. Open the command bar (View -> Command Bar) and set the dropdown at its
--      right to **Client**. It defaults to Server, where there is no camera and
--      no LocalPlayer, and the script will say so rather than half-running.
--   3. Paste this whole file in and press Enter. It prints what it offers.
--   4. Fill the garden first -- an empty one makes a dull picture. The Staff
--      panel's Gifts page spawns any unit, 25 at a time; pick colourful ones
--      from different tiers rather than 25 of the same.
--   5. `shot(1)`, `shot(2)`, `shot(3)` to frame each one, then View -> Screenshot
--      for a clean capture of just the viewport. They land in Pictures\Roblox.
--   6. `shot(0)` gives the camera and the HUD back.
--
-- Nothing here is part of the game: it only runs when pasted in by hand.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
if not player then
	warn("photo-mode: no LocalPlayer. Set the command bar's dropdown to Client and paste again.")
	return
end

local camera = Workspace.CurrentCamera

-- The player's own garden if they have one, else whichever was built first, so a
-- shot still frames something when this is run before a plot is handed out.
local function myPlot(): Model?
	local world = Workspace:FindFirstChild("World")
	local gardens = world and world:FindFirstChild("Gardens")
	if not gardens then
		return nil
	end
	local first: Model? = nil
	for _, plot in gardens:GetChildren() do
		if plot:IsA("Model") then
			first = first or plot
			if plot:GetAttribute("OwnerUserId") == player.UserId then
				return plot
			end
		end
	end
	return first
end

-- Everything the player doesn't need to see in a picture: our HUD, and Roblox's
-- own chat, top bar and backpack.
local function chrome(visible: boolean)
	local gui = player:FindFirstChild("PlayerGui")
	local hud = gui and gui:FindFirstChild("MergeHud")
	if hud and hud:IsA("ScreenGui") then
		hud.Enabled = visible
	end
	pcall(function()
		StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.All, visible)
	end)
end

local function look(from: Vector3, at: Vector3, fov: number)
	camera.CameraType = Enum.CameraType.Scriptable
	camera.FieldOfView = fov
	camera.CFrame = CFrame.lookAt(from, at)
end

-- 1: the garden, low and close, so the squishies fill the frame and the fence
-- and name board place it. The angle is deliberately off the garden's own axis:
-- square-on reads as a diagram, three-quarters reads as a photograph.
local function gardenShot()
	local plot = myPlot()
	if not plot then
		warn("photo-mode: no gardens in the world yet. Press Play first.")
		return
	end
	local origin = plot:GetPivot()
	local from = origin * CFrame.new(-38, 16, 46)
	local at = origin * CFrame.new(0, 3, 0)
	look(from.Position, at.Position, 50)
end

-- 2: the whole arena from above, which is the one shot that says what the game
-- is -- a ring of gardens round a hub -- in a single glance.
local function hubShot()
	look(Vector3.new(0, 150, 210), Vector3.new(0, 0, 0), 45)
end

-- 3: the player and their pet, close, with the hub behind them. Faces are what
-- a browsing player looks at, so this one is framed on the character.
local function petShot()
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") then
		warn("photo-mode: no character yet.")
		return
	end
	local base = root.CFrame
	local from = base * CFrame.new(6, 2.5, 9)
	local at = base * CFrame.new(0, 0.5, -2)
	look(from.Position, at.Position, 40)
end

local shots = { gardenShot, hubShot, petShot }

function _G.shot(index: number)
	if index == 0 then
		camera.CameraType = Enum.CameraType.Custom
		camera.FieldOfView = 70
		chrome(true)
		print("photo-mode: camera and HUD back to normal.")
		return
	end
	local framing = shots[index]
	if not framing then
		warn("photo-mode: shots are 1, 2, 3 -- or 0 to put everything back.")
		return
	end
	-- The HUD stays hidden for every framing: a thumbnail wants the world, and
	-- the same HUD in all three pictures reads as three pictures of a menu.
	chrome(false)
	framing()
end

-- The camera drifts back to the character every frame unless it is told not to,
-- so a scripted framing has to be re-asserted while a shot is being lined up.
if not _G.__photoModeHeld then
	_G.__photoModeHeld = true
	RunService.RenderStepped:Connect(function()
		if camera.CameraType == Enum.CameraType.Scriptable then
			camera.CameraSubject = nil
		end
	end)
end

print("photo-mode: shot(1) garden · shot(2) hub from above · shot(3) player and pet · shot(0) back to normal")
