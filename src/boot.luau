local network = require("./network")
local defiltering = require("./sandbox/defiltering")
local app = require("@layer/app")
local pool = require("./sandbox/pool")

local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local StarterPlayer = game:GetService("StarterPlayer")

local external_boot_prefab = script.Parent.external_boot

local IS_CLIENT = RunService:IsClient()

local function clone_animate()
	local animate = script.Parent:WaitForChild("character"):WaitForChild("Animate"):Clone()
	local bindable = Instance.new("BindableFunction")
	bindable.Name = "PlayEmote"
	bindable.Parent = animate

	animate.Parent = StarterPlayer:WaitForChild("StarterCharacterScripts")
end

local function make_sandboxer(name: string)
	-- Create a module underneath game that's easy to call from sandboxed scripts
	local external_boot = external_boot_prefab:Clone()
	external_boot.Name = name

	local ref = Instance.new("ObjectValue")
	ref.Value = script.Parent
	ref.Name = "module"
	ref.Parent = external_boot

	external_boot.Parent = game
end

return function()
	print("----")
	print("booting nl...")

	print("starting app...")
	app.start()

	if IS_CLIENT then
		network.init()
		defiltering.start_client()
	else
		if SoundService.RespectFilteringEnabled then
			print("SoundService.RespectFilteringEnabled has been changed to false")
			SoundService.RespectFilteringEnabled = false
		end

		clone_animate()
		network.init()
		defiltering.start_server()
	end

	-- Create a module underneath game that's easy to call from sandboxed scripts
	make_sandboxer("native_legacy")
	make_sandboxer("NostalgicScriptLoader") -- backwards compatibility!

    print("nl is now running!")
	print("----")
end
