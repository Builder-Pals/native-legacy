local app = require("@self/app")

return {
    --- pulls an environment into the sandbox.
    enter_sandbox = function(env)
        local environment_sandboxer = app.context.bag.get(app.context.bag.entries.environment_sandboxer)
        environment_sandboxer.sandbox_environment(env)
    end,
    
    boot = require("@self/boot"),
    conversion = require("@self/conversion"),
    load_game_from_id = app.load_game_from_id
}