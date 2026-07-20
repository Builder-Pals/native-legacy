export type VariableStore = {
	read ["values"]: { [string]: unknown },
    read ["dirty"]: { [SomeDef]: boolean },
}

export type Priviledge = "dev" | "server_admin"

export type Def<T=unknown> = {
	id: string,
	permissions: { Priviledge },
	default: T,
	context: "client" | "server" | "client_and_server"
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

export type SomeDef<T=unknown> = Def | Def<T> | SingletonDef<T> | BooleanDef | FloatDef

return nil