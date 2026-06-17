export type OptionalSwitch = boolean?

export type AppSystemFn = (x: App) -> ()

export type AppSystem = {
	id: string,
	enabled: OptionalSwitch,
	run: AppSystemFn,
}

export type BagEntry<T> = { __T: (any) -> T, ["🐟"]: "this is just a luau type wrapper" }

--- All entries available in the service bag, as present in app.luau.
export type BagEntries = {
	environment_sandboxer: BagEntry<EnvironmentSandboxer>,
	client_instance_pool: BagEntry<ClientInstancePool>,
}

--- Provides context & configuration for the runtime application.
export type App = {
	patches: { Patch },
	systems: { AppSystemFn },
	bag: {
		entries: BagEntries,
		get: <T>(entry: { __T: (any) -> T }) -> T,
	},
}

export type EnvironmentSandboxer = {
	sandbox_environment: (env: any) -> (),
}

export type ClientInstancePool = {
	pop: (className: string, parent: Instance?, expand: boolean?) -> Instance,
}

export type PatchedContext<TObject = any> = {
	--[=[
		## Getter
		The current value (potentially with prior patches applied)

		Starting point: `unsandboxed_object[key]`

		## Setter
		The current key (potentially with prior patches applied)
	]=]
	snapshot: any,
	--[=[
		The starting value without any patches applied. Same as `unsandboxed_object[key]`.
	]=]
	unsandboxed: any,
	--- The base object without any patches applied.
	unsandboxed_object: any,
	sandbox_context: App,
	storage: { [any]: any },
	--- The environment of the sandboxed script.
	environment: { [any]: any },
}

export type GetterPatchRun = (context: PatchedContext, key: any) -> any
export type SetterPatchRun = (context: PatchedContext, key: any, value: any) -> any

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
	id: string?,
	kind: PatchKind,
	types: { string }?,
	keys: { any }?,
	classes: { string }?,
	special_conditions: { PatchCondition }?,
	priority: number?,
	enabled: boolean?,
}

export type PatchGroup = {
	enabled: boolean?,
	id: string,
	patches: { Patch },
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
	run: GetterPatchRun,
}

export type SetterPatchInfo = PatchInfoBase & {
	run: SetterPatchRun,
}

return nil
