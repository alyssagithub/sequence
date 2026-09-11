--!strict
const Vide = require(script.Parent.Parent.Parent.Packages.vide)
const Theme = require(script.Parent.Parent.Theme)

const Create = Vide.create

type Props = {
	On: () -> boolean,
	OnChange: (boolean) -> (),
	LayoutOrder: number?,
}

return function(Props: Props)
	return Create "TextButton" {
		Name = "Toggle",
		Size = UDim2.fromOffset(38, 20),
		BackgroundColor3 = function()
			return if Props.On() then Theme.Colors.Accent() else Theme.Colors.Button()
		end,
		Text = "",
		AutoButtonColor = false,
		LayoutOrder = Props.LayoutOrder,
		Activated = function()
			Props.OnChange(not Props.On())
		end,

		Create "UICorner" {CornerRadius = UDim.new(1, 0)},
		Create "UIStroke" {
			Color = Theme.Colors.Border,
			Thickness = 1,
		},
		Create "Frame" {
			Name = "Knob",
			Size = UDim2.fromOffset(14, 14),
			AnchorPoint = Vector2.new(0, 0.5),
			Position = function()
				return UDim2.new(0, if Props.On() then 21 else 3, 0.5, 0)
			end,
			BackgroundColor3 = function()
				return if Props.On() then Theme.Colors.AccentText() else Theme.Colors.DimText()
			end,

			Create "UICorner" {CornerRadius = UDim.new(1, 0)},
		},
	}
end