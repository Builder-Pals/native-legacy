type DeserializedPayload = { [Instance]: { [string]: any } }

type SerializedPayload = { { any } }

local function pack_value(value: any): any
    return if typeof(value) == "Instance" then { value } else value
end

local function unpack_value(value: any): any
    return if typeof(value) == "table" then (value :: any)[1] else value
end

local defilter_serdes = {}

function defilter_serdes.serialize_payload(payload: DeserializedPayload): SerializedPayload
    local serialized = {}
    
    for instance, properties in payload do
        local t: { any } = { instance }
        
        for property, value in properties do
            table.insert(t, property)
            table.insert(t, pack_value(value))
        end

        table.insert(serialized, t)
    end

    return serialized
end

function defilter_serdes.deserialize_payload(payload: SerializedPayload, processor: (instance: Instance, property: string, value: any) -> ())
    for _, chunk in payload do
        local instance = chunk[1]
        
        -- iterate backwards to preserve setting property order
        -- probably doesn't matter, but better safe than sorry :P
        for i = #chunk, 2, -2 do
            local value = chunk[i]
            local property = chunk[i - 1]
            processor(instance, property, unpack_value(value))
        end
    end
end

return defilter_serdes