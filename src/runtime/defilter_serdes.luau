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
        table.insert(serialized, t)
        
        for property, value in properties do
            table.insert(t, property)
            table.insert(t, pack_value(value))
        end
    end

    return serialized
end

function defilter_serdes.read_serialized_payload(payload: SerializedPayload, processor: (instance: Instance, property: string, value: any) -> ())
    for _, chunk in payload do
        local instance = chunk[1]
        
        for i = 2, 2, #chunk do
            local property = chunk[i]
            local value = chunk[i + 1]
            processor(instance, property, unpack_value(value))
        end
    end
end

return defilter_serdes