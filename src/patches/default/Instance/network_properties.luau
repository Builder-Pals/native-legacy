local RunService = game:GetService("RunService")

local patch_creator = require("@layer/patching/patch_creator")
local patch_module_creator = require("@layer/patching/patch_module_creator")
local sandbox_types = require("@layer/sandbox/sandbox_types")
local sandboxer = require("@layer/sandbox/sandboxer")
local defilterer_context = require("@layer/defiltering/defilterer_context")
local Action = require("@layer/util/Action")

if RunService:IsServer() then
    return patch_module_creator.group({})
end

local patch = patch_creator.new_setter_patch({
    types = { "Instance" },
    run = function(context: sandbox_types.PatchedContext, key: any, value: any)
        if workspace.CurrentCamera and context.unsandboxed_object:IsDescendantOf(workspace.CurrentCamera) then
            return key, value
        end

        if not context.unsandboxed_object:IsDescendantOf(game) then
            return key, value
        end

        Action.invoke(defilterer_context.events.send_property, context.unsandboxed_object, key, sandboxer.unsandbox(value))
        return key, value
    end
} :: patch_creator.SetterPatchInfo)

return patch_module_creator.group({ patch })