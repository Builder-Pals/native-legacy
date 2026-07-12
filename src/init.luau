local app = require("@self/app")
local loader = require("@self/loader")
local nl_constants = require("@self/nl_constants")

script:AddTag(nl_constants.RELOAD_PROTECTION)

return {
    --- pulls an environment into the sandbox.
    enter_sandbox = function(env)
        local environment_sandboxer = app.context.bag.get(app.context.bag.entries.environment_sandboxer)
        environment_sandboxer.sandbox_environment(env)
    end,
    
    boot = require("@self/boot"),
    load_game_from_id = loader.load_game_from_id
}