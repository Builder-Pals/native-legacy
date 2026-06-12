local sandbox_types = require("../sandbox_types")

local patch_module_creator = {}

function patch_module_creator.simple(patch: sandbox_types.Patch)
    return { patch }
end

function patch_module_creator.group(patches: { sandbox_types.Patch })
    return patches
end

return patch_module_creator