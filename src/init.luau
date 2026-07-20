local app = require("@self/app")
local deck = require("@self/deck")
local nl_tags = require("@self/nl_tags")

script:AddTag(nl_tags.RELOAD_PROTECTION)

return {
    --- pulls an environment into the sandbox.
    enter_sandbox = function(env)
        local environment_sandboxer = app.context.bag.get(app.context.bag.entries.environment_sandboxer)
        environment_sandboxer.sandbox_environment(env)
    end,
    
    boot = require("@self/boot").boot,
    unpack_from_marketplace_async = deck.unpacker.unpack_from_marketplace_async,
    web = require("@self/web"),
}