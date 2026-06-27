-- some new roblox types aren't available via luau-lsp.
-- consider this polyfill! i think

export type ReflectedProperty = {
	Name: string,
	Owner: string,
	Type: ReflectionType,
	Permits: {
		Read: SecurityCapabilities?,
		Write: SecurityCapabilities?,
		ReadParallel: SecurityCapabilities?,
		WriteParallel: SecurityCapabilities?,
	},
	Display: any, -- cba rn because it's not needed for NL lol sorry
	Serialized: boolean,
}

export type ReflectionType = {
	EngineType: string,
	EnumType: string?,
	ScriptType: string?,
	InstanceType: string?,
}

return nil
