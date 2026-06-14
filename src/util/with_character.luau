return function(player: Player, callback: (Model) -> ())
    player.CharacterAdded:Connect(callback)

    if player.Character then
        task.spawn(callback, player.Character)
    end
end