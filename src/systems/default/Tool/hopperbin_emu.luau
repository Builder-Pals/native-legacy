local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local app = require("@layer/app")
local sandbox = require("@layer/sandbox")
local with_players = require("@layer/util/with_players")
local FakeSignal = require("@layer/util/FakeSignal")
local network = require("@layer/network")

local patching = sandbox.patching

export type FakeMouse = {
	player: Player,
	real_mouse: Mouse,
	object: any,
	key_down: FakeSignal.SignalContext,
	key_up: FakeSignal.SignalContext,
	location: Vector2,
	hit: CFrame,
	target: Instance?,
}

app.add_system("hopperbin_send_input", function(_app)
	local bin_selected = false
	local input_pool = {}
	local mouse = Players.LocalPlayer:GetMouse()

	with_players(function(player)
		local function with_backpack(backpack: Backpack)
			local function with_hopperbin(bin: HopperBin)
				local select_connection = bin.Selected:Connect(function()
					bin_selected = true
				end)

				local deselect_connection = bin.Deselected:Connect(function()
					bin_selected = false
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

		return nil
	end)

	UserInputService.InputBegan:Connect(function(input, processed)
		if processed then
			return
		end

		if input.UserInputType == Enum.UserInputType.Keyboard and bin_selected then
			input_pool[input.KeyCode.Name:lower()] = true
		end
	end)

	UserInputService.InputEnded:Connect(function(input, processed)
		if processed then
			return
		end

		if input.UserInputType == Enum.UserInputType.Keyboard and bin_selected then
			input_pool[input.KeyCode.Name:lower()] = false
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
				mouse.Hit.Position
			}

			network.remotes.unreliable.client.send(network.remotes.ids.unreliable.mouse.update, data)
			table.clear(input_pool)
		end
	end)
end, RunService:IsClient())

local mice_data: { [Player]: { location: Vector2, target: Instance? } } = {}
local fake_mice: { [Player]: FakeMouse } = {}

local function mouse_index(self, key: string): any
	local data = rawget(self, "data") :: FakeMouse
	local lower_key = key:lower()

	if lower_key == "x" then
		return data.location.X
	end

	if lower_key == "y" then
		return data.location.Y
	end

	if key == "Target" or key == "target" then
		return data.target
	end

	if key == "KeyDown" or key == "keyDown" then
		return data.key_down.signal
	end

	if key == "KeyUp" or key == "keyUp" then
		return data.key_up.signal
	end

	if key == "Hit" or key == "hit" then
		return data.hit
	end

	print("fallback", key)
	return (data.real_mouse :: any)[key]
end

app.add_system("hopperbin_receive_input", function(_app)
	with_players(function(player)
		local fake_mouse_data: FakeMouse = {
			player = player,
			real_mouse = player:GetMouse(),

			key_down = FakeSignal.new(),
			key_up = FakeSignal.new(),

			location = Vector2.zero,
			target = nil,

			hit = CFrame.identity,

			[patching.symbols.FAKE_TYPE] = "userdata",
			[patching.symbols.FAKE_TYPEOF] = "Instance",
		}

		fake_mouse_data.object = setmetatable({ data = fake_mouse_data }, { __index = mouse_index })
		fake_mice[player] = fake_mouse_data

		return function()
			mice_data[player] = nil
			fake_mice[player] = nil
		end
	end)

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

			for key, pressed in keys do
				if pressed then
					mouse.key_down.fire(key)
				else
					mouse.key_up.fire(key)
				end
			end
		end
	)
end, RunService:IsServer())

-- HopperBins used to listen to player input on the server.

app.add_patch(
	"hopperbin_emu",
	patching.getter_patch {
		classes = { "HopperBin" },
		keys = { "Selected", "selected" },
		run = function(context, _key)
			local selected_signal = context.unsandboxed_object.Selected :: RBXScriptSignal
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

return nil
