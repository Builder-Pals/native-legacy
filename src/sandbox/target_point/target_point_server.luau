local network = require("@layer/network")
local Players = game:GetService("Players")

return function()
    local humanoids: { [Player]: Humanoid } = {}

    Players.PlayerAdded:Connect(function(player)
        local function on_character(character)
            local humanoid = character:WaitForChild("Humanoid", 10000)

            if humanoid then
                humanoids[player] = humanoid
            end
        end

        player.CharacterAdded:Connect(on_character)

        if player.Character then
            task.spawn(on_character, player.Character)
        end
    end)

    Players.PlayerRemoving:Connect(function(player)
        humanoids[player] = nil
    end)

    network.remotes.unreliable.server.subscribe({}, network.remotes.ids.unreliable.target_point.update, function(player: Player, target_point: unknown)
        assert(typeof(target_point) == "Vector3")

        if humanoids[player] then
            humanoids[player].TargetPoint = target_point
        end
    end)
end