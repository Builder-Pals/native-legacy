local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local hopperbin_emu = require("./hopperbin_emu")
local app = require("@layer/app")
local routing = require("@layer/routing")
local sandbox = require("@layer/sandbox")
local Composite = require("@layer/util/Composite")
local patching = sandbox.patching

local FAKE_TAG = "_fake_hopper"

local function get_tool(name: string)
	return routing.TOOLS:WaitForChild(name)
end

local BTOOL_TYPES = {
	[Enum.BinType.GameTool] = get_tool("GameTool"),
	[Enum.BinType.Clone] = get_tool("Clone"),
	[Enum.BinType.Hammer] = get_tool("Hammer"),
}

local function get_bin_type(bin: HopperBin): Enum.BinType
	local value = bin:GetAttribute("bin_type")

	if value == nil then
		return bin.BinType
	end

	local bin_type = Enum.BinType:FromValue(value :: number)
	assert(bin_type, `Invalid bin type for tool {bin.Name}: {bin:GetAttribute("bin_type")}`)
	return bin_type
end

local function set_bin_type(tool: Instance, bin_type: Enum.BinType)
	tool:SetAttribute("bin_type", bin_type.Value)
end

-- swaps btools out for recreations
-- due to defiltering, we don't have to worry about the client creating tools that won't be
-- detected by this check.
app.add_system("btools_server_swapper", function(_)
	Composite.common.player_added:connect(function(player: Player)
		print(`checking for btools in backpack for {player.Name}`)

		local function with_hopper_bin(bin: HopperBin)
			print(`found hopper bin for {player.Name}: {bin.Name} ({bin.BinType})`)

			-- enforce the real bin type as script to prevent clashing with the modernised tools
			if bin.BinType ~= Enum.BinType.Script then
				set_bin_type(bin, bin.BinType)
				bin.BinType = Enum.BinType.Script
			end

			local tool
			local is_selected = false

			local function refresh_tool()
				if not is_selected then
					if tool then
						tool:Destroy()
						tool = nil
					end

					return
				end

				local new_tool = BTOOL_TYPES[get_bin_type(bin)]

				if not new_tool then
					return
				end

				new_tool = new_tool:Clone()
				new_tool.Parent = player.Character

				tool = new_tool
			end

			local select_connection = hopperbin_emu.on_select(bin):Connect(function()
				is_selected = true
				refresh_tool()
			end)

			local deselect_connection = hopperbin_emu.on_deselect(bin):Connect(function()
				is_selected = false
				refresh_tool()
			end)

			local type_connection = bin:GetPropertyChangedSignal("BinType"):Connect(refresh_tool)

			return function()
				select_connection:Disconnect()
				deselect_connection:Disconnect()
				type_connection:Disconnect()
			end
		end

		local function with_player_child(backpack: Instance)
			if not backpack:IsA("Backpack") then
				return
			end

			print(`found backpack for {player.Name}`)

			local function with_backpack_child(bin: Instance)
				if bin:IsA("HopperBin") then
					local cleanup = with_hopper_bin(bin)
					bin:GetPropertyChangedSignal("Parent"):Once(cleanup)
				end
			end

			backpack.ChildAdded:Connect(with_backpack_child)

			for _, child in backpack:GetChildren() do
				with_backpack_child(child)
			end
		end

		for _, child in player:GetChildren() do
			with_player_child(child)
		end

		player.ChildAdded:Connect(with_player_child)
		return nil
	end)
end, app.run_flags.SERVER)

-- client
-- resets the mouse when a btool accessory is removed from the character
app.add_system("btools_mouse_resetter", function(_)
	local player = Players.LocalPlayer
	Composite.new():listen(player.CharacterAdded):add(player.Character):connect(function(character: Model)
		character.ChildRemoved:Connect(function(child)
			if child:HasTag("BuildTool") then
				UserInputService.MouseIcon = ""
			end
		end)

		return nil
	end)
end, app.run_flags.CLIENT)

-- shared
-- spoofs btools to have HopperBin as the class name
app.add_patch(
	"btools_class_spoofer",
	patching.getter_patch {
		classes = { "Tool" },
		keys = { "className", "ClassName" },
		run = function(context)
			if context.unsandboxed_object:HasTag(FAKE_TAG) then
				return "HopperBin"
			end

			return context.snapshot
		end,
	}
)

-- patch to use the get_bin_type function for the BinType property
app.add_patch(
	"btools_bin_type_spoofer",
	patching.getter_patch {
		classes = { "HopperBin" },
		keys = { "BinType", "binType" },
		run = function(context)
			return get_bin_type(context.unsandboxed_object)
		end,
	}
)

return nil
