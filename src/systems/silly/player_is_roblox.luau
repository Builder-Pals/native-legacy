local app = require("@layer/app")
local sandbox = require("@layer/sandbox")
local patching = sandbox.patching

local ROBLOX_USER_ID = 1

-- Player.UserId will always return 1, tricking scripts into treating you like the Roblox account
app.add_patch("player_is_roblox", patching.getter_patch {
	classes = { "Player" },
	keys = { "UserId", "userId" },
	run = function(context, _key)
		local player = context.unsandboxed_object
		print(`yeah, {player} is roblox!`)
		return ROBLOX_USER_ID
	end,
}, false) -- <-- remove this param or set to true to activate!

return nil