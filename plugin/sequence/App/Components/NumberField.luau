--!strict
const Vide = require(script.Parent.Parent.Parent.Packages.vide)
const Settings = require(script.Parent.Parent.Parent.Settings)
const Theme = require(script.Parent.Parent.Theme)

const Create = Vide.create

type Props = {
	Value: () -> number,
	OnChange: (number) -> (),
	Format: ((number) -> string)?,
	Minimum: number?,
	Maximum: number?,
	Width: number?,
	Suffix: string?,
	LayoutOrder: number?,
	Disabled: (() -> boolean)?,
}

return function(Props: Props)
	const Focused = Vide.source(false)

	const function Shown(): string
		const Value = Props.Value()

		return if Props.Format then Props.Format(Value) else `{math.round(Value * 1000) / 1000}`
	end

	return Create "Frame" {
		Name = "NumberField",
		Size = function()
			return UDim2.fromOffset(Props.Width or 64, Settings.TextSize() + 10)
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
			Size = UDim2.new(1, if Props.Suffix then -24 else -12, 1, 0),
			BackgroundTransparency = 1,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = function()
				return if Props.Disabled and Props.Disabled() then Theme.Colors.DimText() else Theme.Colors.Text()
			end,
			TextSize = Settings.TextSize,
			FontFace = Font.fromEnum(Enum.Font.BuilderSans),
			ClearTextOnFocus = false,
			TextEditable = function()
				return not (Props.Disabled and Props.Disabled())
			end,
			Text = function()
				Focused()

				return Shown()
			end,
			Focused = function()
				Focused(true)
			end,
			FocusLost = function(Enter: boolean)
				Focused(false)
			end,

			Vide.action(function(Box: TextBox)
				Vide.cleanup(Box.FocusLost:Connect(function()
					const Parsed = tonumber(Box.Text:match("^%s*([%-%d%.]+)"))

					if not Parsed then
						Box.Text = Shown()

						return
					end

					const Clamped = math.clamp(Parsed, Props.Minimum or -math.huge, Props.Maximum or math.huge)

					if Clamped ~= Props.Value() then
						Props.OnChange(Clamped)
					end

					Box.Text = Shown()
				end))
			end),
		},
		if Props.Suffix then Create "TextLabel" {
			Name = "Suffix",
			Position = UDim2.new(1, -6, 0, 0),
			AnchorPoint = Vector2.new(1, 0),
			Size = UDim2.new(0, 16, 1, 0),
			BackgroundTransparency = 1,
			TextXAlignment = Enum.TextXAlignment.Right,
			TextColor3 = Theme.Colors.DimText,
			TextSize = Settings.SmallText,
			FontFace = Font.fromEnum(Enum.Font.BuilderSans),
			Text = Props.Suffix,
		} else nil,
	}
end