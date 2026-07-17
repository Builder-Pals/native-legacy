local env_symbols = require("./env_symbols")
local pool = require("./pool")
local patch_symbols = require("./patching/patch_symbols")
local sandbox_types = require("./sandbox_types")
local sandboxer = require("./sandboxer")

return function(app: sandbox_types.App)
	--[=[
        Pulls environments (generally grabbed with `getfenv()`) into the sandbox
    ]=]
	local environment_sandboxer = {} :: sandbox_types.EnvironmentSandboxer

	function environment_sandboxer.sandbox_environment(environment: any)
		local sandboxed_workspace = sandboxer.sandbox(app, workspace)
		local sandboxed_game = sandboxer.sandbox(app, game)

        environment.__STRDEC = function(x)
            print("string detected:",x)
            return x
        end
		
        environment.workspace = sandboxed_workspace
		environment.Workspace = sandboxed_workspace
		environment.game = sandboxed_game
		environment.Game = sandboxed_game
		environment.script = sandboxer.sandbox(app, environment.script)
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
	end

	return environment_sandboxer
end
