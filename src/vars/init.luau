local types = require("@self/var_types")
local defs = require("@self/native_var_defs")

-- export from types
export type VariableStore = types.VariableStore
export type SomeDef = types.SomeDef
export type Def<T=unknown> = types.Def<T>

-- export from defs
export type VipFriendsOption = defs.VipFriendsOption
export type VipGroupPresenceOption = defs.VipGroupPresenceOption
export type VipGroupRankOptin = defs.VipGroupRankOptin
export type VipUnlockBadgesOption = defs.VipUnlockBadgesOption

return {
	modifier = require("@self/var_modifier"),
	validator = require("@self/var_validator"),

	defs = defs.definitions,
	def_from_key = function(key: string): types.Def?
		return (defs.definitions :: { [string]: types.Def })[key]
	end,
	def_array = defs.definition_array,

	types = types,
}
