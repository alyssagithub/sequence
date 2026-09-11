--!strict
const Vide = require(script.Parent.Parent.Parent.Packages.vide)
const Settings = require(script.Parent.Parent.Parent.Settings)
const Theme = require(script.Parent.Parent.Theme)
const Icon = require(script.Parent.Icon)

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
	const Below = Vide.source(true)
	const Side = Vide.source(0.5)
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

			if not Anchor then
				return
			end

			const Screen = Anchor:FindFirstAncestorWhichIsA("LayerCollector")
			const Bottom = if Screen then Screen.AbsolutePosition.Y + Screen.AbsoluteSize.Y else math.huge
			const Right = if Screen then Screen.AbsolutePosition.X + Screen.AbsoluteSize.X else math.huge
			const Left = if Screen then Screen.AbsolutePosition.X else -math.huge
			const Middle = Anchor.AbsolutePosition.X + Anchor.AbsoluteSize.X / 2

			Below(Bottom - (Anchor.AbsolutePosition.Y + Anchor.AbsoluteSize.Y) > 30)

			if Right - Middle < 90 then
				Side(1)
			elseif Middle - Left < 90 then
				Side(0)
			else
				Side(0.5)
			end
		end,
		MouseLeave = function()
			Hovered(false)
		end,

		Vide.action(function(Object: TextButton)
			Anchor = Object
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
		Create "TextLabel" {
			Name = "Tooltip",
			AnchorPoint = function()
				return Vector2.new(Side(), if Below() then 0 else 1)
			end,
			Position = function()
				return UDim2.new(Side(), 0, if Below() then 1 else 0, if Below() then 4 else -4)
			end,
			AutomaticSize = Enum.AutomaticSize.XY,
			BackgroundColor3 = Theme.Colors.Background,
			TextColor3 = Theme.Colors.Text,
			TextSize = Settings.SmallText,
			FontFace = Font.fromEnum(Enum.Font.BuilderSans),
			ZIndex = 60,
			Visible = function()
				return Hovered() and Props.Tooltip ~= nil
			end,
			Text = function()
				return if Props.Tooltip then Vide.read(Props.Tooltip) else ""
			end,

			Create "UICorner" {CornerRadius = UDim.new(0, 4)},
			Create "UIStroke" {Color = Theme.Colors.Border},
			Create "UIPadding" {
				PaddingLeft = UDim.new(0, 6),
				PaddingRight = UDim.new(0, 6),
				PaddingTop = UDim.new(0, 2),
				PaddingBottom = UDim.new(0, 2),
			},
		},
		Create "UICorner" {CornerRadius = UDim.new(0, 4)},
	}
end