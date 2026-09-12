--!strict
const Vide = require(script.Parent.Parent.Parent.Packages.vide)
const Settings = require(script.Parent.Parent.Parent.Settings)
const Theme = require(script.Parent.Parent.Theme)
const Icon = require(script.Parent.Icon)
const Overlay = require(script.Parent.Parent.Overlay)

const Create = Vide.create

type Props = {
	Icon: string | () -> string,
	OnClick: () -> (),
	LayoutOrder: number?,
	Visible: (() -> boolean)?,
	Size: (number | () -> number)?,
	Tooltip: (string | () -> string)?,
	Disabled: (() -> boolean)?,
	Active: (() -> boolean)?,
	Position: UDim2?,
	AnchorPoint: Vector2?,
}

return function(Props: Props)
	const Hovered = Vide.source(false)
	local Anchor: TextButton

	const function Room(): number
		return if Props.Size then Vide.read(Props.Size) else Settings.TextSize()
	end

	const function Off(): boolean
		return Props.Disabled ~= nil and Props.Disabled()
	end

	return Create "TextButton" {
		Name = "IconButton",
		Size = function()
			return UDim2.fromOffset(Room() + 12, Room() + 8)
		end,
		BackgroundColor3 = Theme.Colors.Button,
		BackgroundTransparency = function()
			return if Hovered() and not Off() then 0 else 1
		end,
		Text = "",
		AutoButtonColor = false,
		LayoutOrder = Props.LayoutOrder,
		Visible = Props.Visible,
		Position = Props.Position,
		AnchorPoint = Props.AnchorPoint,
		Activated = function()
			if Off() then
				return
			end

			Props.OnClick()
		end,
		MouseEnter = function()
			Hovered(true)

			if Anchor and Props.Tooltip then
				Overlay.ShowTip(Vide.read(Props.Tooltip), Anchor)
			end
		end,
		MouseLeave = function()
			Hovered(false)

			if Anchor then
				Overlay.HideTip(Anchor)
			end
		end,

		Vide.action(function(Object: TextButton)
			Anchor = Object

			Vide.cleanup(function()
				Overlay.HideTip(Object)
			end)
		end),

		Icon {
			Name = Props.Icon,
			Size = Props.Size,
			Position = UDim2.fromScale(0.5, 0.5),
			AnchorPoint = Vector2.new(0.5, 0.5),
			Colour = function()
				if Off() then
					return Theme.Colors.Border()
				end

				if Props.Active and Props.Active() then
					return Theme.Colors.Accent()
				end

				return if Hovered() then Theme.Colors.Text() else Theme.Colors.DimText()
			end,
		},
		Create "UICorner" {CornerRadius = UDim.new(0, 4)},
	}
end