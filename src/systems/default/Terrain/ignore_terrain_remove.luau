local app = require("@layer/app")
local sandbox = require("@layer/sandbox")
local sandboxer = sandbox.sandboxer
local patching = sandbox.patching

--[[
    Some old scripts would loop through the workspace and remove all children.
    This wasn't a problem before Terrain was added, which will throw an error if you attempt to delete it.

    As a bandaid fix, we'll just ignore calls to remove on it to prevent errors.
--]]
app.add_patch(
	"terrain_remove_swalloer",
	patching.getter_patch {
		classes = { "Terrain" },
		keys = { "Remove", "remove" },
		run = function(context, key)
			return function(sandboxed_self, ...)
                local unsandboxed_self = sandboxer.unsandbox(sandboxed_self)
                assert(typeof(unsandboxed_self) == "Instance" and unsandboxed_self:IsA("Terrain"), `Expected ':' not '.' calling member function {key}`)
            end
		end,
	}
)

return nil
