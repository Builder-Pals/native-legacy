local Players = game:GetService("Players")

local nl_constants = require("@layer/nl_constants")
local Iris = require("../packages/Iris")
local network = require("@layer/network")

local client = network.remotes.reliable.client

return function()
	local gui = Instance.new("ScreenGui")
	gui.Name = "NL Console"
	gui:AddTag(nl_constants.RELOAD_PROTECTION)
	gui.ResetOnSpawn = false
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")

	Iris.Init(gui, nil, false)

	Iris:Connect(function()
		Iris.Window { "native legacy management" }
            Iris.Text { "place loader" }
            local inputText = Iris.InputNum({ "ID" })
            if Iris.Button { "Load" }.clicked() then
                print(`loading {inputText.state.number.value}`)
				client.send(network.remotes.ids.reliable.console.load_place, inputText.state.number.value)
            end
		Iris.End()
	end)
end
