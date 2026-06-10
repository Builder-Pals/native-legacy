local patch_creator = require("@layer/patching/patch_creator")
local patch_module_creator = require("@layer/patching/patch_module_creator")
local sandbox_types = require("@layer/sandbox/sandbox_types")

local ROBLOX_USER_ID = 1

-- Spoofs player.UserId to always return the Roblox accounts user id
local patch = patch_creator.new_getter_patch({
    classes = { "Player" },
    keys = { "UserId", "userId" },
    run = function(context: sandbox_types.PatchedContext, key: any)
        print("yeah, we're roblox!", context, key)
        return ROBLOX_USER_ID
    end
} :: patch_creator.GetterPatchInfo)

return patch_module_creator.simple(patch)