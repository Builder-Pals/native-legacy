local app = require("@layer/app")
local sandbox = require("@layer/sandbox")

local patching = sandbox.patching

local LEGACY_VELOCITY_PROPERTIES = {
	"Velocity",
	"velocity",
	"RotVelocity",
	"rotVelocity",
}

-- Velocity and RotVelocity predate Roblox's assembly-wide velocity model. In
-- the modern engine, assigning either property through an unanchored part of a
-- grounded assembly changes the anchored assembly root too. A non-zero linear
-- velocity on that root then makes the anchored surface behave like a conveyor.
--
-- Old scripts treated these as per-part properties. There is no independent
-- velocity to change while the part belongs to an anchored modern assembly, so
-- sink the legacy write instead of transferring it to the anchored root.
app.add_patch(
	"legacy_grounded_velocity",
	patching.setter_patch {
		types = { "Instance" },
		keys = LEGACY_VELOCITY_PROPERTIES,
		run = function(context, key, value)
			local part = context.unsandboxed_object

			if part:IsA("BasePart") and not part.Anchored then
				local assembly_root = part.AssemblyRootPart

				if assembly_root and assembly_root ~= part and assembly_root.Anchored then
					return nil, nil
				end
			end

			return key, value
		end,
	}
)

return nil
