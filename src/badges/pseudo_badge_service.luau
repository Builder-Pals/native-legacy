local BadgeService = game:GetService("BadgeService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")
local network = require("../network")
local award_logs: { [string]: number } = {}

const SHARED = 2
const UNSHARED = 1

local function get_remote(): RemoteFunction
	if RunService:IsClient() then
		return script:WaitForChild("RemoteFunction") :: RemoteFunction
	else
		local bind = Instance.new("RemoteFunction")
		bind.Archivable = false
		bind.Parent = script
		return bind
	end
end

local remote: RemoteFunction

-- https://create.roblox.com/docs/reference/engine/classes/BadgeService#GetBadgeInfoAsync
type BadgeInfo = {
	Name: string,
	Description: string,
	IconImageId: number,
	IsEnabled: boolean,
}

local function make_notification(player: Player, badge_info: BadgeInfo, badge_id: number?)
	return {
		Title = "Badge Awarded",
		Text = `{player.Name} won "{badge_info.Name}"!`,
		Icon = `rbxassetid://{badge_info.IconImageId}`,
		Duration = 5,

		BadgeId = badge_id,
		UserId = player.UserId,
	}
end

local pseudo_badge_service = {}
pseudo_badge_service.get_bindable_function = get_remote

function pseudo_badge_service.client_share_award_notification(badge_id: number)
	network.remotes.reliable.client.send(network.remotes.ids.reliable.badges.share, badge_id)
end

function pseudo_badge_service.server_share_award_notification(player: Player, badge_id: number)
	local hash = `{player.UserId}|{badge_id}`

	if award_logs[hash] ~= UNSHARED then
		print(`ignoring share request - badge isn't marked as unshared`)
		return
	end

	local badge_info = BadgeService:GetBadgeInfoAsync(badge_id)

	award_logs[hash] = SHARED
	network.remotes.reliable.server.send_all(
		network.remotes.ids.reliable.badges.share,
		make_notification(player, badge_info)
	)
end

function pseudo_badge_service.award_badge_async(user_id: number, badge_id: number)
	if RunService:IsClient() then
		remote = remote or get_remote()
		return remote:InvokeServer(user_id, badge_id)
	end

	local hash = `{user_id}|{badge_id}`

	if award_logs[hash] ~= nil then
		return
	end

	award_logs[hash] = UNSHARED

	-- run the actual call just to validate the badge and simulate API call delay.
	BadgeService:UserHasBadgeAsync(user_id, badge_id)

	local player = Players:GetPlayerByUserId(user_id)

	if player then
		local badge_info: BadgeInfo = BadgeService:GetBadgeInfoAsync(badge_id)
		network.remotes.reliable.server.send(
			network.remotes.ids.reliable.badges.notify,
			player,
			make_notification(player, badge_info, badge_id)
		)
	end
end

return pseudo_badge_service
