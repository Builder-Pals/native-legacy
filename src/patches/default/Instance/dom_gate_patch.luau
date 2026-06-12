local sandbox = require("@layer/sandbox")
local patching = sandbox.patching
local sandboxer = sandbox.sandboxer

-- Data Object Model Gate (DOM Gate)
-- Ensures things coming in/out of the DOM are sandboxed/unsandboxed appropriately.

local patch = patching.getter_patch {
	types = { "Instance" },
	priority = -1,
	run = function(context: sandbox.PatchedContext, _key: any)
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
	end,
}

return patching.module(patch)
