local BadgeService = game:GetService("BadgeService")
local StarterGui = game:GetService("StarterGui")
local app = require("@layer/app")
local sandbox = require("@layer/sandbox")
local network = require("../../../network")
local pseudo_badge_service = require("../../../badges/pseudo_badge_service")
local sandboxer = sandbox.sandboxer
local patching = sandbox.patching

app.add_patch(
	"pseudo_badge_spoof",
	patching.getter_patch {
		classes = { "BadgeService" },
		keys = { "AwardBadge", "awardBadge" },
		run = function(context, key)
			return function(self, ...)
				assert(sandboxer.unsandbox(self) == BadgeService, `Expected ':' not '.' calling member function {key}`)
                pseudo_badge_service.award_badge_async(...)
			end
		end,
	}
)

app.add_system("pseudo_badge_client_display", function()
    network.remotes.reliable.client.subscribe({}, network.remotes.ids.reliable.badges.notify, function(notification_info)
        local bind = Instance.new("BindableFunction")

        bind.OnInvoke = function()
            pseudo_badge_service.client_share_award_notification(notification_info.BadgeId)
        end

        notification_info.Callback = bind
        notification_info.Button1 = "Tell Everyone"
        StarterGui:SetCore("SendNotification", notification_info)
    end)

    network.remotes.reliable.client.subscribe({}, network.remotes.ids.reliable.badges.share, function(notification_info)
        print("received share", notification_info)
        StarterGui:SetCore("SendNotification", notification_info)
    end)
end, app.run_flags.CLIENT)

app.add_system("pseudo_badge_server_display", function()
    pseudo_badge_service.get_bindable_function().OnServerInvoke = function(player, share_type, ...)
        pseudo_badge_service.award_badge_async(...)
    end

    network.remotes.reliable.server.subscribe({}, network.remotes.ids.reliable.badges.share, function(player, badge_id)
        assert(typeof(badge_id) == "number", "Expected number")
        print(`badge is {badge_id}`)
        pseudo_badge_service.server_share_award_notification(player, badge_id)
    end)
end, app.run_flags.SERVER)

return nil
