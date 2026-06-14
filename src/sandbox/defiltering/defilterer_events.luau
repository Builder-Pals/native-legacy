local Action = require("@layer/util/Action")

local defilterer_events = {
    send_property = Action.new() :: Action.Action<Instance, string, unknown>,
    send_property_unreliable = Action.new() :: Action.Action<Instance, string, unknown>,
    add_debris = Action.new() :: Action.Action<Instance, number>
}

return defilterer_events
