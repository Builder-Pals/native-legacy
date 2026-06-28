local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local app = require("@layer/app")

local sandbox = require("@layer/sandbox")
local Composite = require("@layer/util/Composite")
local patching = sandbox.patching

local NAME = "legacy_ownership"
local CHARACTER_TAG = "c"

local function migrate_ownership(part: BasePart)
	for _, character in CollectionService:GetTagged(CHARACTER_TAG) do
		if part:IsDescendantOf(character) then
			if part:CanSetNetworkOwnership() then
				part:SetNetworkOwner(Players:GetPlayerFromCharacter(character :: Model))
			end

            return
		end
	end

	if part:CanSetNetworkOwnership() then
		part:SetNetworkOwner(part:GetNetworkOwner())
	end
end

-- server
-- tags all player characters for convenience
app.add_system(NAME, function()
    Composite.common.player_added:connect(function(player: Player)
		Composite.from(player.CharacterAdded)
			:add(player.Character)
			:connect(function(character: Model)
				character:AddTag(CHARACTER_TAG)
				return nil
			end)
		
		return nil
	end)
end, RunService:IsServer())

-- future: optional inheritance support could be interesting, maybe the new reflection api can help?
local parts = { "Part", "BasePart", "WedgePart", "CornerWedgePart", "TrussPart", "MeshPart" }

app.add_patch(NAME, patching.setter_patch {
    classes = parts,
    keys = { "Parent", "parent" },
    enabled = RunService:IsServer(),
    run = function(context, key, value)
        local part = context.unsandboxed_object
        part.Parent = sandbox.sandboxer.unsandbox(value)

        if not part:IsDescendantOf(workspace) then
            return key, value
        end

        migrate_ownership(part)
        return key, value
    end
})

return nil