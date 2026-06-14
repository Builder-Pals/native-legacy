local network = require("@layer/network")
local Players = game:GetService("Players")

local LOCAL_PLAYER = Players.LocalPlayer

return function()
    assert(LOCAL_PLAYER)

    local function on_character_added(character: Model)
        local humanoid = character:WaitForChild("Humanoid", 10000)

        if humanoid and humanoid:IsA("Humanoid") then
            humanoid:GetPropertyChangedSignal("TargetPoint"):Connect(function()
                network.remotes.unreliable.client.send(network.remotes.ids.unreliable.target_point.update, humanoid.TargetPoint)
            end)
        end
    end

    LOCAL_PLAYER.CharacterAdded:Connect(on_character_added)

    if LOCAL_PLAYER.Character then
        on_character_added(LOCAL_PLAYER.Character)
    end
end