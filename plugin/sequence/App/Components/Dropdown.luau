--!strict
const Vide = require(script.Parent.Parent.Parent.Packages.vide)
const Settings = require(script.Parent.Parent.Parent.Settings)
const Theme = require(script.Parent.Parent.Theme)
const Overlay = require(script.Parent.Parent.Overlay)
const Icon = require(script.Parent.Icon)

const Create = Vide.create

type Props = {
	Options: {string} | () -> {string},
	Chosen: () -> string,
	OnChange: (string) -> (),
	Labels: {[string]: string}?,
	Width: number?,
	LayoutOrder: number?,
	Disabled: (() -> boolean)?,
}

return function(Props: Props)
	local Anchor: TextButton

	const function Label(Value: string): string
		return if Props.Labels and Props.Labels[Value] then Props.Labels[Value] else Value
	end

	return Create "TextButton" {
		Name = "Dropdown",
		Size = function()
			return UDim2.fromOffset(Props.Width or 110, Settings.TextSize() + 10)
		end,
		BackgroundColor3 = Theme.Colors.Input,
		Text = "",
		AutoButtonColor = false,
		LayoutOrder = Props.LayoutOrder,
		Activated = function()
			if Props.Disabled and Props.Disabled() then
				return
			end

			const Entries = {}

			for _, Option in Vide.read(Props.Options) do
				table.insert(Entries, {
					Label = Label(Option),
					Checked = Option == Props.Chosen(),
					Action = function()
						Props.OnChange(Option)
					end,
				})
			end

			Overlay.Menu(Anchor, Entries)
		end,

		Vide.action(function(Object: TextButton)
			Anchor = Object
		end),

		Create "UICorner" {CornerRadius = UDim.new(0, 4)},
		Create "UIStroke" {Color = Theme.Colors.Border},
		Create "TextLabel" {
			Name = "Value",
			Position = UDim2.fromOffset(8, 0),
			Size = UDim2.new(1, -28, 1, 0),
			BackgroundTransparency = 1,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextTruncate = Enum.TextTruncate.AtEnd,
			TextColor3 = function()
				return if Props.Disabled and Props.Disabled() then Theme.Colors.DimText() else Theme.Colors.Text()
			end,
			TextSize = Settings.TextSize,
			FontFace = Font.fromEnum(Enum.Font.BuilderSans),
			Text = function()
				return Label(Props.Chosen())
			end,
		},
		Icon {
			Name = "chevron-down",
			Position = UDim2.new(1, -6, 0.5, 0),
			AnchorPoint = Vector2.new(1, 0.5),
		},
	}
end