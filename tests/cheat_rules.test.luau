local timescale = require("@layer/util/timescale")
local vip = require("@layer/util/vip_cheat_rules")

assert(vip.friend("everyone", false, 10, nil), "everyone should spoof every friendship")
assert(vip.friend("owner", false, 10, 10), "owner should include the game's user creator")
assert(vip.friend("owner", true, 10, nil), "owner should preserve real friends")
assert(not vip.friend("owner", false, 10, nil), "owner should not spoof when no creator user ID is available")
assert(not vip.friend("nobody", true, 10, 10), "nobody should hide real and creator friendships")
assert(vip.friend("default", true, 10, nil), "default should preserve a real friendship")
assert(not vip.friend("default", false, 10, 10), "default should not add the creator")

assert(vip.group_presence("all", false), "all should spoof group membership")
assert(not vip.group_presence("default", false), "default should preserve missing membership")
assert(vip.group_rank("owner", "default", 0) == 255, "owner should spoof rank 255")
assert(vip.group_rank("default", "all", 0) == 1, "spoofed membership should have a positive fallback rank")
assert(vip.group_rank("default", "all", 42) == 42, "real group ranks should survive spoofed presence")
assert(vip.group_rank("default", "default", 0) == 0, "default should preserve a missing rank")

assert(vip.badge("all", false, false), "all should spoof badge ownership")
assert(vip.badge("default", false, true), "default should include pseudo badges")
assert(vip.badge("default", true, false), "default should preserve real badges")
assert(not vip.badge("default", false, false), "default should not invent badge ownership")

assert(timescale.scale_delta_time(0.25, 2) == 0.5, "RunService delta time should be multiplied")
assert(timescale.scale_delta_time(0.25, -2) == -0.5, "negative RunService timescales should be preserved")
assert(timescale.scale_duration(4, 0.5) == 2, "legacy scheduler durations should be multiplied")
assert(timescale.scale_duration(4, -1) == -4, "negative scheduler timescales should be preserved")

print("passed cheat rule cases")
