--!nonstrict

local layer = require(script:WaitForChild("module").Value)

local LINKED_SOURCE_MAPPING = {
    ["http://www.roblox.com/asset/?id=1014542"] = require("@layer/linked_sources/paintball_gun")
}

return function(environment: any)
    if typeof(environment.script) == "Instance" then
        
    end

    layer.enter_sandbox(environment)
end