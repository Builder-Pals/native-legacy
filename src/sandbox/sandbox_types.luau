--- Provides context & configuration for the current sandbox.
export type SandboxContext = {
    patches: { Patch } 
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

export type GetterPatch = Patch & {
    kind: "getter_patch",
    run: GetterPatchRun,
}

export type SetterPatch = Patch & {
    kind: "setter_patch",
    run: SetterPatchRun,
}

--- A union of all patch types
export type SomePatch = GetterPatch | SetterPatch

--- Optional condition to determine hwen a patch should run.
export type PatchCondition = "run_on_unpatched"

--- A union of all patch types.
export type PatchKind = "getter_patch" | "setter_patch"

--- Container for all base information about a patch
export type Patch = {
    type: "patch",
    kind: PatchKind,
    types: { string }?,
    keys: { any }?,
    classes: { string }?,
    special_conditions: { PatchCondition }?,
    priority: number?,
}

type PatchInfoBase = {
    --- What types shouold the patch apply to?
    types: { string }?,
    --- What classes to the patch apply to?
    classes: { string }?,
    --- What keys to the patch apply to?
    keys: { any }?,
    --- Are there any additional filters to check if the patch is right for this object?
    special_conditions: { PatchCondition }?, 
    --- Should the patch have priority over any other patches?
    priority: number?,
}

export type GetterPatchInfo = PatchInfoBase & {
    run: GetterPatchRun
}

export type SetterPatchInfo = PatchInfoBase & {
    run: SetterPatchRun
}

return nil