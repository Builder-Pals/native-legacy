local sandbox = require("@layer/sandbox")
local patching = sandbox.patching
local sandboxer = sandbox.sandboxer

--- Ensures values passed through RBXScriptSignals are sandboxed
local patch = patching.getter_patch {
	classes = patching.ALL_CLASSES,
	types = { "RBXScriptSignal" },
	run = function(context: sandbox.PatchedContext, _key: any)
		print("we're sandboxing a signal")

		return function(_self, unsandboxed_listener)
			local tuple_sandboxer = sandboxer.sandbox_tuple(context.sandbox_context)

			local sandboxed_listener = function(...)
				unsandboxed_listener(tuple_sandboxer(...))
			end

			return context.unsandboxed(context.unsandboxed_object, sandboxed_listener)
		end
	end,
}

return patching.module(patch)
