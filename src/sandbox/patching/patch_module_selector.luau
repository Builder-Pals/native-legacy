local sandbox_types = require("@layer/sandbox/sandbox_types")

export type PatchModule = any

local patch_module_selector = {}

function patch_module_selector.get_patches(patch_module: PatchModule): { sandbox_types.Patch }
    local is_single = patch_module.kind ~= nil

    if is_single then
        return { patch_module }
    end

    local patches = {}

    for _, patch in patch_module do
        table.insert(patches, patch :: sandbox_types.Patch)
    end

    return patches
end

return patch_module_selector