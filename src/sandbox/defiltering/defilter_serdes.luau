export type PropertyOperation = {
	instance: Instance,
	property: string,
	value: any,
	active: boolean,
}

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

function defilter_serdes.serialize_payload(payload: { PropertyOperation }, ak: number): SerializedPayload
	local serialized: SerializedPayload = { ak }
	local current_instance: Instance? = nil
	local current_chunk: { any }? = nil

	for _, operation in payload do
		if not operation.active then
			continue
		end

		if current_instance ~= operation.instance then
			current_instance = operation.instance
			current_chunk = { operation.instance }
			table.insert(serialized, current_chunk)
		end

		local chunk = current_chunk :: { any }
		table.insert(chunk, operation.property)
		table.insert(chunk, pack_value(operation.value))
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

		-- Property order is significant while constructing physical assemblies.
		-- In particular, transforms must arrive before joint endpoints and the
		-- completed root must not be exposed until its descendants are ready.
		for i = 2, #chunk, 2 do
			local property = chunk[i]
			local value = chunk[i + 1]

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
