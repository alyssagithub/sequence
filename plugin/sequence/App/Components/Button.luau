--!strict
const Vide = require(script.Parent.Parent.Parent.Packages.vide)
const Settings = require(script.Parent.Parent.Parent.Settings)
const Theme = require(script.Parent.Parent.Theme)
const Icon = require(script.Parent.Icon)

const Create = Vide.create

type Props = {
	Text: string | () -> string,
	OnClick: () -> (),
	Icon: string?,
	Primary: boolean?,
	Danger: boolean?,
	LayoutOrder: number?,
	Visible: (() -> boolean)?,
	Disabled: (() -> boolean)?,
}

return function(Props: Props)
	const function Off(): boolean
		return Props.Disabled ~= nil and Props.Disabled()
	end

	const function Foreground(): Color3
		if Off() then
			return Theme.Colors.DimText()
		end

		return if Props.Danger or Props.Primary then Theme.Colors.AccentText() else Theme.Colors.ButtonText()
	end

	return Create "TextButton" {
		Name = "Button",
		AutomaticSize = Enum.AutomaticSize.XY,
		Size = UDim2.fromScale(0, 0),
		BackgroundColor3 = function()
			if Off() then
				return Theme.Colors.Button()
			end

			return if Props.Danger then Theme.Colors.Error() elseif Props.Primary then Theme.Colors.Accent() else Theme.Colors.Button()
		end,
		Text = "",
		AutoButtonColor = true,
		LayoutOrder = Props.LayoutOrder,
		Visible = Props.Visible,
		Activated = function()
			if Off() then
				return
			end

			Props.OnClick()
		end,

		Create "UICorner" {CornerRadius = UDim.new(0, 4)},
		Create "UIPadding" {
			PaddingLeft = UDim.new(0, 10),
			PaddingRight = UDim.new(0, 10),
			PaddingTop = UDim.new(0, 5),
			PaddingBottom = UDim.new(0, 5),
		},
		Create "UIListLayout" {
			FillDirection = Enum.FillDirection.Horizontal,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			Padding = UDim.new(0, 6),
		},
		if Props.Icon then Icon {
			Name = Props.Icon,
			Colour = Foreground,
			LayoutOrder = 1,
		} else nil,
		Create "TextLabel" {
			AutomaticSize = Enum.AutomaticSize.XY,
			BackgroundTransparency = 1,
			TextColor3 = Foreground,
			Text = Props.Text,
			TextSize = Settings.TextSize,
			FontFace = Font.fromEnum(Enum.Font.BuilderSansMedium),
			LayoutOrder = 2,
		},
	}
end