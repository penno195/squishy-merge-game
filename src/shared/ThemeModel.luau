--!strict
-- Hands back a theme's own asset as a Model, however it was saved.
--
-- An asset arrives in one of three shapes. The ones built for this game are
-- Models. A single mesh saved out of Studio is a bare MeshPart. And a model
-- taken off the catalogue and dropped into `assets/` is whatever it was in the
-- toolbox -- usually a Folder holding the mesh and whatever else came with it.
-- Only the first was ever accepted, so the other two fell back to a shape built
-- out of parts and looked, from the outside, exactly like a missing file.
--
-- Scripts are stripped on the way through, along with the remotes a script would
-- talk over. A catalogue model is someone else's code running inside your game,
-- and this game already has its own idea of how a squishy moves; running both is
-- at best two animations arguing over the same part. It is the same rule
-- TacoService applies to what it fetches at runtime, for the same reason.
--
-- The template in ReplicatedStorage is never touched -- the clone is what gets
-- tidied. Rewriting it in place would mean each client quietly editing its own
-- copy of something the server replicated to it.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ThemeModel = {}

local function strip(instance: Instance)
	for _, descendant in instance:GetDescendants() do
		if
			descendant:IsA("LuaSourceContainer")
			or descendant:IsA("RemoteEvent")
			or descendant:IsA("RemoteFunction")
			or descendant:IsA("BindableEvent")
			or descendant:IsA("BindableFunction")
		then
			descendant:Destroy()
		end
	end
end

-- The first asset of this name in any of the named folders under ThemeAssets.
local function find(name: string, folders: { string }): Instance?
	local assets = ReplicatedStorage:FindFirstChild("ThemeAssets")
	if not assets then
		return nil
	end
	for _, folderName in folders do
		local folder = assets:FindFirstChild(folderName)
		local found = folder and folder:FindFirstChild(name)
		if found then
			return found
		end
	end
	return nil
end

-- A clone of the named asset, as a Model, with anything that isn't scenery
-- taken out of it. Nil when there is no such asset, and the caller says so in
-- its own words -- a missing prop and a missing unit want different warnings.
function ThemeModel.clone(name: string?, folders: { string }): Model?
	if not name then
		return nil
	end
	local template = find(name, folders)
	if not template then
		return nil
	end

	local copy = template:Clone()
	strip(copy)
	if copy:IsA("Model") then
		return copy
	end

	local model = Instance.new("Model")
	model.Name = template.Name
	if copy:IsA("BasePart") then
		copy.Parent = model
		model.PrimaryPart = copy
	else
		-- A Folder, or anything else that is really just a container: take what
		-- is inside it and drop the wrapper.
		for _, child in copy:GetChildren() do
			child.Parent = model
			if not model.PrimaryPart and child:IsA("BasePart") then
				model.PrimaryPart = child
			end
		end
		copy:Destroy()
	end
	return model
end

return ThemeModel
