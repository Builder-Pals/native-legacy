local sandbox_types = require("@layer/sandbox/sandbox_types")
local patch_types = require("./patch_types")

type PatchInfoBase = {
    --- What types shouold the patch apply to?
    types: { string }?,
    --- What classes to the patch apply to?
    classes: { string }?,
    --- What keys to the patch apply to?
    keys: { any }?,
    --- Are there any additional filters to check if the patch is right for this object?
    special_conditions: { patch_types.SpecialCondition }?, 
    --- Should the patch have priority over any other patches?
    priority: number?,
}

export type GetterPatchInfo = PatchInfoBase & {
    run: sandbox_types.GetterPatchRun
}

export type SetterPatchInfo = PatchInfoBase & {
    run: sandbox_types.SetterPatchRun
}

local patch_creator = {}

function patch_creator.new_getter_patch(data: GetterPatchInfo): patch_types.Patch
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

    return patch :: patch_types.Patch
end

function patch_creator.new_setter_patch(data: SetterPatchInfo): patch_types.Patch
    local patch = {
        type = "patch",
        kind = "setter_patch" :: "setter_patch",

        types = data.types,
        classes = data.classes,
        keys = data.keys,
        priority = data.priority,

        run = data.run
    } :: sandbox_types.SetterPatch

    return patch :: patch_types.Patch
end

return patch_creator