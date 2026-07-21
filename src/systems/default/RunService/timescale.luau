local app = require("@layer/app")
local FakeSignal = require("@layer/util/FakeSignal")
local sandbox = require("@layer/sandbox")
local vars = require("@layer/vars")

local patching = sandbox.patching

app.add_patch(
	"run_service_timescale",
	patching.getter_patch {
		classes = { "RunService" },
		keys = { "Stepped", "RenderStepped" },
		run = function(context, key)
			local cached_signal = context.storage[key]

			if cached_signal then
				return cached_signal
			end

			local real_signal = sandbox.sandboxer.unsandbox(context.unsandboxed)
			assert(typeof(real_signal) == "RBXScriptSignal")
			local fake_signal = FakeSignal.new(real_signal)

			FakeSignal.bind(fake_signal, real_signal :: RBXScriptSignal<...any>, function(callback)
				return function(...)
					local variable_store = context.sandbox_context.vars

					if vars.modifier.get_var(variable_store, vars.defs.sv_timescale_freeze) then
						return
					end

					local multiplier = vars.modifier.get_var(variable_store, vars.defs.sv_timescale_run_service)
					local delta_scale = 1 / multiplier

					if key == "Stepped" then
						local elapsed_time, delta_time = ...
						callback(elapsed_time * delta_scale, delta_time * delta_scale)
					else
						local delta_time = ...
						callback(delta_time * delta_scale)
					end
				end
			end)

			context.storage[key] = fake_signal
			return fake_signal
		end,
	}
)

return nil
