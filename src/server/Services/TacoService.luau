--!strict
-- Fetches the catalogue model the Taco Rain event drops, once, and leaves it in
-- ReplicatedStorage for clients to clone. Nothing else in the game touches it: if
-- it never arrives, the event builds its tacos out of parts instead and nobody can
-- tell the difference except by looking closely.
--
-- Two things this has to get right.
--
-- **It must never hold up startup.** `InsertService:LoadAsset` is a web call, and a
-- web call in `init` is how you get a server with no world and a clean Output. So
-- the fetch runs on its own thread and the rest of the game starts without it.
--
-- **A catalogue model is someone else's code until it isn't.** A free model can
-- carry scripts, and this one is pulled in at runtime by id, so whatever is inside
-- it today is not necessarily what was inside it when the id was written down.
-- Everything that isn't geometry is deleted before it is parented anywhere the
-- game can see -- a whitelist, so a class nobody here has thought of is dropped
-- rather than kept.

local InsertService = game:GetService("InsertService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local Theme = Config.Theme

-- Geometry and the things that decorate it. Everything else goes: scripts of every
-- kind, remotes, sounds, lights, tools, prompts, click detectors, values.
local ALLOWED: { [string]: boolean } = {
	Model = true,
	Folder = true,
	Part = true,
	MeshPart = true,
	WedgePart = true,
	UnionOperation = true,
	SpecialMesh = true,
	BlockMesh = true,
	CylinderMesh = true,
	Decal = true,
	Texture = true,
	SurfaceAppearance = true,
}

local TacoService = {}

local function sanitise(root: Instance)
	for _, descendant in root:GetDescendants() do
		-- Something further up may already have taken it with it.
		if descendant.Parent and not ALLOWED[descendant.ClassName] then
			descendant:Destroy()
		end
	end
	for _, descendant in root:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.Anchored = true
			descendant.CanCollide = false
			descendant.CanQuery = false
			descendant.CanTouch = false
			descendant.CastShadow = false
		end
	end
end

function TacoService.init()
	local assetId = Theme.TacoRainModel
	if not assetId or assetId == 0 then
		return
	end
	task.spawn(function()
		local ok, container = pcall(function()
			return InsertService:LoadAsset(assetId)
		end)
		if not ok or typeof(container) ~= "Instance" then
			warn(`Taco Rain: could not load model {assetId}; falling back to built tacos`)
			return
		end
		sanitise(container)
		-- LoadAsset hands back a Model holding the asset. What's wanted is the thing
		-- inside it, so a single child is unwrapped and anything odder is kept whole.
		local children = container:GetChildren()
		local model = if #children == 1 and children[1]:IsA("Model") then children[1] else container
		if not model:FindFirstChildWhichIsA("BasePart", true) then
			warn(`Taco Rain: model {assetId} had no parts left after cleaning; using built tacos`)
			container:Destroy()
			return
		end
		local assets = ReplicatedStorage:FindFirstChild("ThemeAssets")
		if not assets then
			container:Destroy()
			return
		end
		local effects = assets:FindFirstChild("Effects")
		if not effects then
			local folder = Instance.new("Folder")
			folder.Name = "Effects"
			folder.Parent = assets
			effects = folder
		end
		model.Name = "Taco"
		model.Parent = effects
		if model ~= container then
			container:Destroy()
		end
	end)
end

return TacoService
