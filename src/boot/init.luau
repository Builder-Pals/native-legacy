local network = require("./network")
local defiltering = require("./sandbox/defiltering")
local app = require("@layer/app")
local console = require("./console")
local nl_tags = require("./nl_tags")

local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local StarterPlayer = game:GetService("StarterPlayer")

local external_boot_prefab = script:WaitForChild("external_boot")

local IS_CLIENT = RunService:IsClient()

local function clone_starter_player_scripts()
	local starter_scripts = StarterPlayer:WaitForChild("StarterCharacterScripts")

	local animate = script.Parent:WaitForChild("character"):WaitForChild("Animate"):Clone()
	local bindable = Instance.new("BindableFunction")
	bindable.Name = "PlayEmote"
	bindable.Parent = animate
	animate.Parent = starter_scripts

	local place_hop_camera = script.Parent:WaitForChild("character"):WaitForChild("place_hop_camera"):Clone()
	place_hop_camera.Parent = starter_scripts
end

local function make_sandboxer(name: string)
	-- Create a module underneath game that's easy to call from sandboxed scripts
	local external_boot = external_boot_prefab:Clone()
	external_boot.Name = name

	external_boot:AddTag(nl_tags.RELOAD_PROTECTION)

	local ref = Instance.new("ObjectValue")
	ref.Value = script.Parent
	ref.Name = "module"
	ref.Parent = external_boot

	external_boot.Parent = game
end

--- fires up the layer. should be called once on the server, and once on all clients!
return function()
	print("----")
	print("booting native legacy...")

	print("starting app...")
	app.start()
	console.init()

	if IS_CLIENT then
		network.init()
		defiltering.start_client()
	else
		if SoundService.RespectFilteringEnabled then
			print("SoundService.RespectFilteringEnabled has been changed to false")
			SoundService.RespectFilteringEnabled = false
		end

		clone_starter_player_scripts()
		network.init()
		defiltering.start_server()
	end

	-- Create a module underneath game that's easy to call from sandboxed scripts
	make_sandboxer("native_legacy")
	make_sandboxer("NostalgicScriptLoader") -- backwards compatibility!

    print("nl is up!")
	print("----")
end
