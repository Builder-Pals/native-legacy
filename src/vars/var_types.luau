export type VariableStore = {
	read ["values"]: { [string]: unknown },
    read ["dirty"]: { [Def]: boolean },
}

export type Priviledge = "dev" | "server_admin"

export type Def<T=unknown> = {
	id: string,
	permissions: { Priviledge },
	default: T,
}

export type SingletonDef<T> = Def<T> & {
	type: "singleton",
	options: { T },
}

export type BooleanDef = Def<boolean> & {
	type: "boolean",
}

export type FloatDef = Def<number> & {
	type: "float",
    clamp: { min: number, max: number }?
}

export type SomeDef = SingletonDef<unknown> | BooleanDef | FloatDef

return nil