local app = require("@layer/app")
local pseudo_badge_service = require("@layer/badges/pseudo_badge_service")
local sandbox = require("@layer/sandbox")
local vars = require("@layer/vars")
local vip_cheat_rules = require("@layer/util/vip_cheat_rules")

local patching = sandbox.patching

local function creator_user_id(): number?
	if workspace:GetAttribute("CreatorType") ~= Enum.CreatorType.User.Name then
		return nil
	end

	local creator_id = workspace:GetAttribute("CreatorId")
	return if typeof(creator_id) == "number" then creator_id else nil
end

app.add_patch(
	"vip_friend_spoof",
	patching.getter_patch {
		classes = { "Player" },
		keys = { "IsFriendsWith", "isFriendsWith", "IsBestFriendsWith", "isBestFriendsWith" },
		run = function(context, _key)
			local original = context.snapshot
			return function(self, target_user_id: number)
				-- Preserve validation, errors, and any simulated API delay.
				local real_result = original(self, target_user_id)
				local option = vars.modifier.get_var(context.sandbox_context.vars, vars.defs.sv_vip_friends)

				return vip_cheat_rules.friend(option, real_result, target_user_id, creator_user_id())
			end
		end,
	}
)

app.add_patch(
	"vip_group_presence_spoof",
	patching.getter_patch {
		classes = { "Player" },
		keys = { "IsInGroup", "isInGroup" },
		run = function(context, _key)
			local original = context.snapshot
			return function(self, group_id: number)
				local real_result = original(self, group_id)
				local option = vars.modifier.get_var(context.sandbox_context.vars, vars.defs.sv_vip_group_presence)

				return vip_cheat_rules.group_presence(option, real_result)
			end
		end,
	}
)

app.add_patch(
	"vip_group_rank_spoof",
	patching.getter_patch {
		classes = { "Player" },
		keys = { "GetRankInGroup", "getRankInGroup" },
		run = function(context, _key)
			local original = context.snapshot
			return function(self, group_id: number)
				local real_rank = original(self, group_id)
				local variable_store = context.sandbox_context.vars
				local option = vars.modifier.get_var(variable_store, vars.defs.sv_vip_group_rank)
				local presence_option = vars.modifier.get_var(variable_store, vars.defs.sv_vip_group_presence)

				return vip_cheat_rules.group_rank(option, presence_option, real_rank)
			end
		end,
	}
)

app.add_patch(
	"vip_badge_spoof",
	patching.getter_patch {
		classes = { "BadgeService" },
		keys = { "UserHasBadge", "userHasBadge", "UserHasBadgeAsync", "userHasBadgeAsync" },
		run = function(context, _key)
			local original = context.snapshot
			return function(self, user_id: number, badge_id: number)
				local real_result = original(self, user_id, badge_id)
				local option = vars.modifier.get_var(context.sandbox_context.vars, vars.defs.sv_vip_unlock_badges)

				return vip_cheat_rules.badge(
					option,
					real_result,
					pseudo_badge_service.has_pseudo_badge(user_id, badge_id)
				)
			end
		end,
	}
)

return nil
