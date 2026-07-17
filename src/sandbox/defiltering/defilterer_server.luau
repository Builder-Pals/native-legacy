local Debris = game:GetService("Debris")
local network = require("@layer/network")
local remotes = network.remotes
local defilter_serdes = require("./defilter_serdes")

local function apply(instance: any, property: any, value: any)
	if not instance then
		return
	end

	if property == "__r" then
		instance.Parent = nil
	elseif property == "__d" then
		instance:Destroy()
	elseif property:sub(1, 4) == "__a:" then
		instance:SetAttribute(property:sub(5), value)
	elseif property:sub(1, 4) == "__t:" then
		instance:AddTag(property:sub(5))
	else
		instance[property] = value
	end
end

return function()
	remotes.reliable.server.subscribe(
		{},
		remotes.ids.reliable.defiltering.send_properties,
		function(player, properties: any)
			local ak = defilter_serdes.deserialize_payload(properties, apply)
			remotes.reliable.server.send(remotes.ids.reliable.defiltering.send_properties, player, ak)
		end
	)

	remotes.unreliable.server.subscribe(
		{},
		remotes.ids.unreliable.defiltering.send_properties,
		function(player, properties: any)
			local ak = defilter_serdes.deserialize_payload(properties, apply)
			remotes.reliable.server.send(remotes.ids.reliable.defiltering.send_properties, player, ak)
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
