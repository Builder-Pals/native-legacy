local sandbox_types = require("../sandbox_types")

local patch_module_creator = {}

function patch_module_creator.simple(id: string, patch: sandbox_types.Patch): sandbox_types.PatchGroup
    if not patch.id then
        patch.id = id
    end

    return {
        id = id,
        enabled = true,
        patches = {patch}
    }
end

function patch_module_creator.group(patch: sandbox_types.PatchGroup): sandbox_types.PatchGroup
    return patch
end

return patch_module_creator