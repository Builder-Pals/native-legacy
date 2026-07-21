local vip_cheat_rules = {}

function vip_cheat_rules.friend(
	option: "everyone" | "owner" | "nobody" | "default",
	real_result: boolean,
	target_user_id: number,
	creator_user_id: number?
): boolean
	if option == "everyone" then
		return true
	elseif option == "owner" then
		return real_result or (creator_user_id ~= nil and target_user_id == creator_user_id)
	elseif option == "nobody" then
		return false
	else
		return real_result
	end
end

function vip_cheat_rules.group_presence(option: "all" | "default", real_result: boolean): boolean
	return if option == "all" then true else real_result
end

function vip_cheat_rules.group_rank(
	option: "owner" | "default",
	group_presence_option: "all" | "default",
	real_rank: number
): number
	if option == "owner" then
		return 255
	elseif group_presence_option == "all" and real_rank == 0 then
		-- A positive rank keeps IsInGroup and GetRankInGroup consistent.
		return 1
	else
		return real_rank
	end
end

function vip_cheat_rules.badge(option: "all" | "default", real_result: boolean, has_pseudo_badge: boolean): boolean
	return if option == "all" then true else real_result or has_pseudo_badge
end

return vip_cheat_rules
