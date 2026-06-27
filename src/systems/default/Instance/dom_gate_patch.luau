local app = require("@layer/app")
local sandbox = require("@layer/sandbox")
local patching = sandbox.patching
local sandboxer = sandbox.sandboxer

-- Data Object Model Gate (DOM Gate)
-- ensures things coming in/out of the DOM are sandboxed/unsandboxed appropriately.

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
			local trace = debug.traceback("", 2)

			return function(...)
				local result = table.pack(pcall(function(...)
					return tuple_sandboxer(context.unsandboxed(sandboxer.unsandbox_tuple(...)))
				end, ...))

				local ok = table.unpack(result, 1, 1)

				if not ok then
					local failure = table.unpack(result, 2, 2)
					error(`{script.Name} error: {failure}\n(error originated from {context.unsandboxed_object.ClassName}.{_key})\n🧵 {trace}\nargs: {...}`, 0)
				end

				return table.unpack(result, 2)
			end
		elseif t == "Instance" then
			return sandboxer.sandbox(context.sandbox_context, context.unsandboxed)
		end

		return sandboxer.sandbox(context.sandbox_context, context.snapshot)
	end,
}

return app.add_patch("dom_gate", patch)
