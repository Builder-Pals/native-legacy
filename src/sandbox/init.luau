local RunService = game:GetService("RunService")

local sandbox_types = require("@self/sandbox_types")

-- gotta export them all manually. i hope luau gets a better solution for this later :P

export type SandboxContext = sandbox_types.App

--- Contains context about values that exist within the sandbox.
export type PatchedContext<TObject=any> = sandbox_types.PatchedContext<TObject>
export type GetterPatchRun = sandbox_types.GetterPatchRun
export type SetterPatchRun = sandbox_types.SetterPatchRun
export type GetterPatch = sandbox_types.GetterPatch
export type SetterPatch = sandbox_types.SetterPatch
export type SomePatch = sandbox_types.SomePatch
export type PatchCondition = sandbox_types.PatchCondition
export type PatchKind = sandbox_types.PatchKind
export type Patch = sandbox_types.Patch

export type GetterPatchInfo = sandbox_types.GetterPatchInfo
export type SetterPatchInfo = sandbox_types.SetterPatchInfo

export type App = sandbox_types.App

local is_initialized = false

return {
    pool = require("@self/pool"),
    environment_sandboxer = require("@self/environment_sandboxer"),
    patching = require("@self/patching"),
    sandboxer = require("@self/sandboxer"),
    init = function()
        assert(not is_initialized, "sandbox has already been initialized!")
        is_initialized = true

        if RunService:IsServer() then
           require("@self/pool").server_pool()
        end

        local sandboxer = require("@self/sandboxer")
        local sandbox_wrapper = require("@self/sandbox_wrapper")

        sandboxer.register("Instance", sandbox_wrapper)
        sandboxer.register("RBXScriptSignal", sandbox_wrapper)
        sandboxer.register("RBXScriptConnection", sandbox_wrapper)
    end
}