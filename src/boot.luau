local network = require("./network")
local sandbox = require("./sandbox")
local defiltering = require("./sandbox/defiltering")
local app = require("@layer/app")

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

return function()
	print("----")
	print("booting nl...")

	print("starting app...")
	app.start()

	if IS_CLIENT then
		network.init()
		sandbox.instance_pool.start_client(app.context)
		defiltering.start_client()
	else
		if SoundService.RespectFilteringEnabled then
			print("SoundService.RespectFilteringEnabled has been changed to false")
			SoundService.RespectFilteringEnabled = false
		end

		clone_animate()
		network.init()
		sandbox.instance_pool.start_server()
		defiltering.start_server()
	end

	-- Create a module underneath game that's easy to call from sandboxed scripts
	local external_boot = external_boot_prefab:Clone()
	external_boot.Name = "native_legacy"

	local ref = Instance.new("ObjectValue")
	ref.Value = script.Parent
	ref.Name = "module"
	ref.Parent = external_boot

	external_boot.Parent = game

    print("nl is now running!")
	print("----")
end
