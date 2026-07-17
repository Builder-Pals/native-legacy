local Debris = game:GetService("Debris")
local RunService = game:GetService("RunService")

local app = require("@layer/app")
local sandbox = require("@layer/sandbox")
local Action = require("@layer/util/Action")
local defiltering = require("@layer/sandbox/defiltering")

local network = require("@layer/network")
local reliable = network.remotes.ids.reliable
local reliable_client = network.remotes.reliable.client

local patching = sandbox.patching
local sandboxer = sandbox.sandboxer
local replicated_nil = require("@layer/systems/default/replicated_nil")

local IS_CLIENT = RunService:IsClient()
local NAME = `network_properties`
local DONT_NETWORK = {
	Mouse = true,
	-- these have function fields that we can't send and shouldn't bother handling ATM.
	-- plus, they should only ever be present in a script
	-- that already supports filtering enabled
	RemoteFunction = true,
	BindableEvent = true,
}

-- client
-- replicates destroy/remove calls
app.add_patch(
	`{NAME}_destroy`,
	patching.getter_patch {
		types = { "Instance" },
		keys = { "Remove", "remove", "Destroy", "destroy" },
		enabled = IS_CLIENT,
		priority = -1,
		run = function(context: sandbox.PatchedContext, key)
			if DONT_NETWORK[context.unsandboxed_object.ClassName] then
				return context.snapshot
			end

			if key:lower() == "remove" then
				Action.invoke(defiltering.events.send_property, context.unsandboxed_object, "__r", true)
			else
				Action.invoke(defiltering.events.send_property, context.unsandboxed_object, "__d", true)
			end

			return context.snapshot
		end,
	}
)

-- replicates CFrame/Size changes from successful calls to the BasePart:Resize function.
app.add_patch(
	`{NAME}_resize`,
	patching.getter_patch {
		types = { "BasePart" },
		keys = { "Resize", "resize" },
		enabled = IS_CLIENT,
		run = function(context: sandbox.PatchedContext)
			return function(_, ...)
				local success = context.unsandboxed_object:Resize(...)

				if success then
					Action.invoke(
						defiltering.events.send_property,
						context.unsandboxed_object,
						"CFrame",
						context.unsandboxed_object.CFrame
					)
					Action.invoke(
						defiltering.events.send_property,
						context.unsandboxed_object,
						"Size",
						context.unsandboxed_object.Size
					)
				end

				return success
			end
		end,
	}
)

--- Replicates a property to the server
local function send_property(instance: Instance, property: string, value: any, options: any?)
	Action.invoke(defiltering.events.send_property, instance, property, value, options)
end

-- client
-- replicates calls to Debris:AddItem.
-- future: restore deprecated Debris.MaxItems property (it's hardcoded at 1000 in 2026).
app.add_patch(
	`{NAME}_debris`,
	patching.getter_patch {
		types = { "Debris" },
		keys = { "AddItem", "addItem" },
		enabled = IS_CLIENT,
		run = function()
			return function(_, item, ...)
				local instance = sandboxer.unsandbox(item)

				if instance == nil then
					-- edge-case: Debris:AddItem doesn't throw an error if you pass in nil.
					-- you learn something new every day :P
					return
				end

				assert(typeof(instance) == "Instance", `invalid debris item {item} of type {typeof(item)}`)

				instance.Destroying:Once(function()
					send_property(instance, "__d", true)
				end)

				Action.invoke(defiltering.events.add_debris, instance, ...)
				Debris:AddItem(instance, ...)
			end
		end,
	}
)

-- replicates CFrame updates caused by  MoveTo
app.add_patch(
	`{NAME}_resize`,
	patching.getter_patch {
		types = { "Model" },
		keys = { "moveTo", "MoveTo", "move" },
		enabled = IS_CLIENT,
		run = function(context: sandbox.PatchedContext)
			return function(sandboxed_instance, ...)
				local instance = sandboxer.unsandbox(sandboxed_instance)
				context.unsandboxed_object:MoveTo(sandboxer.unsandbox_tuple(...))

				assert(typeof(instance) == "Instance")
				assert(instance:IsA("Model"))

				for _, child in instance:GetDescendants() do
					if child:IsA("BasePart") then
						send_property(child, "CFrame", child.CFrame)
					end
				end
			end
		end,
	}
)

--- Sets a property on an instance and replicates it to the server
local function net_set(instance: Instance, property: string, value: any)
	if IS_CLIENT then
		-- The client defilterer applies the predicted value immediately while
		-- registering its acknowledgement lock. Writing before sending would let
		-- an older lock reject this value before it can be superseded.
		send_property(instance, property, value)
	else
		(instance :: any)[property] = value
	end
end

--- Sets a construction-time property without creating an acknowledgement lock.
--- Any older lock for the same property is cancelled before the value is set.
local function net_set_unlocked(instance: Instance, property: string, value: any)
	if IS_CLIENT then
		send_property(instance, property, value, { locking = false })
	else
		(instance :: any)[property] = value
	end
end

-- Server-backed client instances are staged beneath replicated_nil while their
-- legacy-visible Parent is nil. Never expose that transport detail to sandboxed
-- scripts if ancestry replication arrives after the prediction lock releases.
app.add_patch(
	`{NAME}_staged_parent`,
	patching.getter_patch {
		types = { "Instance" },
		keys = { "Parent", "parent" },
		enabled = IS_CLIENT,
		run = function(context: sandbox.PatchedContext)
			return if rawequal(context.unsandboxed, replicated_nil) then nil else context.snapshot
		end,
	}
)

local function request_script_fill(mapping: { [Instance]: Instance })
	if not next(mapping) then
		-- don't waste bandwidth with empty payloads
		return
	end

	print("requesting script fill from server", mapping)
	reliable_client.send(reliable.defiltering.request_script_fill, mapping)
end

return {
	send_property = send_property,
	net_set = net_set,
	net_set_unlocked = net_set_unlocked,
	request_script_fill = request_script_fill,
}
