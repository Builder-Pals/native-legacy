const Lighting = game:GetService("Lighting") :: Lighting & {
	--- deprecated
	ShadowColor: Color3,
} & {}

const BASE_SHADOW_COLOR = Color3.new(0.7, 0.7, 0.72)

const app = require("@layer/app")
const sandbox = require("@layer/sandbox")
local string_util = require("../../../util/string_util")
const sandboxer = sandbox.sandboxer
const patching = sandbox.patching

local function get_lighting_value(key: string): unknown
	return (Lighting :: Lighting & {})[key]
end

local function get_lighting_attribute(key: string): unknown
	return Lighting:GetAttribute(string_util.to_pascal(key)) or get_lighting_value(key)
end

local function get_fallbackless_attribute(key: string): unknown
	return Lighting:GetAttribute(string_util.to_pascal(key))
end

local function set_lighting_attribute(key: string, value: unknown)
	Lighting:SetAttribute(string_util.to_pascal(key), value)
end

type Processors = { [string]: (any) -> any }

local function brightness_processor(value: number)
	--[[
        Setting brightness to 0 on the modern client hides per-pixel shadows entirely,
        this wasn't the case with stencil shadows and has a signficiant effect on lighting.

        We'll use +0.8 as a basis to always have shadows. Exposure compensation
        is lowered to balance out the change. The result is more pronounced shadows,
        without compromising too much on brightness.
        
        A major thing missing is the deprecated ShadowColor property, the luminosity effected:
        0 - Visible shadows,
        1 - No shadows

        We can't change the color, but we can mimick how pronounced the shadows are
        as described before.
    ]]

	local remap_amount = 0.8
	local shadow_color = get_lighting_attribute("ShadowColor") :: Color3

	if shadow_color ~= BASE_SHADOW_COLOR then
		local _, _, luminosity = shadow_color:ToHSV()
		remap_amount *= 1 - luminosity
	end

	if get_fallbackless_attribute("ColorShift_Bottom") == nil then
		Lighting.ColorShift_Bottom = shadow_color
	end

	local remapped = value + remap_amount

	Lighting.Brightness = remapped
	Lighting.ExposureCompensation = -remap_amount

	return remapped
end

local processors = {
	Brightness = brightness_processor,

	Ambient = function(value: Color3)
		--[[
            The influence of `Ambient` on the lower lighting range is more pronounced
        ]]
		local _, _, luminosity = value:ToHSV()
		return value:Lerp(Color3.new(0, 0, 0), math.min(0.5 - luminosity, 0))
	end,

	ShadowColor = function(value: Color3)
		brightness_processor(get_lighting_attribute("Brightness") :: number)
		return value
	end,
}

app.add_patch(
	"lighting_remapper",
	patching.setter_patch {
		classes = { "Lighting" },
		keys = { "Brightness" },
		run = function(context, key, value)
			local unsandboxed_value = sandboxer.unsandbox(value)

			-- throw an excpetion if it's an invalid key
			local _ = Lighting[key]

			local processor = processors[string_util.to_pascal(key)]
			local mutated_value = processor(unsandboxed_value)

			set_lighting_attribute(key, mutated_value)

			return key, mutated_value
		end,
	},
	true
)

-- patch getter to use the attributes instead
app.add_patch(
	"lighting_remapper_getter",
	patching.getter_patch {
		classes = { "Lighting" },
		keys = { "Brightness", "GlobalShadows" },
		run = function(context, key)
			local unsandboxed_value = get_lighting_attribute(key)
			return key, unsandboxed_value
		end,
	},
	true
)

local function run_remapper()
	for property, processor in processors :: Processors do
		local value = (Lighting :: Lighting & {})[property]
		set_lighting_attribute(property, processor(value))
	end
end

app.add_system("lighting_remapper", function()
	for property, processor in processors :: Processors do
		Lighting:GetAttributeChangedSignal(property):Connect(function()
			local value = get_lighting_attribute(property)
			local mutated_value = processor(value);
			(Lighting :: Lighting & {})[property] = mutated_value
		end)
	end
end, app.run_flags.CLIENT)

local function restore_defaults()
	Lighting.Brightness = 1
	Lighting.Ambient = Color3.fromRGB(127, 127, 127)
	Lighting.OutdoorAmbient = Color3.fromRGB(127, 127, 127)
	Lighting.ColorShift_Bottom = Color3.fromRGB(255, 255, 255)
	Lighting.ColorShift_Top = Color3.fromRGB(255, 255, 255)
	Lighting.ShadowColor = BASE_SHADOW_COLOR
	Lighting.ClockTime = 14
	Lighting.FogColor = Color3.fromRGB(255, 255, 255)
	Lighting.FogStart = 0
	Lighting.FogEnd = 100000

	for property in processors :: Processors do
		set_lighting_attribute(property, nil)
	end
end

local function make_lighting_effects()
	local bloom_disabler = Instance.new("BloomEffect")
	bloom_disabler.Archivable = false
	bloom_disabler.Name = "nl_no_bloom"
	bloom_disabler.Intensity = 0
	bloom_disabler.Parent = Lighting

	local color_grading = Instance.new("ColorGradingEffect")
	color_grading.TonemapperPreset = Enum.TonemapperPreset.Retro
	color_grading.Name = "nl_color_grading"
	color_grading.Parent = Lighting
end

return {
	restore_defaults = restore_defaults,
	make_lighting_effects = make_lighting_effects,
	run_remapper = run_remapper,
}
