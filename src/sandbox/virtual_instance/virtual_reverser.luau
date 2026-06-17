local constants = require("./virtual_constants")

return function(x: Instance)
    if x:HasTag(constants.RESOLVED_TAG) then
        print("SUCCESSFUL REVERSE:", x:GetFullName(), (x.Parent :: ObjectValue).Value:GetFullName())
        return (x.Parent :: ObjectValue).Value :: Instance
    else
        return x
    end
end