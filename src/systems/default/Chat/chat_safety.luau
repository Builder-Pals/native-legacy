const TextChatService = game:GetService("TextChatService")
const app = require("@layer/app")
const sandbox = require("@layer/sandbox")
const patching = sandbox.patching
const Composite = require("@layer/util/Composite")

print("chat safety running. praise david")

const chat_binds: { [Player]: BindableEvent } = {}

app.add_system("chat_events", function(context)
	task.spawn(function()
		local rbx_general = TextChatService:WaitForChild("TextChannels"):WaitForChild("RBXGeneral")
		assert(rbx_general:IsA("TextChannel"), "not a TextChannel")

		Composite.common.player_added:connect(function(player: Player)
			local bind = chat_binds[player] or Instance.new("BindableEvent")

			-- use TextChatService, as it receives fitlered messages.
			rbx_general.MessageReceived:Connect(function(message)
				if message.TextSource.UserId ~= player.UserId then
					return
				end

				bind:Fire(message.Text)
			end)

			chat_binds[player] = bind

			return function()
				chat_binds[player] = nil
			end
		end)
	end)
end, app.run_flags.SERVER)

app.add_patch(
	"chat_chatted_patch",
	patching.getter_patch {
		classes = { "Player" },
		keys = { "Chatted" },
		run = function(context, _key)
			local player = context.unsandboxed_object :: unknown

			assert(
				typeof(player) == "Instance" and player:IsA("Player"),
				`Expected ':' not '.' calling member function {_key}`
			)
			local signal = chat_binds[player]

			if signal == nil then
				if player:IsDescendantOf(game) then
					signal = Instance.new("BindableEvent")
					chat_binds[player] = signal
					return signal.Event
				else
					return Instance.new("BindableEvent").Event
				end
			end

			return signal.Event
		end,
	},
	app.run_flags.SERVER
)

return nil
