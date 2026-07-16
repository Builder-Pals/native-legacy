local sandbox = require("@layer/sandbox")
local make_joints = require("../../../util/make_joints")
local app = require("@layer/app")
local patching = require("@layer/sandbox/patching")

local function make_class_pack()
	local copy = table.clone(patching.class_packs.parts)
	table.insert(copy, "Workspace")
    return copy
end

local make_joints_classes = make_class_pack()

--[[
    
--]]
app.add_patch(
	"restore_make_joints",
	patching.getter_patch {
		classes = make_joints_classes,
		keys = { "MakeJoints", "makeJoints" },
		run = function(context, _key)
			return function(sandboxed_self)
                local self = sandbox.sandboxer.unsandbox(sandboxed_self)
                assert(typeof(self) == "Instance", "Expected ':' not '.' calling member function MakeJoints")
                assert(table.find(make_joints_classes, self.ClassName), "Expected ':' not '.' calling member function MakeJoints")
				return make_joints.make_joints(self)
			end
		end,
	}
)

app.add_patch(
    "restore_break_joints",
    patching.getter_patch {
        classes = make_joints_classes,
        keys = { "BreakJoints", "breakJoints" },
        run = function(context, _key)
            return function(sandboxed_self)
                local self = sandbox.sandboxer.unsandbox(sandboxed_self)
                assert(typeof(self) == "Instance", "Expected ':' not '.' calling member function BreakJoints")
                assert(table.find(make_joints_classes, self.ClassName), "Expected ':' not '.' calling member function BreakJoints")
                return make_joints.break_joints(self)
            end
        end,
    }
)

return nil
