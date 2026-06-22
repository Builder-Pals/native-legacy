local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local app = require("@layer/app")
local sandbox = require("@layer/sandbox")
local with_players = require("@layer/util/with_players")
local string_util = require("../../../util/string_util")
local FakeSignal = require("@layer/util/FakeSignal")
local network = require("@layer/network")

local patching = sandbox.patching

local SPECIAL_KEYS = {
	MB1_DOWN = string.char(1),
	MB1_UP = string.char(2),
	MB2_DOWN = string.char(3),
	MB2_UP = string.char(4),
}

local SPECIAL_KEY_REVERSER: { [string]: string } = {}

for key, value in SPECIAL_KEYS :: { [string]: string } do
	SPECIAL_KEY_REVERSER[value] = key
end

local function get_special_key_priority(key: string)
	return string.byte(key)
end

local function sort_special_keys(a, b)
	return get_special_key_priority(a) < get_special_key_priority(b)
end

local KEY_REMAPPING = {
	[Enum.KeyCode.One] = "1",
	[Enum.KeyCode.Two] = "2",
	[Enum.KeyCode.Three] = "3",
	[Enum.KeyCode.Four] = "4",
	[Enum.KeyCode.Five] = "5",
	[Enum.KeyCode.Six] = "6",
	[Enum.KeyCode.Seven] = "7",
	[Enum.KeyCode.Eight] = "8",
	[Enum.KeyCode.Nine] = "9",
	[Enum.KeyCode.Zero] = "0",
}

export type FakeMouse = {
	player: Player,
	real_mouse: Mouse,
	object: any,
	location: Vector2,
	hit: CFrame,
	target: Instance?,

	key_down: FakeSignal.SignalContext,
	key_up: FakeSignal.SignalContext,

	button_1_down: FakeSignal.SignalContext,
	button_1_up: FakeSignal.SignalContext,
	button_2_down: FakeSignal.SignalContext,
	button_2_up: FakeSignal.SignalContext,
}

-- client
-- sends mouse data to the server.
app.add_system("hopperbin_send_input", function(_app)
	local bin_selected = false
	local input_pool = {}
	local player = Players.LocalPlayer
	local mouse = player:GetMouse()

	do
		local function with_backpack(backpack: Backpack)
			local function with_hopperbin(bin: HopperBin)
				local select_connection = bin.Selected:Connect(function()
					bin_selected = true
					network.remotes.reliable.client.send(network.remotes.ids.reliable.hopperbin.select, bin)
				end)

				local deselect_connection = bin.Deselected:Connect(function()
					bin_selected = false
					network.remotes.reliable.client.send(network.remotes.ids.reliable.hopperbin.deselect, bin)
				end)

				bin:GetPropertyChangedSignal("Parent"):Once(function()
					select_connection:Disconnect()
					deselect_connection:Disconnect()
				end)
			end

			local function with_child(child: Instance)
				if child:IsA("HopperBin") then
					with_hopperbin(child)
				end
			end

			backpack.ChildAdded:Connect(with_child)

			for _, child in backpack:GetChildren() do
				with_child(child)
			end
		end

		local function with_child(child: Instance)
			if child:IsA("Backpack") then
				with_backpack(child)
			end
		end

		player.ChildAdded:Connect(with_child)

		for _, child in player:GetChildren() do
			with_child(child)
		end
	end

	UserInputService.InputBegan:Connect(function(input, processed)
		if processed then
			return
		end

		if input.UserInputType == Enum.UserInputType.Keyboard and bin_selected then
			local key_as_string = KEY_REMAPPING[input.KeyCode] or input.KeyCode.Name:lower()
			input_pool[key_as_string] = true
		elseif input.UserInputType == Enum.UserInputType.MouseButton1 then
			input_pool[SPECIAL_KEYS.MB1_DOWN] = true
		elseif input.UserInputType == Enum.UserInputType.MouseButton2 then
			input_pool[SPECIAL_KEYS.MB2_DOWN] = true
		end
	end)

	UserInputService.InputEnded:Connect(function(input, processed)
		if processed then
			return
		end

		if input.UserInputType == Enum.UserInputType.Keyboard and bin_selected then
			local key_as_string = KEY_REMAPPING[input.KeyCode] or input.KeyCode.Name:lower()
			input_pool[key_as_string] = false
		elseif input.UserInputType == Enum.UserInputType.MouseButton1 then
			input_pool[SPECIAL_KEYS.MB1_DOWN] = false
		elseif input.UserInputType == Enum.UserInputType.MouseButton2 then
			input_pool[SPECIAL_KEYS.MB2_DOWN] = false
		end
	end)

	task.spawn(function()
		while true do
			task.wait(1 / 16)

			if not bin_selected then
				continue
			end

			local data = {
				UserInputService:GetMouseLocation(),
				mouse.Target,
				input_pool,
				mouse.Hit.Position,
			}

			network.remotes.unreliable.client.send(network.remotes.ids.unreliable.mouse.update, data)
			table.clear(input_pool)
		end
	end)
end, RunService:IsClient())

-- note: HopperBin.Selected/HopperBin.Deselected are not reliable with
-- filtering enabled.
local function get_server_select_signal(bin: HopperBin)
	return bin:GetAttributeChangedSignal("select")
end

local function get_server_deselect_signal(bin: HopperBin)
	return bin:GetAttributeChangedSignal("deselect")
end

local mice_data: { [Player]: { location: Vector2, target: Instance? } } = {}
local fake_mice: { [Player]: FakeMouse } = {}

local function mouse_index(self, key: string): any
	local data = rawget(self, "data") :: FakeMouse
	local camel_key = string_util.to_camel(key)

	if camel_key == "x" then
		return data.location.X
	end

	if camel_key == "y" then
		return data.location.Y
	end

	if camel_key == "target" then
		return data.target
	end

	if camel_key == "keyDown" then
		return data.key_down.signal
	end

	if camel_key == "keyUp" then
		return data.key_up.signal
	end

	if camel_key == "hit" then
		return data.hit
	end

	if camel_key == "button1Down" then
		return data.button_1_down.signal
	end

	if camel_key == "button1Up" then
		return data.button_1_up.signal
	end

	if camel_key == "button2Down" then
		return data.button_2_down.signal
	end

	if camel_key == "button2Up" then
		return data.button_2_up.signal
	end

	print("fallback", key)
	return (data.real_mouse :: any)[key]
end

local function refresh_fake_mouse(player: Player)
	local existing = fake_mice[player]

	if existing then
		-- prevent existing mouse from receiving any more events
		FakeSignal.destroy_wire(existing.key_down.signal)
		FakeSignal.destroy_wire(existing.key_up.signal)
	end

	-- don't create new mice for disconnected players.
	if not player:IsDescendantOf(game) then
		return
	end

	local fake_mouse_data: FakeMouse = {
		player = player,
		real_mouse = player:GetMouse(),

		key_down = FakeSignal.new(),
		key_up = FakeSignal.new(),

		button_1_down = FakeSignal.new(),
		button_1_up = FakeSignal.new(),
		button_2_down = FakeSignal.new(),
		button_2_up = FakeSignal.new(),

		location = Vector2.zero,
		target = nil,

		hit = CFrame.identity,

		[patching.symbols.FAKE_TYPE] = "userdata",
		[patching.symbols.FAKE_TYPEOF] = "Instance",
	}

	fake_mouse_data.object = setmetatable({ data = fake_mouse_data }, { __index = mouse_index })
	fake_mice[player] = fake_mouse_data
end

-- Server
-- Throws away mice when appropriate to ensure (per player) only one Hopperbin has
-- an active mouse at a time.
app.add_system("hopperbin_mouse_refresher", function(_app)
	with_players(function(player)
		local function with_backpack(backpack: Backpack)
			refresh_fake_mouse(player)

			local function with_hopperbin(bin: HopperBin)
				local deselect_connection = get_server_deselect_signal(bin):Connect(function()
					refresh_fake_mouse(player)
				end)

				bin:GetPropertyChangedSignal("Parent"):Once(function()
					deselect_connection:Disconnect()
				end)
			end

			local function with_child(child: Instance)
				if child:IsA("HopperBin") then
					with_hopperbin(child)
				end
			end

			backpack.ChildAdded:Connect(with_child)

			for _, child in backpack:GetChildren() do
				with_child(child)
			end
		end

		local function with_child(child: Instance)
			if child:IsA("Backpack") then
				with_backpack(child)
			end
		end

		player.ChildAdded:Connect(with_child)

		for _, child in player:GetChildren() do
			with_child(child)
		end

		return nil
	end)
end, RunService:IsServer())

-- Server
-- Receive mouse input from the client.
app.add_system("hopperbin_net_receiver", function(_app)
	local function increment_attribute(instance: Instance, attribute: string)
		local current = instance:GetAttribute(attribute) or 0
		assert(typeof(current) == "number")
		instance:SetAttribute(attribute, current + 1)
	end

	local function validate_bin_ownership(player: Player, bin: HopperBin)
		return bin.Parent and bin.Parent:IsA("Backpack") and bin.Parent.Parent == player
	end

	with_players(function(player)
		refresh_fake_mouse(player)

		return function()
			mice_data[player] = nil
			fake_mice[player] = nil
		end
	end)

	network.remotes.reliable.server.subscribe(
		{},
		network.remotes.ids.reliable.hopperbin.select,
		function(player, bin: unknown)
			assert(typeof(bin) == "Instance")
			assert(bin:IsA("HopperBin"))

			-- other than for security, this could prevent against some weird edge cases
			-- (like if a bin was parented to another player, and the events were received late.)
			if validate_bin_ownership(player, bin) then
				increment_attribute(bin, "select")
			end
		end
	)

	network.remotes.reliable.server.subscribe(
		{},
		network.remotes.ids.reliable.hopperbin.deselect,
		function(player, bin: unknown)
			assert(typeof(bin) == "Instance")
			assert(bin:IsA("HopperBin"))

			if validate_bin_ownership(player, bin) then
				increment_attribute(bin, "deselect")
			end
		end
	)

	local function handle_special_key(key: unknown, mouse: FakeMouse)
		if key == SPECIAL_KEYS.MB1_DOWN then
			mouse.button_1_down.fire()
			return true
		elseif key == SPECIAL_KEYS.MB1_UP then
			mouse.button_1_up.fire()
			return true
		elseif key == SPECIAL_KEYS.MB2_DOWN then
			mouse.button_2_down.fire()
			return true
		elseif key == SPECIAL_KEYS.MB2_UP then
			mouse.button_2_up.fire()
			return true
		end

		return false
	end

	network.remotes.unreliable.server.subscribe(
		{},
		network.remotes.ids.unreliable.mouse.update,
		function(player, payload: any)
			assert(typeof(payload) == "table")
			local mouse = fake_mice[player]

			mouse.location = payload[1]
			mouse.target = payload[2]
			local keys = payload[3]
			mouse.hit = CFrame.new(payload[4])

			local special_keys = {}

			for key, pressed in keys do
				if SPECIAL_KEY_REVERSER[key] then
					table.insert(special_keys, key)
					continue
				end

				if pressed then
					mouse.key_down.fire(key)
				else
					mouse.key_up.fire(key)
				end
			end

			-- handle special keys in order. mouse down events should always fire before up.
			table.sort(special_keys, sort_special_keys)

			for _, key in special_keys do
				handle_special_key(key, mouse)
			end
		end
	)
end, RunService:IsServer())

-- Server
-- HopperBins used to listen to player input on the server.
app.add_patch(
	"hopperbin_select_emu",
	patching.getter_patch {
		classes = { "HopperBin" },
		keys = { "Selected", "selected" },
		run = function(context, _key)
			local selected_signal = get_server_select_signal(context.unsandboxed_object)
			local fake_signal = FakeSignal.new()
			local player = context.unsandboxed_object.Parent.Parent

			assert(player, "no player?")
			assert(player:IsA("Player"), "not a player?")

			FakeSignal.wire(fake_signal.signal, selected_signal, function(_real_mouse)
				local mouse = fake_mice[player]
				mouse.real_mouse = _real_mouse

				assert(mouse, `{player} is missing fake mouse`)
				return mouse.object
			end)

			return fake_signal.signal
		end,
	},
	RunService:IsServer()
)

app.add_patch(
	"hopperbin_deselect_emu",
	patching.getter_patch {
		classes = { "HopperBin" },
		keys = { "Deselected", "deselected" },
		run = function(context, _key)
			-- using attributes allowed me to dodge the GC handling nightmare here! yay!
			return get_server_deselect_signal(context.unsandboxed_object)
		end,
	},
	RunService:IsServer()
)

return nil
