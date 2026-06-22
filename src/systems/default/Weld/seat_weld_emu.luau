local RunService = game:GetService("RunService")

local app = require("@layer/app")
local sandbox = require("@layer/sandbox")
local patching = sandbox.patching
local sandboxer = sandbox.sandboxer

-- seat welds were made to the Torso before the HumanoidRootPart was added to the R6 rig.
-- this behaviour is relied on by old vehicle tools to check who is seated.
--
-- without this patch, most vehicle hopper bins (which are based on the plane tool) break.
app.add_patch(
	"seat_weld_emu",
	patching.getter_patch {
		classes = { "Weld" },
		keys = { "Part1", "part1" },
		run = function(context, _key)
			local weld = context.unsandboxed_object :: BasePart?
            local part_1 = context.unsandboxed :: Weld

            if weld and weld.Name == "SeatWeld" and part_1.Parent and part_1.Name == "HumanoidRootPart" then
                return sandboxer.sandbox(context.sandbox_context, part_1.Parent:FindFirstChild("Torso") or part_1)
            end

            return context.snapshot
		end,
	},
	RunService:IsServer()
)


return nil