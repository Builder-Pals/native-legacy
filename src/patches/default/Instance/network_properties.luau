local RunService = game:GetService("RunService")

local sandbox = require("@layer/sandbox")
local Action = require("@layer/util/Action")
local defiltering = require("@layer/sandbox/defiltering")

local patching = sandbox.patching
local sandboxer = sandbox.sandboxer

if RunService:IsServer() then
	return sandbox.patching.group_module {}
end

--- Replicates property changes to the server.
local patch = patching.setter_patch {
	types = { "Instance" },
	run = function(context: sandbox.PatchedContext, key: any, value: any)
		-- future: this would cause issues in cases where things are put under the camera and then moved out.
		-- the server could create stuff we parent to nil in player gui, and then we can move it out at any time?

		if workspace.CurrentCamera and context.unsandboxed_object:IsDescendantOf(workspace.CurrentCamera) then
			return key, value
		end

		-- if not context.unsandboxed_object:IsDescendantOf(game) then
		-- 	return key, value
		-- end

		print("sending",key,value)
		Action.invoke(defiltering.events.send_property, context.unsandboxed_object, key, sandboxer.unsandbox(value))
		return key, value
	end,
}

return patching.module(patch)
