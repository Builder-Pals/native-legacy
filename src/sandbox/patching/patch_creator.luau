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