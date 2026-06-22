local Players = game:GetService("Players")

local nl_constants = require("@layer/nl_constants")
local Iris = require("../packages/Iris")
local network = require("@layer/network")

local client = network.remotes.reliable.client

local games: { [string]: number } = {
	["Pipe Riding"] = 14475947102,
	["Underwater Obby"] = 14848794565,
	["Airplane Crash to Mystery Island"] = 14961020116,
	["Build your own Noob Trap"] = 14687697121,
	["Heli-Wars"] = 14535192873,
	["Base Wars"] = 13159150083,
	["WARZONE"] = 14687770741,
	["Virtual Paintball"] = 13232401212,
	["Sandbox"] = 13224001965
}

return function()
	local gui = Instance.new("ScreenGui")
	gui.Name = "NL Console"
	gui:AddTag(nl_constants.RELOAD_PROTECTION)
	gui.ResetOnSpawn = false
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")

	Iris.Init(gui, nil, false)

	local function request(id: number)
		print(`requesting {id}}`)
		workspace:AddTag("place_hopping")
		client.send(network.remotes.ids.reliable.console.load_place,id)
	end

	Iris:Connect(function()
		Iris.Window { "native legacy management" }
            Iris.Text { "place loader" }
			Iris.CollapsingHeader({"Load from ID"})
				local inputText = Iris.InputNum({ "ID" })
				if Iris.Button { "Load" }.clicked() then
					request(inputText.state.number.value)
				end
			Iris.End()
			for game_name, id in games do
				if Iris.Button { game_name }.clicked() then
					request(id)
				end
			end
		Iris.End()
	end)
end
