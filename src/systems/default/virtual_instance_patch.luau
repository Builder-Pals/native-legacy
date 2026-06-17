local RunService = game:GetService("RunService")

local app = require("@layer/app")
local sandbox = require("@layer/sandbox")
local virtual_instance = require("@layer/sandbox/virtual_instance")

local patching = sandbox.patching

local holders = virtual_instance.util.holders
local value_storage = virtual_instance.util.value_storage
local call_storage = virtual_instance.util.call_storage

-- luau hack. cant turn off dynaimc property access lints afaik.
type AllowDynamicProperty = Instance & {}

local function get_resolution(instance: Instance)
	return (instance.Parent :: ObjectValue).Value :: AllowDynamicProperty
end

local function is_resolved(instance: Instance)
	return instance:HasTag(virtual_instance.constants.RESOLVED_TAG)
end

local setter_patch = patching.setter_patch {
	types = { "Instance" },
	run = function(context, key, value)
		local instance = context.unsandboxed_object
		local index = table.find(holders, instance)

		if not index then
			return key, value
		end

		if is_resolved(instance) then
			get_resolution(instance)[key] = value
		end

		instance[key] = value
		value_storage[index][key] = value

		print("virtual set", key, value)
		return key, value
	end,
}

local getter_patch = patching.getter_patch {
	types = { "Instance" },
	run = function(context, key)
		local instance = context.unsandboxed_object
		local index = table.find(holders, instance)

		if not index then
			return instance[key]
		end

		if is_resolved(instance) then
			print("virtualizing redirector method", key)
			local resolution = get_resolution(instance)
			local method = (resolution :: AllowDynamicProperty)[key]

			return function(_self, ...)
				method(...)
			end
		end

		if typeof(context.snapshot) == "function" then
			print("virtualizing method", key)
			local method = context.snapshot :: (...any) -> ...any

			return function(_self, ...)
				table.insert(call_storage[index], {
					key = key,
					args = table.pack(key, ...),
				})

				method(_self, ...)
			end
		end

		return instance[key]
	end,
}

app.add_patch_group {
	enabled = RunService:IsClient(),
	patches = { setter_patch, getter_patch },
}

return nil
