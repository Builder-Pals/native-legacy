local app = require("@layer/app")
local sandbox = require("@layer/sandbox")
local sandboxer = sandbox.sandboxer
local patching = sandbox.patching

app.add_patch(
	"vip_badge_spoof",
	patching.getter_patch {
		classes = { "Player" },
		keys = { "IsBestFriendsWith", "isBestFriendsWith" },
		run = function(context, _key)
			local player = context.unsandboxed_object
			return function(_self, ...)
				-- run the original call for throwing errors and maintaining api call delays
				player.IsBestFriendsWith(sandboxer.unsandbox(_self), sandboxer.unsandbox_tuple(...))
				-- then return true anyway :3
				print(`spoofing best friends check`, ...)
				return true
			end
		end,
	}
)

app.add_patch(
	"vip_badge_spoof",
	patching.getter_patch {
		classes = { "BadgeService" },
		keys = { "UserHasBadge", "userHasBadge" },
		run = function(context, _key)
			local badge_service = context.unsandboxed_object
			return function(_self, ...)
				-- run the original call for throwing errors and maintaining api call delays
				badge_service.UserHasBadge(sandbox.sandboxer.unsandbox(_self), sandboxer.unsandbox_tuple(...))
				-- then return true anyway B)
				print(`spoofing badge check`, ...)
				return true
			end
		end,
	}
)

return nil
