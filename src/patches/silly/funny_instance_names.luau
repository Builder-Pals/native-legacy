local patch_creator = require("@layer/patching/patch_creator")
local patch_module_creator = require("@layer/patching/patch_module_creator")
local sandbox_types = require("@layer/sandbox/sandbox_types")

-- Set instance name's will always have '!!' appended to the end
local patch = patch_creator.new_setter_patch({
    types = { "Instance" },
    keys = { "Name", "name" },
    run = function(context: sandbox_types.PatchedContext, _key: any, value: any)
        context.unsandboxed_object.Name = `{value}!!`
    end
} :: patch_creator.SetterPatchInfo)

return patch_module_creator.simple(patch)