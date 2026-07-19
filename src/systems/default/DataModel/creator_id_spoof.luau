const app = require("@layer/app")
const sandbox = require("@layer/sandbox")
const patching = sandbox.patching

--[[
    added this because a game (sword fighting tournament 2011) kicked me out for having a different id.
    you really never know until you test a bunch lol
]]

app.add_patch(
    "creator_id_spoof",
    patching.getter_patch {
        classes = { "DataModel" },
        keys = { "creatorId", "CreatorId" },
        run = function(context, _key)
            return workspace:GetAttribute("CreatorId") or context.snapshot
        end,
    }
)

app.add_patch(
    "creator_type_spoof",
    patching.getter_patch {
        classes = { "DataModel" },
        keys = { "creatorType", "CreatorType" },
        run = function(context, _key)
            local attribute = workspace:GetAttribute("CreatorType")

            if attribute then
                return Enum.CreatorType:FromName(attribute :: string)
            end

            return context.snapshot
        end,
    }
)

return nil
