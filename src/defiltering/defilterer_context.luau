local Action = require("@layer/util/Action")

local defilterer_context = {}

defilterer_context.events = {
    send_property = Action.new() :: Action.Action<Instance, string, unknown>
}

return defilterer_context
