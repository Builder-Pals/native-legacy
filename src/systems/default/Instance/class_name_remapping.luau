const app = require("@layer/app")
const sandbox = require("@layer/sandbox")
const patching = sandbox.patching

const REMAPPING: { [string]: string } = {
	Accessory = "Hat",
	MeshPart = "Part"
}

for old, new in REMAPPING do
	app.add_patch(
		`class_name_remapping_{old}`,
		patching.getter_patch {
			classes = { old },
			keys = { "ClassName", "className" },
			run = function(context, key)
				return new
			end,
		}
	)
end

return nil
