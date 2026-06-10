local RunService = game:GetService("RunService")

if RunService:IsClient() then
    return script:WaitForChild("RemoteFunction") :: RemoteFunction
end

local remote = Instance.new("RemoteFunction")
remote.Archivable = false
remote.Parent = script

return remote