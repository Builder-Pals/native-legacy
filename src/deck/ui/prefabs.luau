local plz = require("@layer/plz")

local gui_prefab = Instance.new("ScreenGui")
gui_prefab.ResetOnSpawn = false
gui_prefab.Name = "plz click"

local frame_prefab = Instance.new("Frame")
frame_prefab.BorderSizePixel = 0

local button_prefab = Instance.new("TextButton")
button_prefab.Text = ""
button_prefab.BorderSizePixel = 0

local label_prefab = Instance.new("TextLabel")
label_prefab.BackgroundTransparency = 1

local image_prefab = Instance.new("ImageLabel")
image_prefab.BackgroundTransparency = 1

local ui_stroke_prefab = Instance.new("UIStroke")

local aspect_constraint = Instance.new("UIAspectRatioConstraint")

local ui_padding_prefab = Instance.new("UIPadding")

local ui_list_layout_prefab = Instance.new("UIListLayout")
ui_list_layout_prefab.SortOrder = Enum.SortOrder.LayoutOrder

local ui_gradient_prefab = Instance.new("UIGradient")

local Button = plz.allocate(button_prefab)
local ScreenGui = plz.allocate(gui_prefab)
local Frame = plz.allocate(frame_prefab)
local Label = plz.allocate(label_prefab)
local Image = plz.allocate(image_prefab)
local UIStroke = plz.allocate(ui_stroke_prefab)
local UIAspectRatioConstraint = plz.allocate(aspect_constraint)
local UIPadding = plz.allocate(ui_padding_prefab)
local UIListLayout = plz.allocate(ui_list_layout_prefab)
local UIGradient = plz.allocate(ui_gradient_prefab)

return {
    Button = Button,
    ScreenGui = ScreenGui,
    Frame = Frame,
    Label = Label,
    Image = Image,
    UIStroke = UIStroke,
    AspectConstraint = UIAspectRatioConstraint,
    UIPadding = UIPadding,
    UIListLayout = UIListLayout,
    UIGradient = UIGradient,

    sources = {
        Button = button_prefab,
        Frame = frame_prefab
    }
}