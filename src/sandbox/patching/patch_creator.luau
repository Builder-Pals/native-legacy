local sandbox_types = require("@layer/sandbox/sandbox_types")

local patch_creator = {}

function patch_creator.new_getter_patch(data: sandbox_types.GetterPatchInfo): sandbox_types.Patch
    local patch = {
        type = "patch",
        kind = "getter_patch" :: "getter_patch",

        types = data.types,
        classes = data.classes,
        keys = data.keys,
        special_conditions = data.special_conditions,
        priority = data.priority,

        run = data.run
    } :: sandbox_types.GetterPatch

    return patch :: sandbox_types.Patch
end

--[=[
    ```luau
    {
        --- What types shouold the patch apply to?
        types: { string }?,
        --- What classes to the patch apply to?
        classes: { string }?,
        --- What keys to the patch apply to?
        keys: { any }?,
        --- Are there any additional filters to check if the patch is right for this object?
        special_conditions: { PatchCondition }?,
        --- Should the patch have priority over any other patches?
        priority: number?,
        --- The patch itself!
        run: (context: PatchedContext, key: any, value: any) -> any
    }
    ```
]=]
function patch_creator.new_setter_patch(data: sandbox_types.SetterPatchInfo): sandbox_types.Patch
    local patch = {
        type = "patch",
        kind = "setter_patch" :: "setter_patch",

        types = data.types,
        classes = data.classes,
        keys = data.keys,
        priority = data.priority,

        run = data.run
    } :: sandbox_types.SetterPatch

    return patch :: sandbox_types.Patch
end

return patch_creator