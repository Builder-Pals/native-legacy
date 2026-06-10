local remotes = require("@layer/network/remotes")
local defilter_serdes = require("./defilter_serdes")

local function apply(instance: any, property: any, value: any)
    instance[property] = value
end

remotes.reliable.server.subscribe({}, remotes.ids.reliable.defiltering.send_properties, function(_player, properties: any)
    defilter_serdes.read_serialized_payload(properties, apply)
end)

remotes.unreliable.server.subscribe({}, remotes.ids.unreliable.defiltering.send_properties, function(_player, properties: any)
    defilter_serdes.read_serialized_payload(properties, apply)
end)