-- A require tree shaped like Rojo's, so `script.Parent.X` resolves.
local cache = {}
local scripts = {}

local folderMeta = {}
folderMeta.__index = function(folder, key)
	local children = rawget(folder, "__children")
	return children and children[key]
end

local function newFolder(path, parent)
	local folder = setmetatable({ __path = path, __children = {}, Parent = parent }, folderMeta)
	function folder:FindFirstChild(name)
		return rawget(self, "__children")[name]
	end
	return folder
end

local function newScript(path, parent)
	local s = { __path = path, Parent = parent }
	function s:IsA(class)
		return class == "ModuleScript"
	end
	scripts[path] = s
	return s
end

local shared = newFolder("Shared", nil)
local themes = newFolder("Shared/Themes", shared)
shared.__children.Themes = themes

for _, name in { "Balance", "Settings", "Types", "Config", "Economy" } do
	shared.__children[name] = newScript("Shared/" .. name, shared)
end
for _, name in { "Squishies", "CandyLand" } do
	themes.__children[name] = newScript("Shared/Themes/" .. name, themes)
end

local function load(path)
	if cache[path] ~= nil then
		return cache[path]
	end
	local loader = loaders[path]
	assert(loader, "no loader for " .. path)
	local value = loader(scripts[path], function(target)
		return load(target.__path)
	end)
	cache[path] = value
	return value
end

Config = load("Shared/Config")
Economy = load("Shared/Economy")
