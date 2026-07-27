local plz = require("@layer/plz")
local catalog_types = require("../data/catalog_types")
local prefabs = require("./prefabs")

export type Props = {
	delta_time: number,
	games: { catalog_types.GameEntry },
	absolute_size: Vector2,
}

export type State = {
	scroll: number,
	user_scroll: number,
	focus: number,
	is_mouse_held: boolean,
	springs: { [number]: number },
}

const ENTRY_SIZE = 50
const EXPANDED_SIZE = 120
const INSET = 500
const PADDING = 8

local function GameWheel(pen: plz.Pen, props: Props, passed_state: State?)
	const state: State = passed_state
		or {
			scroll = 0,
			user_scroll = 0,
			focus = 0,
			is_mouse_held = false,
			springs = {},
		}

	local us = math.round(state.user_scroll / ENTRY_SIZE)

	if us ~= 0 then
		state.focus = math.clamp(state.focus + us, 0, #props.games)
		state.springs[state.focus] = state.springs[state.focus] or 0
		state.user_scroll = 0
	end

	local frame = pen:node(prefabs.Frame)
	frame.AnchorPoint = Vector2.new(1, 0)
	frame.Position = UDim2.fromScale(1, 0)
	frame.Size = UDim2.new(0, 500, 1, 0)
	frame.BackgroundTransparency = 0.2

	local function listen(node)
		plz.event(node, prefabs.sources.Frame.InputBegan, function(io: InputObject)
			if io.UserInputType == Enum.UserInputType.MouseButton1 then
				state.is_mouse_held = true
			end
		end)

		plz.event(node, prefabs.sources.Frame.InputEnded, function(io: InputObject)
			if io.UserInputType == Enum.UserInputType.MouseButton1 then
				state.is_mouse_held = false
			end
		end)

		plz.event(node, prefabs.sources.Frame.InputChanged, function(io: InputObject)
			if io.UserInputType == Enum.UserInputType.MouseWheel then
				state.user_scroll -= io.Position.Z * 10
			end

			if io.UserInputType == Enum.UserInputType.MouseMovement and state.is_mouse_held then
				state.user_scroll -= io.Delta.Y / 2
			end
		end)
	end

	listen(frame)

	local total_y = state.scroll

	for index, perc in state.springs do
		local is_focused = state.focus == index
		local goal = if is_focused then 1 else 0
		state.springs[index] = math.lerp(perc, goal, props.delta_time * if is_focused then 10 else 8)

		if goal == 0 and perc < 0.005 then
			print(`anim {index} finished`)
			state.springs[index] = nil
		end
	end

	for index, details in props.games do
		local is_selected = state.focus == index
		local y = total_y --(index * 58) + (math.sin(os.clock()) * 500)
		local center_proximity = math.abs(y - props.absolute_size.Y / 2) / props.absolute_size.Y -- math.clamp(props.absolute_size.Y / math.abs(y - props.absolute_size.Y), 0, 1)

		local entry = pen:node(prefabs.Button)
		entry.Position = UDim2.fromOffset(INSET * center_proximity ^ 2, y)

		plz.event(entry, prefabs.sources.Button.MouseButton1Click, function()
			if state.focus and state.focus == index then
				print("already focused")
				return
			end

			print("now focusing", index)
			state.focus = index
			state.springs[index] = state.springs[index] or 0
		end)

		local focus = state.springs[index] or 0

		entry.Size = UDim2.new(1, 0, 0, math.lerp(ENTRY_SIZE, EXPANDED_SIZE, focus))
		entry.BackgroundTransparency = 1
		entry.Parent = frame

		listen(entry)

		local game_name = pen:node(prefabs.Label)
		game_name.RichText = true
		game_name.Text = `<b>{details.name}</b> by {details.creator.name}`
		game_name.Position = UDim2.fromOffset(8, 0)
		game_name.TextXAlignment = Enum.TextXAlignment.Left
		game_name.ZIndex = 2
		game_name.Size = UDim2.new(1, 0, 0, ENTRY_SIZE)
		game_name.Font = Enum.Font.Cartoon
		game_name.TextSize = 17
		game_name.TextColor3 = Color3.new(0.9, 0.9, 0.9)
		game_name.TextTransparency = center_proximity * 2
		game_name.Parent = entry

		local game_thumb = pen:node(prefabs.Image)
		game_thumb.AnchorPoint = Vector2.new(0, 1)
		game_thumb.Position = UDim2.fromScale(0, 1)
		game_thumb.Size = UDim2.fromScale(1, 1)--:Lerp(UDim2.new(1, 0, 1, -ENTRY_SIZE), focus)
		game_thumb.ScaleType = Enum.ScaleType.Crop
		game_thumb.Image = details.thumbnails[1]
		game_thumb.ImageColor3 = Color3.fromRGB(34, 55, 80):Lerp(Color3.new(0.701961, 0.690196, 0.690196), focus)
		game_thumb.ImageTransparency = center_proximity * 2

		if is_selected then
			local stroke = pen:node(prefabs.UIStroke)
			stroke.Thickness = 2
			stroke.Color = Color3.new(0.4, 0.4, 0.4)
			stroke.Parent = game_thumb
		end

		game_thumb.Parent = entry

		if is_selected then
			entry.Position -= UDim2.fromOffset(10, 0)
			entry.BackgroundColor3 = Color3.new(0, 1, 0)
			entry.AutoButtonColor = false
		end

		total_y += entry.Size.Height.Offset + PADDING
	end

	const padded_size = (ENTRY_SIZE + PADDING)

	local scroll = (-padded_size * state.focus) + props.absolute_size.Y / 2
	scroll -= state.user_scroll
	state.scroll = math.lerp(state.scroll, scroll, props.delta_time * 10)

	return frame, state
end

return GameWheel
