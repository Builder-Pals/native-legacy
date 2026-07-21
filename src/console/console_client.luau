local Players = game:GetService("Players")
local TextChatService = game:GetService("TextChatService")

local nl_tags = require("@layer/nl_tags")
local Iris = require("../packages/Iris")
local network = require("@layer/network")
local app = require("@layer/app")
local vars = require("@layer/vars")
local native_var_docs = require("../vars/native_var_docs")

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

local function set_from_widget<T>(def: vars.Def<T>, value: T)
	vars.validator.assert_valid(def, value)
	vars.modifier.set_var(app.context.vars, def, value)
	print(`set {def.id} to {value}`)
end

local function try_document(def: vars.Def, current_value: unknown)
	local docs = native_var_docs[def.id]

	if docs then
		Iris.PushConfig({ RichText = true })
		local tip_builder = { docs.tooltip }

		if next(docs.values) then
			table.insert(tip_builder, "----------")
		end

		for key, value in docs.values do
			if current_value == key then
				table.insert(tip_builder, `<b>{key}</b> - {value}`)
			else
				table.insert(tip_builder, `{key}: {value}`)
			end
		end

		Iris.Tooltip({ table.concat(tip_builder, "\n") })
		Iris.PopConfig()
	end
end

local function singleton_cheat(label: string, def: vars.SingletonDef)
	local current_value = app.context.vars.values[def.id]
	local state = Iris.State(current_value)
	local combo = Iris.ComboArray({ label }, { index = state }, def.options)
	local changed = combo.changed()

	if changed and state:get() ~= current_value then
		set_from_widget(def, state:get())
	elseif not changed and state:get() ~= current_value then
		state:set(current_value)
	end
	
	if combo.hovered() then
		try_document(def :: vars.Def, current_value)
	end
end

local function boolean_cheat(label: string, def: vars.BooleanDef)
	local current_value = app.context.vars.values[def.id]
	local state = Iris.State(current_value)
	local checkbox = Iris.Checkbox({ label }, { isChecked = state })
	local changed = checkbox.checked() or checkbox.unchecked()

	if changed and state:get() ~= current_value then
		set_from_widget(def, state:get())
	elseif not changed and state:get() ~= current_value then
		state:set(current_value)
	end

	if checkbox.hovered() then
		try_document(def :: vars.Def, current_value)
	end
end

local function float_cheat(label: string, def: vars.FloatDef)
	local current_value = app.context.vars.values[def.id]
	local state = Iris.State(current_value)
	
	local input

	if def.clamp then
		input = Iris.InputNum(
			{ label, 0.05, def.clamp.min, def.clamp.max, "%.3f", true },
			{ number = state }
		)
	else
		input = Iris.InputNum(
			{ label, 0.05, 0, 0, "%.3f", true },
			{ number = state }
		)
	end

	local changed = input.numberChanged()

	if changed and state:get() ~= current_value then
		set_from_widget(def, state:get())
	elseif not changed and state:get() ~= current_value then
		state:set(current_value)
	end

	if input.hovered() then
		try_document(def :: vars.Def, current_value)
	end
end

local function request_game(id: string | number)
	print(`requesting to play id={id}`)
	workspace:AddTag("place_hopping")
	client.send(network.remotes.ids.reliable.console.load_place, tostring(id))
end

local function render_place_loader()
	Iris.Text { "place loader" }
	Iris.CollapsingHeader({"Load from Marketplace"})
		local input_1 = Iris.InputNum({ "ID" })
		if Iris.Button { "Load" }.clicked() then
			request_game(input_1.state.number.value)
		end
	Iris.End()
	Iris.CollapsingHeader({"Load Uncopylocked Place"})
		Iris.TextWrapped { "[HIGHLY EXPERIMENTAL] Native Legacy will do its best to load this game within the compatibility layer. It may take a while to load. This feature does not support games uploaded after 2017." }
		local input_2 = Iris.InputText({ "ID" })
		if Iris.Button { "Load" }.clicked() then
			request_game(input_2.state.text.value)
		end
	Iris.End()
end

local function render_cheats_menu()
	Iris.Text { "fun" }
	Iris.CollapsingHeader { "Free VIP" }
		Iris.TextWrapped { "Spoof common friend, group, and badge checks used by classic VIP doors." }
		singleton_cheat("Friends", vars.defs.sv_vip_friends)
		singleton_cheat("Group presence", vars.defs.sv_vip_group_presence)
		singleton_cheat("Group rank", vars.defs.sv_vip_group_rank)
		singleton_cheat("Unlock badges", vars.defs.sv_vip_unlock_badges)
	Iris.End()
	Iris.CollapsingHeader { "Timescale" }
		Iris.TextWrapped { "Scale legacy scheduler waits and RunService delta time for sandboxed scripts." }
		boolean_cheat("Freeze", vars.defs.sv_timescale_freeze)
		float_cheat("RunService", vars.defs.sv_timescale_run_service)
		float_cheat("wait / spawn / delay", vars.defs.sv_timescale_wait)
	Iris.End()
end

local function render_featured_games()
	Iris.Text { "featured games" }
	for game_name, id in games do
		if Iris.Button { game_name }.clicked() then
			request_game(id)
		end
	end
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
			Iris.Window({ "native legacy demo" }, { isOpened = is_open, position = position, size = size })
				render_place_loader()
				Iris.Separator()
				render_cheats_menu()
				Iris.Separator()
				render_featured_games()
			Iris.End()
		end,

		[window_types.notice] = function()
			local window_size = Iris.State(Vector2.new(300, 200))

			Iris.Window({ "notice" }, { isOpened = is_open, position = position, size = window_size })
				Iris.Text { "type /nl into chat to summon\nthis window whenever. have fun!" }
				if Iris.Button { "cool, i read that" }.clicked() then
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
