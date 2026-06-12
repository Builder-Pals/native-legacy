local sandbox = require("@layer/sandbox")
local patching = sandbox.patching

local ROBLOX_USER_ID = 1

-- Player.UserId will always return 1 (The User ID of Roblox's account)
local patch = patching.getter_patch {
	classes = { "Player" },
	keys = { "UserId", "userId" },
	run = function(context: sandbox.PatchedContext, key: any)
		print("yeah, we're roblox!", context, key)
		return ROBLOX_USER_ID
	end,
}

return patching.module(patch)
