local app = require("@layer/app")
local sandbox = require("@layer/sandbox")
local patching = sandbox.patching

-- scripts can set instance names, but exclamation marks will be added to the end
local patch = patching.setter_patch {
	types = { "Instance" },
	keys = { "Name", "name" },
	run = function(context: sandbox.PatchedContext, _key: any, value: any)
		context.unsandboxed_object.Name = `{value}!!`
        return nil
    end,
}

return app.add_patch("shouty_instance_names", patch, false)
