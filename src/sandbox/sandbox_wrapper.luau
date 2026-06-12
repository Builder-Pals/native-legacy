local patch_filter_selector = require("@layer/patching/patch_filter_selector")
local new_symbol = require("@layer/util/new_symbol")
local patch_symbols = require("@layer/patching/patch_symbols")
local patch_types = require("@layer/patching/patch_types")
local s = require("@layer/patching/patch_symbols")
local sandbox_types = require("./sandbox_types")

local function get_setter_patches(self)
    return rawget(self, s.SETTER_PATCHES_SYMBOL) :: { sandbox_types.SetterPatch }
end

local function get_getter_patches(self)
    return rawget(self, s.GETTER_PATCHES_SYMBOL) :: { sandbox_types.GetterPatch }
end

local function get_storage(self)
    return rawget(self, s.PATCH_STORAGE_SYMBOL) :: { [patch_types.Patch]: any }
end

local function get_sandbox_context(self)
    return rawget(self, s.SANDBOX_CONTEXT) :: sandbox_types.SandboxContext
end

local function should_run_on_key(patch: patch_types.Patch, key: any, met_conditions: { [patch_types.PatchCondition]: true })
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

local function get_storage_for_patch(self, patch: patch_types.Patch)
    local storage = get_storage(self)

    if storage[patch] then
        return storage[patch]
    else
        storage[patch] = {}
        return storage[patch]
    end
end

local function get_unsandboxed_object(self)
    return rawget(self, s.UNSANDBOXED_OBJECT) :: any
end

local metatable = {}

function metatable:__tostring()
    return `{get_unsandboxed_object(self)} ;)`
end

function metatable:__index(key: any)
    local unsandboxed_object = get_unsandboxed_object(self)
    local raw = unsandboxed_object[key]

    local mutated = raw
    local met_conditions = {}

    for _, patch in get_getter_patches(self) do
        if should_run_on_key(patch, key, met_conditions) then
            local context: sandbox_types.PatchedContext = {
                snapshot = mutated,
                unsandboxed = raw,
                unsandboxed_object = unsandboxed_object,
                sandbox_context = get_sandbox_context(self),
                storage = get_storage_for_patch(self, patch)
            }
            
            mutated = patch.run(context, key)
        end
    end

    return mutated
end

function metatable:__newindex(key: any, value: any)
    local unsandboxed_object = get_unsandboxed_object(self)
    local mutated_key, mutated_value = key, value
    local met_conditions = {}
    
    for _, patch in get_setter_patches(self) do
        if should_run_on_key(patch, key, met_conditions) then
            local context: sandbox_types.PatchedContext = {
                snapshot = key,
                unsandboxed = get_unsandboxed_object(self),
                unsandboxed_object = unsandboxed_object,
                sandbox_context = get_sandbox_context(self),
                storage = get_storage_for_patch(self, patch)
            }
            
            mutated_key, mutated_value = patch.run(context, key, value)
        end
    end

    if mutated_key ~= nil then
        unsandboxed_object[mutated_key] = mutated_value
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

return function(context: sandbox_types.SandboxContext, value: any)
    local filtered_patches = patch_filter_selector.find_patches(context.patches)(value)
    
    if #filtered_patches == 0 then
        -- no patches to apply to the object
        return value
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
        [s.SETTER_PATCHES_SYMBOL] = setter_patches,
        [s.GETTER_PATCHES_SYMBOL] = getter_patches,
        [s.PATCH_STORAGE_SYMBOL] = {},
        [s.UNSANDBOXED_OBJECT] = value,
        [s.SANDBOX_CONTEXT] = context
    }

    return setmetatable(sandboxed, metatable)
end