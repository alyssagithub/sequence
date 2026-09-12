--!strict
const Vide = require(script.Parent.Parent.Packages.vide)
const Settings = require(script.Parent.Parent.Settings)
const Theme = require(script.Parent.Theme)

const Create = Vide.create

export type Entry = {
	Label: string,
	Action: (() -> ())?,
	Checked: boolean?,
	Divider: boolean?,
	Disabled: boolean?,
}

const Overlay = {
	Open = Vide.source(nil :: {Position: Vector2, Width: number, Entries: {Entry}}?),
	Tip = Vide.source(nil :: {Text: string, Anchor: GuiObject}?),
}

local Root: GuiObject?

function Overlay.Close()
	Overlay.Open(nil)
end

function Overlay.Menu(Anchor: GuiObject, Entries: {Entry}, Width: number?)
	const Origin = if Root then Root.AbsolutePosition else Vector2.zero

	Overlay.Open({
		Position = Anchor.AbsolutePosition - Origin + Vector2.new(0, Anchor.AbsoluteSize.Y + 2),
		Width = math.max(Width or 0, Anchor.AbsoluteSize.X),
		Entries = Entries,
	})
end

function Overlay.MenuAt(Position: Vector2, Entries: {Entry}, Width: number?)
	const Origin = if Root then Root.AbsolutePosition else Vector2.zero

	Overlay.Open({
		Position = Position - Origin,
		Width = Width or 160,
		Entries = Entries,
	})
end

function Overlay.ShowTip(Text: string, Anchor: GuiObject)
	const Current = Overlay.Tip()

	if Current and Current.Anchor == Anchor and Current.Text == Text then
		return
	end

	Overlay.Tip({Text = Text, Anchor = Anchor})
end

function Overlay.HideTip(Anchor: GuiObject)
	const Current = Overlay.Tip()

	if Current and Current.Anchor == Anchor then
		Overlay.Tip(nil)
	end
end

function Overlay.Layer()
	return Create "Frame" {
		Name = "Overlay",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		ZIndex = 100,

		Vide.action(function(Object: Frame)
			Root = Object
		end),

		Create "TextButton" {
			Name = "Shade",
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			Text = "",
			AutoButtonColor = false,
			ZIndex = 100,
			Visible = function()
				return Overlay.Open() ~= nil
			end,
			Activated = Overlay.Close,
			MouseButton2Click = Overlay.Close,
		},

		Vide.show(Overlay.Tip, function(Tip)
			return Create "TextLabel" {
				Name = "Tooltip",
				AutomaticSize = Enum.AutomaticSize.XY,
				BackgroundColor3 = Theme.Colors.Background,
				TextColor3 = Theme.Colors.Text,
				TextSize = Settings.SmallText,
				FontFace = Font.fromEnum(Enum.Font.BuilderSans),
				ZIndex = 110,
				Interactable = false,
				Text = function()
					return Tip().Text
				end,
				Vide.action(function(Label: TextLabel)
					const function Place()
						const Current = Tip()
						const Origin = if Root then Root.AbsolutePosition else Vector2.zero
						const Room = if Root then Root.AbsoluteSize else Vector2.new(1000, 1000)
						const Anchor = Current.Anchor
						const Width = Label.AbsoluteSize.X
						const Height = Label.AbsoluteSize.Y
						const Left = Anchor.AbsolutePosition.X - Origin.X
						const Top = Anchor.AbsolutePosition.Y - Origin.Y

						if Left < 60 then
							Label.Position = UDim2.fromOffset(Left + Anchor.AbsoluteSize.X + 6, math.clamp(Top + Anchor.AbsoluteSize.Y / 2 - Height / 2, 4, math.max(4, Room.Y - Height - 4)))

							return
						end

						const Middle = Left + Anchor.AbsoluteSize.X / 2
						const Below = Top + Anchor.AbsoluteSize.Y
						const X = math.clamp(Middle - Width / 2, 4, math.max(4, Room.X - Width - 4))
						const Y = if Below + Height + 6 > Room.Y then Top - Height - 4 else Below + 4

						Label.Position = UDim2.fromOffset(X, Y)
					end

					Vide.effect(function()
						Tip()
						Place()
						task.defer(Place)
					end)
				end),

				Create "UICorner" {CornerRadius = UDim.new(0, 4)},
				Create "UIStroke" {Color = Theme.Colors.Border},
				Create "UIPadding" {
					PaddingLeft = UDim.new(0, 6),
					PaddingRight = UDim.new(0, 6),
					PaddingTop = UDim.new(0, 2),
					PaddingBottom = UDim.new(0, 2),
				},
			}
		end),

		Vide.show(Overlay.Open, function(Open)
			return Create "Frame" {
				Name = "Menu",
				Position = function()
					const Where = Open().Position
					const Room = if Root then Root.AbsoluteSize else Vector2.new(1000, 1000)
					const Height = #Open().Entries * (Settings.TextSize() + 12) + 8

					return UDim2.fromOffset(math.max(0, math.min(Where.X, Room.X - Open().Width)), if Where.Y + Height > Room.Y then math.max(0, Where.Y - Height - 26) else Where.Y)
				end,
				AutomaticSize = Enum.AutomaticSize.Y,
				Size = function()
					return UDim2.fromOffset(Open().Width, 0)
				end,
				BackgroundColor3 = Theme.Colors.Background,
				ZIndex = 101,

				Create "UICorner" {CornerRadius = UDim.new(0, 4)},
				Create "UIStroke" {Color = Theme.Colors.Border},
				Create "UIPadding" {
					PaddingTop = UDim.new(0, 4),
					PaddingBottom = UDim.new(0, 4),
				},
				Create "UIListLayout" {SortOrder = Enum.SortOrder.LayoutOrder},

				Vide.indexes(function()
					return Open().Entries
				end, function(Entry, Index)
					const Hovered = Vide.source(false)

					return Create "TextButton" {
						Name = "Entry",
						Size = function()
							return UDim2.new(1, 0, 0, if Entry().Divider then 5 else Settings.TextSize() + 12)
						end,
						BackgroundColor3 = Theme.Colors.Button,
						BackgroundTransparency = function()
							return if Hovered() and not Entry().Divider and not Entry().Disabled then 0 else 1
						end,
						Text = "",
						AutoButtonColor = false,
						LayoutOrder = Index,
						ZIndex = 102,
						MouseEnter = function()
							Hovered(true)
						end,
						MouseLeave = function()
							Hovered(false)
						end,
						Activated = function()
							const Chosen = Entry()

							if Chosen.Divider or Chosen.Disabled then
								return
							end

							Overlay.Close()

							if Chosen.Action then
								Chosen.Action()
							end
						end,

						Create "Frame" {
							Name = "Line",
							Position = UDim2.new(0, 8, 0.5, 0),
							Size = UDim2.new(1, -16, 0, 1),
							BackgroundColor3 = Theme.Colors.Border,
							ZIndex = 103,
							Visible = function()
								return Entry().Divider == true
							end,
						},
						Create "TextLabel" {
							Name = "Label",
							Position = UDim2.fromOffset(26, 0),
							Size = UDim2.new(1, -30, 1, 0),
							BackgroundTransparency = 1,
							TextXAlignment = Enum.TextXAlignment.Left,
							TextColor3 = function()
								return if Entry().Disabled then Theme.Colors.DimText() else Theme.Colors.Text()
							end,
							TextSize = Settings.TextSize,
							FontFace = Font.fromEnum(Enum.Font.BuilderSans),
							ZIndex = 103,
							Text = function()
								return Entry().Label
							end,
							Visible = function()
								return not Entry().Divider
							end,
						},
						Create "TextLabel" {
							Name = "Check",
							Position = UDim2.fromOffset(8, 0),
							Size = UDim2.new(0, 16, 1, 0),
							BackgroundTransparency = 1,
							TextColor3 = Theme.Colors.Accent,
							TextSize = Settings.TextSize,
							FontFace = Font.fromEnum(Enum.Font.BuilderSansBold),
							ZIndex = 103,
							Text = "•",
							Visible = function()
								return Entry().Checked == true
							end,
						},
					}
				end),
			}
		end),
	}
end

return Overlay