local Players = game:GetService("Players")

type Maid = () -> ()

return function(callback: (Player) -> Maid?)
	local maids: { [Player]: Maid } = {}

	Players.PlayerAdded:Connect(function(player)
		maids[player] = callback(player)
	end)

	Players.PlayerRemoving:Connect(function(player)
		if maids[player] then
			maids[player]()
		end
	end)

	for _, player in Players:GetPlayers() do
		maids[player] = callback(player)
	end
end
