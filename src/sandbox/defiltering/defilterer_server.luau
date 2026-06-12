local remotes = require("@layer/network/remotes")
local defilter_serdes = require("./defilter_serdes")

local function apply(instance: any, property: any, value: any)
	print(`{instance}.{property} = {value}`)

	if property == "__r" then
		instance.Parent = nil
	elseif property == "__d" then
		instance:Destroy()
	else
		instance[property] = value
	end
end

return function()
	remotes.reliable.server.subscribe(
		{},
		remotes.ids.reliable.defiltering.send_properties,
		function(_player, properties: any)
			print("payload", properties)
			defilter_serdes.deserialize_payload(properties, apply)
		end
	)

	remotes.unreliable.server.subscribe(
		{},
		remotes.ids.unreliable.defiltering.send_properties,
		function(_player, properties: any)
			defilter_serdes.deserialize_payload(properties, apply)
		end
	)
end
