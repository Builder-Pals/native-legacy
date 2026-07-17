local Action = require("@layer/util/Action")

export type SendPropertyOptions = {
    -- The value that should remain visible on this client when it differs from
    -- the value used to represent it on the server.
    local_value: unknown?,
    use_local_value: boolean?,
    -- Construction writes are applied locally without creating an ordinary
    -- acknowledgement lock for every copied property.
    locking: boolean?,
}

local defilterer_events = {
    send_property = Action.new() :: Action.Action<Instance, string, unknown, SendPropertyOptions?>,
    send_property_unreliable = Action.new() :: Action.Action<Instance, string, unknown>,
    cancel_instance = Action.new() :: Action.Action<Instance>,
    add_debris = Action.new() :: Action.Action<Instance, number>,
}

return defilterer_events
