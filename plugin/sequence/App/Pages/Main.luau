--!strict
const Vide = require(script.Parent.Parent.Parent.Packages.vide)
const Settings = require(script.Parent.Parent.Parent.Settings)
const Theme = require(script.Parent.Parent.Theme)
const Overlay = require(script.Parent.Parent.Overlay)
const Hotkeys = require(script.Parent.Parent.Hotkeys)
const Session = require(script.Parent.Parent.Parent.Editor.Session)
const TopBar = require(script.Parent.TopBar)
const Transport = require(script.Parent.Transport)
const Timeline = require(script.Parent.Timeline)
const Inspector = require(script.Parent.Inspector)
const Icon = require(script.Parent.Parent.Components.Icon)

const Create = Vide.create

return function()
	return Create "Frame" {
		Name = "MainPage",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Theme.Colors.Background,
		BorderSizePixel = 0,
		InputBegan = Hotkeys.Handle,

		Create "Frame" {
			Name = "Column",
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,

			Create "UIListLayout" {SortOrder = Enum.SortOrder.LayoutOrder},
			Create "Frame" {
				Name = "Top",
				Size = UDim2.new(1, 0, 0, 36),
				BackgroundTransparency = 1,
				LayoutOrder = 1,

				TopBar(),
			},
			Create "Frame" {
				Name = "Middle",
				Size = UDim2.new(1, 0, 0, 36),
				BackgroundTransparency = 1,
				LayoutOrder = 2,

				Transport(),
			},
			Create "Frame" {
				Name = "Body",
				Size = UDim2.fromScale(1, 1),
				BackgroundTransparency = 1,
				LayoutOrder = 3,

				Create "UIFlexItem" {FlexMode = Enum.UIFlexMode.Fill},

				Timeline(),
				Create "Frame" {
					Name = "Welcome",
					Size = UDim2.fromScale(1, 1),
					BackgroundColor3 = Theme.Colors.Background,
					ZIndex = 30,
					Visible = function()
						return Session.Rig() == nil
					end,

					Create "Frame" {
						Name = "Card",
						AnchorPoint = Vector2.new(0.5, 0.5),
						Position = UDim2.fromScale(0.5, 0.5),
						AutomaticSize = Enum.AutomaticSize.XY,
						BackgroundTransparency = 1,
						ZIndex = 31,

						Create "UIListLayout" {
							HorizontalAlignment = Enum.HorizontalAlignment.Center,
							Padding = UDim.new(0, 8),
							SortOrder = Enum.SortOrder.LayoutOrder,
						},
						Icon {
							Name = "person-standing",
							Size = 40,
							LayoutOrder = 1,
						},
						Create "TextLabel" {
							AutomaticSize = Enum.AutomaticSize.XY,
							BackgroundTransparency = 1,
							TextColor3 = Theme.Colors.Text,
							TextSize = function()
								return Settings.TextSize() + 4
							end,
							FontFace = Font.fromEnum(Enum.Font.BuilderSansBold),
							Text = "Nothing to animate yet",
							LayoutOrder = 2,
							ZIndex = 31,
						},
						Create "TextLabel" {
							AutomaticSize = Enum.AutomaticSize.XY,
							BackgroundTransparency = 1,
							TextColor3 = Theme.Colors.DimText,
							TextSize = Settings.TextSize,
							FontFace = Font.fromEnum(Enum.Font.BuilderSans),
							TextWrapped = true,
							Text = "Select a rig in the viewport, then press the rig button above. Any model with Motor6D joints works: characters, doors, vehicles.",
							LayoutOrder = 3,
							ZIndex = 31,

							Create "UISizeConstraint" {MaxSize = Vector2.new(360, math.huge)},
						},
					},
				},
			},
			Create "Frame" {
				Name = "Bottom",
				Size = UDim2.new(1, 0, 0, 40),
				BackgroundTransparency = 1,
				LayoutOrder = 4,

				Inspector(),
			},
		},
		Overlay.Layer(),
	}
end