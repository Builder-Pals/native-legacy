local Debris = game:GetService("Debris")
local network = require("@layer/network")
local nl_tags = require("../../nl_tags")
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

	remotes.reliable.server.subscribe({}, remotes.ids.reliable.defiltering.request_script_fill, function(_, mapping)
		assert(typeof(mapping) == "table")

		for _, array: unknown in mapping do
			if typeof(array) ~= "table" then
				continue
			end

			local copy = (array :: { unknown })[1]
			local original = (array :: { unknown })[2]

			if typeof(copy) ~= "Instance" then
				continue
			end

			if original == nil then
				warn(`[defiltering_server] unknown script {copy:GetFullName()}`)
				continue
			end

			if typeof(original) ~= "Instance" then
				continue
			end

			if not copy:IsA("Script") and not copy:IsA("LocalScript") and not copy:IsA("ModuleScript") then
				continue
			end

			if not original:IsA("ModuleScript") and not original:IsA("Script") and not original:IsA("LocalScript") then
				continue
			end

			local existing = copy:FindFirstChild(nl_tags.POINTER_SCRIPT)

			if existing then
				existing:Destroy()
			end

			local clone = original:Clone()
			clone.Name = "__nl"
			clone:AddTag(nl_tags.POINTER_SCRIPT)
			clone:AddTag(nl_tags.NL_HIDDEN)
			clone.Enabled = copy.Enabled
			clone.Parent = copy

			copy:GetPropertyChangedSignal("Enabled"):Connect(function()
				clone.Enabled = copy.Enabled
			end)
		end
	end)
end
