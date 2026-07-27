local plz = require("@layer/plz")
local Button = require("./Button")
local prefabs = require("./prefabs")

export type Props = {
	title: string,
	thumbnail: string,
	description: string,
}

const TITLE_SIZE = 40
const STROKE_CLR = Color3.new(0.1, 0.1, 0.1)

local function add_stroke(pen: plz.Pen, parent: Instance)
	local stroke = pen:node(prefabs.UIStroke)
	stroke.Thickness = 1
	stroke.Color = STROKE_CLR
	stroke.BorderStrokePosition = Enum.BorderStrokePosition.Inner
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = parent
end

local function GameCard(pen: plz.Pen, props: Props)
	local frame = pen:node(prefabs.Frame)
	frame.Name = "game_card"
	frame.Size = UDim2.fromScale(1, 1)
	frame.BackgroundTransparency = 1
	frame.BackgroundTransparency = 1

	do
		local rect = Rect.new(16, 16, 16, 16)

		local title = pen:node(prefabs.Image)
		title.Name = "title"
		title.Image = "rbxassetid://121175181981781"
		title.ScaleType = Enum.ScaleType.Slice
		title.SliceCenter = rect
		title.Size = UDim2.new(1, 0, 0, TITLE_SIZE)
		title.Parent = frame

		local gradient = pen:node(prefabs.UIGradient)
		gradient.Rotation = 90
		gradient.Color = ColorSequence.new {
			ColorSequenceKeypoint.new(0, Color3.new(0.15, 0.15, 0.15)),
			ColorSequenceKeypoint.new(0.7, STROKE_CLR),
			ColorSequenceKeypoint.new(1, STROKE_CLR),
		}
		gradient.Parent = title

		local text = pen:node(prefabs.Label)
		text.TextXAlignment = Enum.TextXAlignment.Left
		text.Text = props.title
		text.FontFace = Font.fromName("Ubuntu", Enum.FontWeight.Bold)
		text.TextSize = 22
		text.TextColor3 = Color3.new(0.75, 0.75, 0.75)
		text.Size = UDim2.fromScale(1, 1)
		text.Position = UDim2.fromOffset(8, 0)
		text.Parent = title
	end

	local content = pen:node(prefabs.Frame)
	content.Name = "content"
	content.Position = UDim2.fromOffset(0, TITLE_SIZE)
	content.Size = UDim2.new(1, 0, 0, 0)
	content.AutomaticSize = Enum.AutomaticSize.Y
	content.BackgroundTransparency = 0
	content.Parent = frame

	local thumb = pen:node(prefabs.Image)
	thumb.Name = "thumb"
	thumb.Position = UDim2.fromOffset(0, 58)
	thumb.Image = props.thumbnail
	thumb.Size = UDim2.new(1, 0, 0, 300)
	--thumb.ScaleType = Enum.ScaleType.Fit
	thumb.Parent = content
	add_stroke(pen, thumb)

	local aspect = pen:node(prefabs.AspectConstraint)
	aspect.AspectRatio = 16 / 9
	aspect.Parent = thumb

	local spacer = pen:node(prefabs.Frame)
	spacer.BackgroundTransparency = 1
	spacer.Size = UDim2.fromOffset(0, 8)
	spacer.Parent = frame

	do
		local box = pen:node(prefabs.Frame)
		box.Name = "desc"
		box.Size = UDim2.new(1, 0, 0, 200)
		box.BackgroundColor3 = Color3.new(0.811765, 0.811765, 0.811765)
		box.Parent = content

		local description = pen:node(prefabs.Label)
		description.Size = UDim2.new(1, 0, 1, 0)
		description.Text = props.description
		description.TextXAlignment = Enum.TextXAlignment.Left
		description.TextYAlignment = Enum.TextYAlignment.Top
		description.TextWrapped = true
		description.TextColor3 = Color3.new(0.08, 0.08, 0.08)
		description.TextSize = 14
		description.FontFace = Font.fromName("Ubuntu", Enum.FontWeight.Regular)
		description.Parent = box

		local text_fade = pen:node(prefabs.UIGradient)
		text_fade.Rotation = 90
		text_fade.Transparency = NumberSequence.new {
			NumberSequenceKeypoint.new(0, 0),
			NumberSequenceKeypoint.new(0.5, 0),
			NumberSequenceKeypoint.new(1, 1),
		}
		text_fade.Parent = description

		add_stroke(pen, box)

		local padding = pen:node(prefabs.UIPadding)
		padding.PaddingLeft = UDim.new(0, 8)
		padding.PaddingRight = UDim.new(0, 8)
		padding.PaddingTop = UDim.new(0, 8)
		padding.PaddingBottom = UDim.new(0, 8)
		padding.Parent = box

		local btn = Button(pen, {
			text = "Open",
		})

		btn.AnchorPoint = Vector2.new(1, 1)
		btn.Position = UDim2.fromScale(1, 1)
		btn.ZIndex = 1

		btn.Parent = box
	end

	local layout = pen:node(prefabs.UIListLayout)
	layout.Padding = UDim.new(0, 8)
	layout.Parent = content

	local padding = pen:node(prefabs.UIPadding)
	padding.PaddingLeft = UDim.new(0, 8)
	padding.PaddingRight = UDim.new(0, 8)
	padding.PaddingTop = UDim.new(0, 8)
	padding.PaddingBottom = UDim.new(0, 8)
	padding.Parent = content

	-- TODO: pop the original author's robloxian out of the top right of the description

	return frame
end

return GameCard
