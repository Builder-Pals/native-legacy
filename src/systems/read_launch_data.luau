local app = require("@layer/app")
local game_request_handler = require("../console/game_request_handler")
local Composite = require("@layer/util/Composite")

local launch_taken = false

local function read_arg(x: string): string?
    if x:lower():sub(1, 5) == "play_" then
        return x:sub(6)
    end

    if x:lower():sub(1, 4) == "nla_" then
        return x:sub(5)
    end

    return nil
end

app.add_system("read_launch_data", function()
    Composite.common.player_added:connect(function(player: Player)
        if launch_taken then
            return nil
        end
        
        local join_data = player:GetJoinData()

        if join_data.LaunchData == nil then
            return nil
        end

        local fingerprint = `uid={player.UserId} name={player.Name} launch_data="{join_data.LaunchData}"`
        local target = read_arg(join_data.LaunchData)

        if not target then
            warn(`[join-data] invalid or unknown launch data {fingerprint}`)
            return nil
        end

        print(`[join-data] player requested to load game {target} launch data {fingerprint}`)
        
        local message = Instance.new("Message")
        message.Parent = player
        message.Text = "handling your request..."

        local ok, result = pcall(game_request_handler.handle_async, target)

        if not ok then
            warn(`[join-data] failed to load game {target}: {result}\n{debug.traceback()}`)
        else
            print(`[join-data] successfully loaded game {target}`)
        end

        message:Destroy()

        return nil
    end)
end, app.run_flags.SERVER)

return nil