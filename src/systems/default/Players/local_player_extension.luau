local RunService = game:GetService("RunService")
local app = require("@layer/app")
local sandbox = require("@layer/sandbox")
local patching = sandbox.patching

--[[
    A lot of old HopperBin scripts seem to access the LocalPlayer inside of server scripts.
    I haven't looked into why this worked too much, but presumably its an artifact of
    'play solo' behaviour - if there was only one player to worry about, LocalPlayer
    may have always been set for convenience.
--]]
app.add_patch(
	"local_player_extension",
	patching.getter_patch {
		classes = { "Players" },
		keys = { "LocalPlayer", "localPlayer" },
		run = function(ctx)
            local source = patching.utils.get_source_script()
            
            if not source then
                warn(`[{script.Name}] no source found`)
                return ctx.unsandboxed
            end

            local hopperBin = source:FindFirstAncestorWhichIsA("HopperBin")
            local player = hopperBin and hopperBin:FindFirstAncestorWhichIsA("Player")

            if player then
                return player
            end

            return ctx.unsandboxed
		end,
	},
    RunService:IsServer()
)


return nil