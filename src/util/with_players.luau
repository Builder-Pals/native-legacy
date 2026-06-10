local Players = game:GetService("Players")

return function(callback: (Player) -> ())
    for _, player in Players:GetPlayers() do
        callback(player)
    end

    Players.PlayerAdded:Connect(callback)
end