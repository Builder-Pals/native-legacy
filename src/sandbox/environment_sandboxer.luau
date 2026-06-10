
local start_instance_pool = require("@layer/instance_pool/start_instance_pool")
local patch_filter_selector = require("@layer/patching/patch_filter_selector")
local patch_module_selector = require("@layer/patching/patch_module_selector")
local new_sandboxed_instance_constructor = require("./new_sandboxed_instance_constructor")
local sandbox_types = require("./sandbox_types")
local sandboxer = require("./sandboxer")

local environment_sandboxer = {}

function environment_sandboxer.sandbox_environment_default(environment: any)
    local patches = {}

    for _, patch in script.Parent.Parent.patches.default:GetDescendants() do
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
    environment.Instance = new_sandboxed_instance_constructor(context, start_instance_pool())
end

return environment_sandboxer