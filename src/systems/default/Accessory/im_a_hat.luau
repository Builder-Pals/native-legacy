local app = require("@layer/app")

local sandbox = require("@layer/sandbox")
local patching = sandbox.patching

-- accessories replaced hats long ago. this patch makes accessories appear to be hats for old scripts.
app.add_patch(
	"im_a_hat",
	patching.getter_patch {
		classes = { "Accessory" },
		keys = { "className", "ClassName" },
		run = function(_)
			return function(_)
				return "Hat"
			end
		end,
	}
)