local patch_filter_selector = require("@layer/sandbox/patching/patch_filter_selector")
local env_symbols = require("./env_symbols")
local new_symbol = require("@layer/util/new_symbol")
local patch_symbols = require("./patching/patch_symbols")
local sandbox_types = require("./sandbox_types")
local script_stalling = require("./script_stalling")
local unsandbox = require("./unsandbox")

local sandbox_wrapper: (app: sandbox_types.App, value: any) -> any

local function get_setter_patches(self)
	return rawget(self, patch_symbols.SETTER_PATCHES_SYMBOL) :: { sandbox_types.SetterPatch }
end

local function get_getter_patches(self)
	return rawget(self, patch_symbols.GETTER_PATCHES_SYMBOL) :: { sandbox_types.GetterPatch }
end

local function get_storage(self)
	return rawget(self, patch_symbols.PATCH_STORAGE_SYMBOL) :: { [sandbox_types.Patch]: any }
end

local function get_sandbox_context(self)
	return rawget(self, patch_symbols.SANDBOX_CONTEXT) :: sandbox_types.App
end

local function should_run_on_key(
	patch: sandbox_types.Patch,
	key: any,
	met_conditions: { [sandbox_types.PatchCondition]: true }
)
	local matched = patch.keys == nil or table.find(patch.keys, key)

	if not matched then
		return false
	end

	if patch.special_conditions then
		for _, value in patch.special_conditions do
			if not met_conditions[value] then
				return false
			end
		end
	end

	return true
end

local function get_storage_for_patch(self, patch: sandbox_types.Patch)
	local storage = get_storage(self)

	if storage[patch] then
		return storage[patch]
	else
		storage[patch] = {}
		return storage[patch]
	end
end

local function sandbox_tuple(context: sandbox_types.App, ...)
    local packed = table.pack(...)
    local result = {}

    for key, value in packed do
        result[key] = sandbox_wrapper(context, value)
    end

    return table.unpack(result)
end

local function get_unsandboxed_object(self)
	return rawget(self, patch_symbols.UNSANDBOXED_OBJECT) :: any
end

local metatable = {}

function metatable:__tostring()
	return `{get_unsandboxed_object(self)} [nl]`
end

function metatable:__index(key: any)
	local unsandboxed_object = get_unsandboxed_object(self)
	local raw_value
    local app = get_sandbox_context(self)

	-- bit of a hack...
	-- generally we want to throw the error for invalid indexes, but it's ideal to throw a
	-- warning instead of error for RBXScriptSignal:disconnect
	if typeof(unsandboxed_object) == "RBXScriptSignal" and key == "disconnect" then
		raw_value = nil
	else
		raw_value = unsandboxed_object[key]
	end

	local mutated = raw_value
	local met_conditions = {}

	for _, patch in get_getter_patches(self) do
		if should_run_on_key(patch, key, met_conditions) then
			local context: sandbox_types.PatchedContext = {
				snapshot = mutated,
				unsandboxed = raw_value,
				unsandboxed_object = unsandboxed_object,
				sandbox_context = app,
				storage = get_storage_for_patch(self, patch),
			}

			mutated = patch.run(context, key)
		end
	end

	if typeof(mutated) == "function" then
        local source_script = getfenv(2)[env_symbols.SOURCE_SCRIPT]
        assert(source_script)

		return function(...)
			script_stalling.yield_if_stalled(source_script)
			return sandbox_tuple(app, mutated(...))
		end
	end

	return mutated
end

function metatable:__newindex(key: any, value: any)
	local unsandboxed_object = get_unsandboxed_object(self)
	local mutated_key, mutated_value = key, value
	local met_conditions = {}

    local app = get_sandbox_context(self)

	for _, patch in get_setter_patches(self) do
		if should_run_on_key(patch, key, met_conditions) then
			local context: sandbox_types.PatchedContext = {
				snapshot = mutated_key,
				unsandboxed = get_unsandboxed_object(self),
				unsandboxed_object = unsandboxed_object,
				sandbox_context = app,
				storage = get_storage_for_patch(self, patch),
			}

			mutated_key, mutated_value = patch.run(context, key, mutated_value)

			if mutated_key == nil then
				-- a patch has sunk the value.
				return
			end
		end
	end

	if mutated_key ~= nil then
		unsandboxed_object[mutated_key] = unsandbox(mutated_value)
	end
end

function metatable:__iter()
	local last_value: unknown?

	local function iterate(o)
		local key, value = next(self, last_value)
		last_value = value

		if (patch_symbols :: any)[key] then
			return iterate(o)
		end

		return key, value
	end

	return iterate
end

function metatable.__eq(a, b)
    if typeof(a) ~= "table" or typeof(b) ~= "table" then
		return false
	end

	return unsandbox(a) == unsandbox(b)
end

local leak = {}

sandbox_wrapper = function(context: sandbox_types.App, value: any)
	local filtered_patches = patch_filter_selector.find_patches(context.patches)(value)

	if #filtered_patches == 0 then
		return value
	end

	if leak[value] then
		return leak[value]
	end

	local setter_patches: { sandbox_types.SetterPatch } = {}
	local getter_patches: { sandbox_types.GetterPatch } = {}

	for _, patch in filtered_patches do
		if patch.kind == "getter_patch" then
			table.insert(getter_patches, patch :: sandbox_types.GetterPatch)
		elseif patch.kind == "setter_patch" then
			table.insert(setter_patches, patch :: sandbox_types.SetterPatch)
		else
			warn(debug.traceback(`Unrecognised patch {patch.kind}`))
		end
	end

	local sandboxed: { [new_symbol.Symbol]: any } = {
		[patch_symbols.SETTER_PATCHES_SYMBOL] = setter_patches,
		[patch_symbols.GETTER_PATCHES_SYMBOL] = getter_patches,
		[patch_symbols.PATCH_STORAGE_SYMBOL] = {},
		[patch_symbols.UNSANDBOXED_OBJECT] = value,
		[patch_symbols.SANDBOX_CONTEXT] = context,
	}

	local new = setmetatable(sandboxed, metatable)

	leak[value] = new

	return new
end

return sandbox_wrapper