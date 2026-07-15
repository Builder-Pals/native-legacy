type DeserializedPayload = { [Instance]: { [string]: any } }

type SerializedPayload = { { any } | number }

local function pack_value(value: any): any
	return if typeof(value) == "Instance" then { value } else value
end

local function unpack_value(value: any): (boolean, any)
	if typeof(value) == "table" then
		local first = (value :: any)[1]
		return first ~= nil, first
	end

	return true, value
end

local defilter_serdes = {}

function defilter_serdes.serialize_payload(payload: DeserializedPayload, ak: number): SerializedPayload
	local serialized: SerializedPayload = { ak }

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

function defilter_serdes.deserialize_payload(
	payload: SerializedPayload,
	processor: (instance: Instance, property: string, value: any) -> ()
): number
	local ak = 0

	for _, chunk in payload do
		if typeof(chunk) == "number" then
			ak = chunk
			continue
		end
		
		local instance = chunk[1]

		-- iterate backwards to preserve setting property order
		-- probably doesn't matter, but better safe than sorry :P
		for i = #chunk, 2, -2 do
			local value = chunk[i]
			local property = chunk[i - 1]

			if property == "a" then
				ak = value
				continue
			end 

            local success, unpacked_value = unpack_value(value)
			
            -- in the event the client sends an instance to us that doesn't exist on the server,
            -- we don't want to set any properties - we might end up deleting something accidentally
            -- otherwise.
            if success then
                processor(instance, property, unpacked_value)
            end
		end
	end

	return ak
end

return defilter_serdes
