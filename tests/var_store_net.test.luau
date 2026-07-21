local var_store_net = require("@layer/systems/deck/vars/var_store_net")
local vars = require("@layer/vars")

local expected_order = {
	"sv_vip_friends",
	"sv_vip_group_presence",
	"sv_vip_group_rank",
	"sv_vip_unlock_badges",
	"sv_timescale_freeze",
	"sv_timescale_run_service",
	"sv_timescale_wait",
}

for index, expected_id in expected_order do
	assert(vars.def_array[index].id == expected_id, `network ID {index} should map to {expected_id}`)
end

local store = vars.modifier.new()
assert(vars.modifier.get_var(store, vars.defs.sv_vip_friends) == "everyone", "friend spoof default should be everyone")
assert(vars.modifier.get_var(store, vars.defs.sv_timescale_freeze) == false, "freeze should default off")
assert(vars.modifier.get_var(store, vars.defs.sv_timescale_wait) == 1, "wait timescale should default to one")

vars.modifier.set_var(store, vars.defs.sv_vip_friends, "nobody")
local outgoing = var_store_net.take_dirty_table(store)
assert(outgoing["1"] == "nobody", "dirty values should use deterministic string network IDs")
assert(next(store.dirty) == nil, "sent values should be marked clean")

var_store_net.unpack_to(store, { ["1"] = "owner", ["6"] = 2 })
assert(vars.modifier.get_var(store, vars.defs.sv_vip_friends) == "owner", "clean payloads should update values")
assert(vars.modifier.get_var(store, vars.defs.sv_timescale_run_service) == 2, "float payloads should update values")
assert(next(store.dirty) == nil, "replicated payloads should not be echoed")

var_store_net.unpack_to(store, { ["2"] = "default" }, true)
assert(store.dirty[vars.defs.sv_vip_group_presence], "authoritative server changes should become dirty")

local valid_min = pcall(var_store_net.unpack_to, store, { ["7"] = -100000 })
local valid_max = pcall(var_store_net.unpack_to, store, { ["7"] = 100000 })
local invalid_low = pcall(var_store_net.unpack_to, store, { ["7"] = -100001 })
local invalid_high = pcall(var_store_net.unpack_to, store, { ["7"] = 100001 })
assert(valid_min and valid_max, "timescale bounds should be accepted")
assert(not invalid_low and not invalid_high, "out-of-range timescales should be rejected")

local invalid_singleton = pcall(var_store_net.unpack_to, store, { ["1"] = "invalid" })
local invalid_net_id = pcall(var_store_net.unpack_to, store, { ["99"] = true })
local invalid_key_type = pcall(var_store_net.unpack_to, store, { [1] = "default" })
assert(not invalid_singleton, "unknown singleton values should be rejected")
assert(not invalid_net_id, "unknown network IDs should be rejected")
assert(not invalid_key_type, "non-string transport keys should be rejected")

local value_before_invalid_payload = vars.modifier.get_var(store, vars.defs.sv_vip_friends)
local invalid_payload = pcall(var_store_net.unpack_to, store, { ["1"] = "nobody", ["7"] = 100001 })
assert(not invalid_payload, "a payload containing an invalid value should be rejected")
assert(
	vars.modifier.get_var(store, vars.defs.sv_vip_friends) == value_before_invalid_payload,
	"invalid payloads should not be partially applied"
)

print("passed variable synchronization cases")
