export type SpecialCondition = "run_on_unpatched"
export type PatchKinds = "getter_patch" | "setter_patch"

export type Patch = {
    type: "patch",
    kind: PatchKinds,
    types: { string }?,
    keys: { any }?,
    classes: { string }?,
    special_conditions: { SpecialCondition }?,
    priority: number?,
}

return nil