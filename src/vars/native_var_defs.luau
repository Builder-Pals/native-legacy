local t = require("./var_types")

export type VipFriendsOption = "everyone" | "owner" | "nobody" | "default"
export type VipGroupPresenceOption = "all" | "default"
export type VipGroupRankOption = "owner" | "default"
export type VipUnlockBadgesOption = "all" | "default"

--[=[
    controls the vip friend spoof
    
    everyone - all users are your friend
    owner - your real friends list, plus the game's owner (if their UserId is available
    nobody - NOBODY is your friend. :(
    default - keep your real friends list
]=]
local sv_vip_friends: t.SingletonDef<VipFriendsOption> = {
	type = "singleton",
	id = "sv_vip_friends",
	permissions = { "dev" },

	default = "everyone",
	options = { "everyone", "owner", "nobody", "default" },
	context = "server",
}

--[=[
    controls the vip group presence patch
    
    all - spoofs you as in ALL groups on roblox
    default - return the real group values
]=]
local sv_vip_group_presence: t.SingletonDef<VipGroupPresenceOption> = {
	type = "singleton",
	id = "sv_vip_group_presence",
	permissions = { "dev" },

	default = "all",
	options = { "all", "default" },
	context = "server",
}

--[=[
    controls the vip group rank patch
    
    owner - spoofs your rank as 255 (the owner)
    default - spoofs your rank as the real value, or 1 if 'group presence' is faking your presence
]=]
local sv_vip_group_rank: t.SingletonDef<VipGroupRankOption> = {
	type = "singleton",
	id = "sv_vip_group_rank",
	permissions = { "dev" },

	default = "owner",
	options = { "owner", "default" },
	context = "server",
}

--[=[
    controls the vip badge unlock patch
    
    all - ALL roblox badges belong to you
    default - keep your real owned badges, plus pseudo badges earnt through native legacy
]=]
local sv_vip_unlock_badges: t.SingletonDef<VipUnlockBadgesOption> = {
	type = "singleton",
	id = "sv_vip_unlock_badges",
	permissions = { "dev" },

	default = "all",
	options = { "all", "default" },
	context = "server",
}

--[=[
    controls the vip badge unlock patch
    
    all - ALL roblox badges belong to you
    default - keep your real owned badges, plus pseudo badges earnt through native legacy
]=]
local sv_timescale_freeze: t.BooleanDef = {
	type = "boolean",
	id = "sv_timescale_freeze",
	permissions = { "dev" },

	default = false,
	context = "server",
}

--[=[
    controls the timescale of run service
]=]
local sv_timescale_run_service: t.FloatDef = {
	type = "float",
	id = "sv_timescale_run_service",
	permissions = { "dev" },

	default = 1,
	clamp = { min = -100000, max = 100000 },
	context = "server",
}

--[=[
    controls the timescale of spawn/delay/wait (but not the new task methods, as they don't matter for this project)
]=]
local sv_timescale_wait: t.FloatDef = {
	type = "float",
	id = "sv_timescale_wait",
	permissions = { "dev" },

	default = 1,
	clamp = { min = -100000, max = 100000 },
	context = "server",
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

-- Network IDs are derived from this array, so its order must be identical in
-- every VM. Iterating `definitions` with `pairs` does not guarantee that.
local def_array: { t.SomeDef } = {
	sv_vip_friends,
	sv_vip_group_presence,
	sv_vip_group_rank,
	sv_vip_unlock_badges,
	sv_timescale_freeze,
	sv_timescale_run_service,
	sv_timescale_wait,
}

return {
	definitions = definitions,
	definition_array = def_array,
}
