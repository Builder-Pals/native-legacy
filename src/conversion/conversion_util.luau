local ChangeHistoryService = game:GetService("ChangeHistoryService")

local WRAPPER = [[require(game:WaitForChild("native_legacy"))(getfenv());]]
local DONT_SANDBOX_FLAG = "nl_dont_sandbox"
local CHANGE_ACTION = "nl_tree"

local TARGET_SERVICES = {
    Workspace = true,
    Players = true,
    Lighting = true,
    ReplicatedStorage = true,
    ReplicatedFirst = true,
    ServerScriptService = true,
    ServerStorage = true,
    StarterGui = true,
    StarterPack = true,
    StarterPlayer = true,
    Chat = true,
    Teams = true,
    SoundService = true,
}

-- the LuaSourceContainer type doesn't include the Source property, so we'll do it ourselves :>
type SourceContainer = ModuleScript | Script | LocalScript

local function can_sandbox(instance: Instance)
	return instance:FindFirstChild(DONT_SANDBOX_FLAG) == nil and not instance:HasTag(DONT_SANDBOX_FLAG)
end

local conversion_util = {}

function conversion_util.convert_source(source: string)
	return if source:sub(1, #WRAPPER) == WRAPPER then source else WRAPPER .. source
end

function conversion_util.convert_script(script: SourceContainer)
	script.Source = conversion_util.convert_source(script.Source)
end

local function convert_node(instance: Instance)
	if
		can_sandbox(instance)
		and (instance:IsA("ModuleScript") or instance:IsA("Script") or instance:IsA("LocalScript"))
	then
		conversion_util.convert_script(instance)
	end

	for _, child in ipairs(instance:GetChildren()) do
		if can_sandbox(child) then
			convert_node(child)
		end
	end
end

--- Converts a 
function conversion_util.convert_game(data_model: DataModel)
    for _, service in ipairs(data_model:GetChildren()) do
        if TARGET_SERVICES[service.Name] then
            convert_node(service)
        end
    end
end

--- Sandboxes an Instance (and all of its descendants)
function conversion_util.convert_tree(instance: Instance)
	local recording = ChangeHistoryService:TryBeginRecording(CHANGE_ACTION, "NL tree conversion")

	if not recording then
		warn(`change history service error, only one operation can be recorded at a time.`)
	end

	convert_node(instance)

	ChangeHistoryService:FinishRecording(CHANGE_ACTION, Enum.FinishRecordingOperation.Commit)
end

return conversion_util
