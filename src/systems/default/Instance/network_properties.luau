local Debris = game:GetService("Debris")
local RunService = game:GetService("RunService")

local app = require("@layer/app")
local sandbox = require("@layer/sandbox")
local Action = require("@layer/util/Action")
local defiltering = require("@layer/sandbox/defiltering")

local patching = sandbox.patching
local sandboxer = sandbox.sandboxer

local IS_CLIENT = RunService:IsClient()
local NAME = `network_properties`
local DONT_NETWORK = { Mouse = true }

-- client
-- replicates property changes to the server
app.add_patch(
	`{NAME}_changes`,
	patching.setter_patch {
		types = { "Instance" },
		enabled = IS_CLIENT,
		priority = -1,
		run = function(context: sandbox.PatchedContext, key: any, value: any)
			if DONT_NETWORK[context.unsandboxed_object.ClassName] then
				return key, value
			end

			-- property didn't change, no need to network
			if context.unsandboxed_object[key] == sandboxer.unsandbox(value) then
				return key, value
			end

			-- future: this would cause issues in cases where things are put under the camera and then moved out.
			-- the server could create stuff we parent to nil in player gui, and then we can move it out at any time?

			if workspace.CurrentCamera and context.unsandboxed_object:IsDescendantOf(workspace.CurrentCamera) then
				return key, value
			end

			-- if not context.unsandboxed_object:IsDescendantOf(game) then
			-- 	return key, value
			-- end

			Action.invoke(defiltering.events.send_property, context.unsandboxed_object, key, sandboxer.unsandbox(value))
			return key, value
		end,
	}
)

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
-- this causes some rubber-banding as the server sends Size requests back to the client, but its acceptable for now.
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
				assert(typeof(instance) == "Instance")

				instance.Destroying:Once(function()
					Action.invoke(defiltering.events.send_property, instance, "__d", true)
				end)

				Action.invoke(defiltering.events.add_debris, instance, ...)
				Debris:AddItem(instance, ...)
			end
		end,
	}
)

return nil
