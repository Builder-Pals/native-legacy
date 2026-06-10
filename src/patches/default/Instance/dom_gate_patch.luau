local patch_creator = require("@layer/patching/patch_creator")
local patch_module_creator = require("@layer/patching/patch_module_creator")
local sandbox_types = require("@layer/sandbox/sandbox_types")
local sandboxer = require("@layer/sandbox/sandboxer")

-- Data Object Model Gate (DOM Gate)
-- Ensures things coming in/out of the DOM are sandboxed/unsandboxed appropriately.

local patch = patch_creator.new_getter_patch({
    types = { "Instance" },
    priority = -1,
    run = function(context: sandbox_types.PatchedContext, _key: any)
        local is_unsandboxed = rawequal(context.snapshot, context.unsandboxed)

        if not is_unsandboxed then
            return context.snapshot
        end

        local t = typeof(context.snapshot)

        if t == "function" then
            local tuple_sandboxer = sandboxer.sandbox_tuple(context.sandbox_context)

            return function(...)
                return tuple_sandboxer(context.unsandboxed(sandboxer.unsandbox_tuple(...)))
            end
        elseif t == "Instance" then
            return sandboxer.sandbox(context.sandbox_context, context.unsandboxed)
        end

        return sandboxer.sandbox(context.sandbox_context, context.snapshot)
    end
} :: patch_creator.GetterPatchInfo)

return patch_module_creator.simple(patch)