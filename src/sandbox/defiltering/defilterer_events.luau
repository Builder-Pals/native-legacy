local Action = require("@layer/util/Action")

local defilterer_events = {
    send_property = Action.new() :: Action.Action<Instance, string, unknown>
}

return defilterer_events
