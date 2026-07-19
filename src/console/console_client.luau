local Players = game:GetService("Players")
local TextChatService = game:GetService("TextChatService")

local nl_tags = require("@layer/nl_tags")
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
	["Disaster Hotel"] = 13155062219,
	--["WARZONE"] = 14687770741,
	["Virtual Paintball"] = 13232401212,
	["Sandbox"] = 13224001965,
	--["Hotline Roblox"] = 13448653318
	["Orbital Warfare"] = 13293927722
}

local function make_command()
	local command = Instance.new("TextChatCommand")
	command.Name = "NLPanel"
	command.PrimaryAlias = "/nl"
	command.SecondaryAlias = "/nativelegacy"
	command.Parent = TextChatService:WaitForChild("TextChatCommands")

	return command
end

local function apply_theme()
	local light_theme = Iris.TemplateConfig.colorLight
	assert(light_theme, "light theme is missing")
	Iris.UpdateGlobalConfig(light_theme :: any)
end

return function()
	apply_theme()
	local command = make_command()

	local gui = Instance.new("ScreenGui")
	gui.Name = "NL Console"
	gui:AddTag(nl_tags.RELOAD_PROTECTION)
	gui.ResetOnSpawn = false
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")

	Iris.Init(gui, nil, false)

	local function request(id: string | number)
		print(`requesting to play id={id}`)
		workspace:AddTag("place_hopping")
		client.send(network.remotes.ids.reliable.console.load_place, tostring(id))
	end

	local is_open = Iris.State(true)
	local position = Iris.State(Vector2.new(16, 350))
	local size = Iris.State(Vector2.new(300, 400))

	const window_types = {
		manager = 1,
		notice = 2
	}

	local current_window = window_types.manager

	local remove_close_notice
	remove_close_notice = is_open:onChange(function()
		current_window = window_types.notice
		assert(remove_close_notice)
		remove_close_notice()
		is_open:set(true)
	end)

	local windows = {
		[window_types.manager] = function()
			Iris.Window({ "native legacy management" }, { isOpened = is_open, position = position, size = size })
				Iris.Text { "place loader" }
				Iris.CollapsingHeader({"Load from Marketplace"})
					local input_1 = Iris.InputNum({ "ID" })
					if Iris.Button { "Load" }.clicked() then
						request(input_1.state.number.value)
					end
				Iris.End()
				Iris.CollapsingHeader({"Load Uncopylocked Place"})
					Iris.TextWrapped { "[HIGHLY EXPERIMENTAL] Native Legacy will do its best to load this game within the compatibility layer. It may take a while to load. This feature does not support games uploaded after 2017." }
					local input_2 = Iris.InputText({ "ID" })
					if Iris.Button { "Load" }.clicked() then
						request(input_2.state.text.value)
					end
				Iris.End()
				Iris.Separator()
				for game_name, id in games do
					if Iris.Button { game_name }.clicked() then
						request(id)
					end
				end
			Iris.End()
		end,

		[window_types.notice] = function()
			local window_size = Iris.State(Vector2.new(300, 200))

			Iris.Window({ "notice" }, { isOpened = is_open, position = position, size = window_size })
				Iris.Text { "type /nl into chat to summon\nthis window whenever. have fun!" }
				if Iris.Button { "OK" }.clicked() then
					is_open:set(false)
				end
			Iris.End()
		end
	}

	Iris:Connect(function()
		windows[current_window]()
	end)

	command.Triggered:Connect(function()
		print("ok")
		current_window = window_types.manager
		is_open:set(not is_open:get())
	end)
end
