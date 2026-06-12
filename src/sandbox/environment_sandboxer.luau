local RunService = game:GetService("RunService")
local patch_filter_selector = require("./patching/patch_filter_selector")
local patch_module_selector = require("./patching/patch_module_selector")
local instance_pool = require("./instance_pool")
local sandbox_types = require("./sandbox_types")
local sandboxer = require("./sandboxer")

local DEFAULT_PATCHES_FOLDER = script.Parent.Parent:WaitForChild("patches"):WaitForChild("default")

local runtime

--[=[
    Pulls environments (`getfenv()`) into the sandbox
]=]
local environment_sandboxer = {}

function environment_sandboxer.sandbox_environment_default(environment: any)
    local patches = {}

    for _, patch in DEFAULT_PATCHES_FOLDER:GetDescendants() do
        if not patch:IsA("ModuleScript") then
            continue
        end

        for _, sub_patch in patch_module_selector.get_patches(require(patch) :: any) do
            table.insert(patches, sub_patch)
        end
    end

    patches = patch_filter_selector.sort_patches(patches)
    environment_sandboxer.sandbox_environment(environment, { patches = patches })
end

function environment_sandboxer.sandbox_environment(environment: any, context: sandbox_types.SandboxContext)
    local sandboxed_workspace = sandboxer.sandbox(context, workspace)
    local sandboxed_game = sandboxer.sandbox(context, game)

    environment.workspace = sandboxed_workspace
    environment.Workspace = sandboxed_workspace
    environment.game = sandboxed_game
    environment.Game = sandboxed_game
    environment.script = sandboxer.sandbox(context, environment.script)

    -- future: maybe this should be constructed elsewhere and passed in, instance pool creation
    -- this kindaa feels like a weird side effect.
    local instance_pool_runtime = if runtime then runtime else if RunService:IsClient() then instance_pool.start_client() else instance_pool.start_server()
    runtime = instance_pool_runtime
    
    environment.Instance = instance_pool.new_lib(context, instance_pool_runtime)
end

return environment_sandboxer