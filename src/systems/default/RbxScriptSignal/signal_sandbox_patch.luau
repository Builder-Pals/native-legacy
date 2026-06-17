local app = require("@layer/app")
local sandbox = require("@layer/sandbox")
local patching = sandbox.patching
local sandboxer = sandbox.sandboxer

-- prevents RBXScriptSignals from causing sandbox escapes and 'restores' deprecated methods

local patch = patching.getter_patch {
	classes = patching.ALL_CLASSES,
	types = { "RBXScriptSignal" },
	run = function(context: sandbox.PatchedContext, key)
		-- sandboxes all values passed through RBXScriptSignals to prevent escapes.

		if key == "connect" or key == "Connect" then
			return function(_self, unsandboxed_listener)
				local tuple_sandboxer = sandboxer.sandbox_tuple(context.sandbox_context)

				local sandboxed_listener = function(...)
					unsandboxed_listener(tuple_sandboxer(...))
				end

				return context.unsandboxed(context.unsandboxed_object, sandboxed_listener)
			end
		end

		-- prevents `RBXScriptSignal:disconnect` from throwing an error.
		-- https://github.com/Fizzyhex/nostalgic-layer/issues/19

		if key == "disconnect" then
			warn(`RBXScriptSignal:{key} has been called. Instead of throwing an error, nothing will happen. {debug.traceback()}`)
			return function(_self, callback)
				assert(typeof(callback) == "function")
			end
		end

		return context.unsandboxed_object[key]
	end,
}

app.add_patch("signal_sandbox", patch)

return nil
