local patch_types = require("@layer/patching/patch_types")

--- Provides context & configuration for the current sandbox.
export type SandboxContext = {
    patches: { patch_types.Patch } 
}

export type PatchedContext<TObject=any> = {
    --- Similar to Snapshots in Harmony - the value (potentially with prior patches applied)
    snapshot: any,
    --- Similar to Original in Harmony - the raw value without any patches
    unsandboxed: any,
    unsandboxed_object: any,
    sandbox_context: SandboxContext,
    storage: { [any]: any },
}

export type GetterPatchRun = ( context: PatchedContext, key: any ) -> ( any )
export type SetterPatchRun = ( context: PatchedContext, key: any, value: any ) -> ( any )

export type GetterPatch = patch_types.Patch & {
    kind: "getter_patch",
    run: GetterPatchRun,
}

export type SetterPatch = patch_types.Patch & {
    kind: "setter_patch",
    run: SetterPatchRun,
}

export type SomePatch = GetterPatch | SetterPatch

return nil