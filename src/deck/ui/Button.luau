local plz = require("@layer/plz")
local prefabs = require("./prefabs")

local BOLD_UBUNTU = Font.fromName("Ubuntu", Enum.FontWeight.Bold)

export type Props = {
    text: string,
}

local function Button(pen: plz.Pen, props: Props)
    local button = pen:node(prefabs.Button)
    button.Size = UDim2.fromOffset(110, 30)
    button.BackgroundColor3 = Color3.new(0.031373, 0.109804, 0.258824)
    button.TextColor3 = Color3.new(0.815686, 0.784314, 0.968627)
    button.BackgroundTransparency = 0
    button.FontFace = BOLD_UBUNTU
    button.TextSize = 12
    button.Text = props.text

    local stroke = pen:node(prefabs.UIStroke)
    stroke.Thickness = 2
    stroke.LineJoinMode = Enum.LineJoinMode.Miter
    stroke.BorderStrokePosition = Enum.BorderStrokePosition.Inner
    stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    stroke.Color = Color3.fromRGB(75, 86, 132)
    stroke.Parent = button

    return button
end

return Button