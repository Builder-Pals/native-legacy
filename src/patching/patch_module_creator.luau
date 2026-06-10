local patch_types = require("./patch_types")

local patch_module_creator = {}

function patch_module_creator.simple(patch: patch_types.Patch)
    return patch
end

function patch_module_creator.group(patches: { patch_types.Patch })
    return patches
end

return patch_module_creator