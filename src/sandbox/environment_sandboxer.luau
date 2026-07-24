local nl_tags = require("../nl_tags")
local env_symbols = require("./env_symbols")
local pool = require("./pool")
local patch_symbols = require("./patching/patch_symbols")
local sandbox_types = require("./sandbox_types")
local sandboxer = require("./sandboxer")
local vars = require("../vars")

local RunService = game:GetService("RunService")

-- Legacy spawn resumed on the throttled scheduler, which ran at
-- roughly 30 Hz
const LEGACY_SPAWN_DELAY = 1 / 30

local function sandboxed_require(module_or_id)
	local unsandboxed = sandboxer.unsandbox(module_or_id)

	if typeof(unsandboxed) == "Instance" then
		error("numeric requires are not supported!")
	end

	return require(unsandboxed :: any) :: any
end

return function(app: sandbox_types.App)
	--[=[
        Pulls environments (generally grabbed with `getfenv()`) into the sandbox
    ]=]
	local environment_sandboxer = {} :: sandbox_types.EnvironmentSandboxer

	function environment_sandboxer.sandbox_environment(environment: any)
		local sandboxed_workspace = sandboxer.sandbox(app, workspace)
		local sandboxed_game = sandboxer.sandbox(app, game)

		environment.__STRDEC = function(x)
			return x
		end

		if environment.script:HasTag(nl_tags.POINTER_SCRIPT) then
			environment.script = environment.script.Parent
		end

		environment.workspace = sandboxed_workspace
		environment.Workspace = sandboxed_workspace
		environment.game = sandboxed_game
		environment.Game = sandboxed_game
		environment.script = sandboxer.sandbox(app, environment.script)
		environment.require = sandboxed_require
		environment[env_symbols.SOURCE_SCRIPT] = environment.script

		environment.typeof = function(x)
			if typeof(x) == "table" then
				return rawget(x, patch_symbols.FAKE_TYPEOF) or typeof(sandboxer.unsandbox(x))
			end

			return typeof(x)
		end

		environment.type = function(x)
			if type(x) == "table" then
				return rawget(x, patch_symbols.FAKE_TYPE) or type(sandboxer.unsandbox(x))
			end

			return type(x)
		end

		environment.Instance = pool.new_instance_lib(app)

		local function wait_multiplier(): number
			return 1 / vars.modifier.get_var(app.vars, vars.defs.sv_timescale_wait)
		end

		environment.wait = function(duration: number?)
			while vars.modifier.get_var(app.vars, vars.defs.sv_timescale_freeze) do
				RunService.Heartbeat:Wait()
			end

            local start = os.clock()
			local timer = duration or 0

            repeat
                timer -= task.wait(LEGACY_SPAWN_DELAY)
            until timer <= 0

			return os.clock() - start, elapsedTime()
		end

		environment.delay = function(duration: number, callback: () -> ())
			local timer = duration

			while timer > 0 do
				timer -= task.wait(LEGACY_SPAWN_DELAY) * wait_multiplier()
			end

			return task.spawn(callback)
		end

		environment.spawn = function(callback: () -> ())
			return task.defer(callback)
		end
	end

	return environment_sandboxer
end
