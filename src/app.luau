local RunService = game:GetService("RunService")
local sandbox_types = require("@layer/sandbox/sandbox_types")
local patch_filter_selector = require("./sandbox/patching/patch_filter_selector")
local sandbox = require("@layer/sandbox")

export type OptionalSwitch = boolean?

local VALID_BAG_ENTRIES: { [any]: true } = {}

local function new_entry<R>(x: R)
	VALID_BAG_ENTRIES[x] = true
	return (x :: any) :: { __T: R, ["🐟"]: "this is just a luau type wrapper" }
end

local BAG_ENTRIES: sandbox_types.BagEntries = {
	client_instance_pool = new_entry(sandbox.instance_pool.start_client),
	environment_sandboxer = new_entry(sandbox.environment_sandboxer),
}

local setup = {
	patches = {} :: { sandbox_types.Patch },
	systems = {} :: { sandbox_types.AppSystemFn },
}

local app = {}

app.context = (
	setmetatable({}, {
		__index = function()
			error("the app has not been started yet! generally it should be accessed through a system.")
		end,
	}) :: any
) :: sandbox_types.App

function app.add_system(id: string, run: sandbox_types.AppSystemFn, enabled: OptionalSwitch?)
	local system: sandbox_types.AppSystem = {
		id = id,
		enabled = enabled,
		run = run,
	}

	if system.enabled ~= false then
		table.insert(setup.systems, system.run)
	end

	return system
end

function app.add_patch(id: string, patch: sandbox_types.Patch, enabled: OptionalSwitch?): sandbox_types.PatchGroup
	local patch_group: sandbox_types.PatchGroup = {
		id = id,
		enabled = if enabled ~= nil then enabled else patch.enabled,
		patches = { patch },
	}

	if not patch.id then
		patch.id = id
	end

	if patch_group.enabled ~= false then
		table.insert(setup.patches, patch)
	end

	return patch_group
end

function app.add_patch_group(patch_group: sandbox_types.PatchGroup): sandbox_types.PatchGroup
	if patch_group.enabled ~= false then
		for index, patch in patch_group.patches do
			patch.id = `{patch_group.id}_{index}` 
			table.insert(setup.patches, patch)
		end
	end

	return patch_group
end

function app.start()
	print("loading modules")

	if RunService:IsServer() then
		sandbox.instance_pool.start_server()
	end

	local constructed: { [any]: any } = {}
	local bag = {}

	-- important: load all modules to allow them to register patches/systems
	for _, child in script.Parent:WaitForChild("systems"):GetDescendants() do
		if child:IsA("ModuleScript") then
			local _ = require(child :: any) :: any
		end
	end

	local app_context = {
		systems = setup.systems,
		patches = patch_filter_selector.sort_patches(setup.patches),
		bag = bag,
	}
	
	print("app:", app_context)

	bag.entries = BAG_ENTRIES

	function bag.get<T>(constructor: any)
		assert(VALID_BAG_ENTRIES[constructor], `unknown bag entry {constructor}`)
		local result = constructed[constructor]

		if result then
			return result
		else
			local new = constructor(app_context)
			constructed[constructor] = new
			return new
		end
	end

	app.context = app_context :: sandbox_types.App

	for _, system in setup.systems do
		system(app.context)
	end

	print("systems running!")
end

return app
