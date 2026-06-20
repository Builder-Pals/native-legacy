
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

return {
    pool = require("@self/pool"),
    environment_sandboxer = require("@self/environment_sandboxer"),
    patching = require("@self/patching"),
    sandboxer = require("@self/sandboxer"),
}