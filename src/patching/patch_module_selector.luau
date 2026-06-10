local patch_types = require("./patch_types")

export type PatchModule = any

local patch_module_selector = {}

function patch_module_selector.get_patches(patch_module: PatchModule): { patch_types.Patch }
    local is_single = patch_module.kind ~= nil

    if is_single then
        return { patch_module }
    end

    local patches = {}

    for _, patch in patch_module do
        table.insert(patches, patch :: patch_types.Patch)
    end

    return patches
end

return patch_module_selector