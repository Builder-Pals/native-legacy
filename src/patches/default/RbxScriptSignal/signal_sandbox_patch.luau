local patch_creator = require("@layer/patching/patch_creator")
local patch_module_creator = require("@layer/patching/patch_module_creator")
local sandbox_types = require("@layer/sandbox/sandbox_types")
local sandboxer = require("@layer/sandbox/sandboxer")

--- Ensures values passed through RBXScriptSignals are sandboxed
local patch = patch_creator.new_getter_patch({
    classes = {},
    types = { "RBXScriptSignal" },
    run = function(context: sandbox_types.PatchedContext, _key: any)
        print("we're sandboxing a signal")

        return function(_, unsandboxed_listener)
            local tuple_sandboxer = sandboxer.sandbox_tuple(context.sandbox_context)

            local sandboxed_listener = function(...)
                unsandboxed_listener(tuple_sandboxer(...))
            end

            return context.unsandboxed(context.unsandboxed_object, sandboxed_listener)
        end
    end
} :: patch_creator.GetterPatchInfo)

return patch_module_creator.simple(patch)