local RunService = game:GetService("RunService")

local FOLDER_NAME = ""

if RunService:IsServer() then
    local folder = Instance.new("Folder")
    folder.Name = FOLDER_NAME
    folder.Archivable = false
    folder.Parent = script
    return folder
else
    local folder = script:WaitForChild(FOLDER_NAME)
    assert(folder:IsA("Folder"))
    folder.Parent = nil
    return folder
end