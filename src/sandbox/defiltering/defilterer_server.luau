local Debris = game:GetService("Debris")
local network = require("@layer/network")
local remotes = network.remotes
local change_tracker = network.change_tracker
local defilter_serdes = require("./defilter_serdes")

local function apply(instance: any, property: any, value: any)
	--print(instance, `.{property} = {value}`)

	if not instance then
		return
	end

	if property == "__r" then
		instance.Parent = nil
	elseif property == "__d" then
		instance:Destroy()
	else
		instance[property] = value
		change_tracker.server_change(instance, property)
	end
end

return function()
	remotes.reliable.server.subscribe(
		{},
		remotes.ids.reliable.defiltering.send_properties,
		function(_player, properties: any)
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

	remotes.reliable.server.subscribe(
		{},
		remotes.ids.reliable.defiltering.add_debris,
		function(_player, item: unknown, lifetime: unknown)
			assert(typeof(item) == "Instance")
			assert(typeof(lifetime) == "number")
			Debris:AddItem(item, lifetime)
		end
	)
end
