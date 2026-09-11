--!strict
const Vide = require(script.Parent.Parent.Parent.Packages.vide)
const Settings = require(script.Parent.Parent.Parent.Settings)
const Theme = require(script.Parent.Parent.Theme)

const Create = Vide.create

type Props = {
	Value: () -> string,
	OnChange: (string) -> (),
	Placeholder: string?,
	Width: (number | () -> number)?,
	Size: UDim2?,
	LayoutOrder: number?,
	Bold: boolean?,
}

return function(Props: Props)
	const Focused = Vide.source(false)

	return Create "Frame" {
		Name = "TextField",
		Size = function()
			if Props.Size then
				return Props.Size
			end

			return UDim2.fromOffset(if Props.Width then Vide.read(Props.Width) else 140, Settings.TextSize() + 10)
		end,
		BackgroundColor3 = Theme.Colors.Input,
		LayoutOrder = Props.LayoutOrder,

		Create "UICorner" {CornerRadius = UDim.new(0, 4)},
		Create "UIStroke" {
			Color = function()
				return if Focused() then Theme.Colors.Accent() else Theme.Colors.Border()
			end,
		},
		Create "TextBox" {
			Name = "Input",
			Position = UDim2.fromOffset(6, 0),
			Size = UDim2.new(1, -12, 1, 0),
			BackgroundTransparency = 1,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = Theme.Colors.Text,
			PlaceholderColor3 = Theme.Colors.DimText,
			PlaceholderText = Props.Placeholder or "",
			TextSize = Settings.TextSize,
			FontFace = Font.fromEnum(if Props.Bold then Enum.Font.BuilderSansBold else Enum.Font.BuilderSans),
			ClearTextOnFocus = false,
			TextTruncate = Enum.TextTruncate.AtEnd,
			Text = function()
				Focused()

				return Props.Value()
			end,
			Focused = function()
				Focused(true)
			end,

			Vide.action(function(Box: TextBox)
				Vide.cleanup(Box.FocusLost:Connect(function()
					Focused(false)

					const Trimmed = Box.Text:match("^%s*(.-)%s*$") or ""

					if Trimmed ~= Props.Value() then
						Props.OnChange(Trimmed)
					end

					Box.Text = Props.Value()
				end))
			end),
		},
	}
end