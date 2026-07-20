local t = require("./var_types")

export type VipFriendsOption = "everyone" | "owner" | "nobody" | "default"
export type VipGroupPresenceOption = "all" | "default"
export type VipGroupRankOptin = "owner" | "default"
export type VipUnlockBadgesOption = "all" | "default"

--[=[
    controls the vip friend spoof
    
    everyone - all users are your friend
    owner - your real friends list, plus the game's owner (if their UserId is available
    nobody - NOBODY is your friend. :(
    default - keep your real friends list
]=]
const sv_vip_friends: t.SingletonDef<VipFriendsOption> = {
	type = "singleton",
	id = "sv_vip_friends",
	permissions = { "dev" },

	default = "everyone",
	options = { "everyone", "owner", "nobody", "default" },
}

--[=[
    controls the vip group presence patch
    
    all - spoofs you as in ALL groups on roblox
    default - return the real group values
]=]
const sv_vip_group_presence: t.SingletonDef<VipGroupPresenceOption> = {
	type = "singleton",
	id = "sv_vip_group_presence",
	permissions = { "dev" },

	default = "all",
	options = { "all", "default" },
}

--[=[
    controls the vip group rank patch
    
    owner - spoofs your rank as 255 (the owner)
    default - spoofs your rank as the real value, or 1 if 'group presence' is faking your presence
]=]
const sv_vip_group_rank: t.SingletonDef<VipGroupRankOptin> = {
	type = "singleton",
	id = "sv_vip_group_rank",
	permissions = { "dev" },

	default = "owner",
	options = { "owner", "default" },
}

--[=[
    controls the vip badge unlock patch
    
    all - ALL roblox badges belong to you
    default - keep your real owned badges, plus pseudo badges earnt through native legacy
]=]
const sv_vip_unlock_badges: t.SingletonDef<VipUnlockBadgesOption> = {
	type = "singleton",
	id = "sv_vip_unlock_badges",
	permissions = { "dev" },

	default = "all",
	options = { "all", "default" },
}

--[=[
    controls the vip badge unlock patch
    
    all - ALL roblox badges belong to you
    default - keep your real owned badges, plus pseudo badges earnt through native legacy
]=]
const sv_timescale_freeze: t.BooleanDef = {
	type = "boolean",
	id = "sv_timescale_freeze",
	permissions = { "dev" },

	default = false,
}

--[=[
    controls the timescale of run service
]=]
const sv_timescale_run_service: t.FloatDef = {
	type = "float",
	id = "sv_timescale_run_service",
	permissions = { "dev" },

	default = 1,
}

--[=[
    controls the timescale of spawn/delay/wait (but not the new task methods, as they don't matter for this project)
]=]
const sv_timescale_wait: t.FloatDef = {
	type = "float",
	id = "sv_timescale_wait",
	permissions = { "dev" },

	default = 1,
}

local definitions = {
	sv_vip_friends = sv_vip_friends,
	sv_vip_group_presence = sv_vip_group_presence,
	sv_vip_group_rank = sv_vip_group_rank,
	sv_vip_unlock_badges = sv_vip_unlock_badges,
	sv_timescale_freeze = sv_timescale_freeze,
	sv_timescale_run_service = sv_timescale_run_service,
	sv_timescale_wait = sv_timescale_wait,
}

local def_array: { t.Def } = {}

for _, def in pairs(definitions :: { [string]: t.Def }) do
    table.insert(def_array, def)
end

return {
	definitions = definitions,
    definition_array = def_array,
}
