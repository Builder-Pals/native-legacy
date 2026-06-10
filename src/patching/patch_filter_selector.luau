local patch_types = require("./patch_types")

type PatchFilter = patch_types.Patch

local NEGATIVE_PRIORITY_OFFSET = 10000000

local patch_filter_selector = {}

function patch_filter_selector.is_patch_for_class(filter: PatchFilter, class: string)
    if not filter.classes then
        return true
    end
    
    for _, value in filter.classes do
        if class == value then
            return true
        end
    end

    return false
end

function patch_filter_selector.is_patch_for_type(filter: PatchFilter, type: string)
    if not filter.types then
        return false
    end
    
    for _, value in filter.types do
        if type == value then
            return true
        end
    end

    return false
end

function patch_filter_selector.is_patch_for_object(filter: PatchFilter, value: any)
    local t = typeof(value)

    if t == "Instance" then
        return patch_filter_selector.is_patch_for_class(filter, value.ClassName) or patch_filter_selector.is_patch_for_type(filter, t)
    end

    return patch_filter_selector.is_patch_for_type(filter, t)
end

--- Creates a filtering function for finding patches that apply to an object.
function patch_filter_selector.find_patches(patches: { patch_types.Patch })
    --- Filters for any patches that belong to the given object.
    return function(x: any)
        local filtered = {}
        
        for _, patch in patches do
            if patch_filter_selector.is_patch_for_object(patch, x) then
                table.insert(filtered, patch)
            end
        end

        return filtered
    end
end

function patch_filter_selector.sort_patches(patches: { patch_types.Patch })
    local sorted = table.clone(patches)

    table.sort(sorted, function(a: patch_types.Patch, b: patch_types.Patch)
        local priority_a = a.priority or 1
        local priority_b = b.priority or 1
        assert(priority_a < NEGATIVE_PRIORITY_OFFSET, `Priorities cannot be above {NEGATIVE_PRIORITY_OFFSET}`)
        assert(priority_b < NEGATIVE_PRIORITY_OFFSET, `Priorities cannot be above {NEGATIVE_PRIORITY_OFFSET}`)

        if priority_a < 0 then
            priority_a = NEGATIVE_PRIORITY_OFFSET + math.abs(priority_a)
        end

        if priority_b < 0 then
            priority_b = NEGATIVE_PRIORITY_OFFSET + math.abs(priority_b)
        end

        return priority_a > priority_b
    end)

    return sorted
end

return patch_filter_selector