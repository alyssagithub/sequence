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
const ReferencePanel = require(script.Parent.ReferencePanel)
const EmotePanel = require(script.Parent.EmotePanel)
const InsertWindow = require(script.Parent.InsertWindow)
const Icon = require(script.Parent.Parent.Components.Icon)
const Button = require(script.Parent.Parent.Components.Button)

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
				Create "UIListLayout" {
					FillDirection = Enum.FillDirection.Horizontal,
					SortOrder = Enum.SortOrder.LayoutOrder,
				},
				Create "Frame" {
					Name = "TimelineHolder",
					Size = UDim2.fromScale(1, 1),
					BackgroundTransparency = 1,
					LayoutOrder = 1,

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
							Name = "Offer",
							AnchorPoint = Vector2.new(0.5, 1),
							Position = UDim2.new(0.5, 0, 1, -16),
							AutomaticSize = Enum.AutomaticSize.XY,
							BackgroundColor3 = Theme.Colors.Panel,
							ZIndex = 32,
							Visible = function()
								return Session.Offer() ~= nil
							end,

							Create "UICorner" {CornerRadius = UDim.new(0, 6)},
							Create "UIStroke" {Color = Theme.Colors.Border},
							Create "UIPadding" {
								PaddingLeft = UDim.new(0, 12),
								PaddingRight = UDim.new(0, 12),
								PaddingTop = UDim.new(0, 8),
								PaddingBottom = UDim.new(0, 8),
							},
							Create "UIListLayout" {
								FillDirection = Enum.FillDirection.Horizontal,
								VerticalAlignment = Enum.VerticalAlignment.Center,
								Padding = UDim.new(0, 10),
								SortOrder = Enum.SortOrder.LayoutOrder,
							},
							Create "TextLabel" {
								AutomaticSize = Enum.AutomaticSize.XY,
								BackgroundTransparency = 1,
								TextColor3 = Theme.Colors.Text,
								TextSize = Settings.TextSize,
								FontFace = Font.fromEnum(Enum.Font.BuilderSans),
								LayoutOrder = 1,
								ZIndex = 33,
								Text = function()
									const Model = Session.Offer()

									return if Model then `Animate {Model.Name}?` else ""
								end,
							},
							Button {
								Text = "Yes",
								Primary = true,
								LayoutOrder = 2,
								OnClick = function()
									const Model = Session.Offer()

									Session.Offer(nil)

									if Model then
										Session.LoadRig(Model)
									end
								end,
							},
							Button {
								Text = "No",
								LayoutOrder = 3,
								OnClick = function()
									Session.Offer(nil)
								end,
							},
						},
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
								Text = "Select one or more rigs in the viewport, then press the rig button above. Any model with Motor6D or AnimationConstraint joints works: characters, doors, vehicles.",
								LayoutOrder = 3,
								ZIndex = 31,

								Create "UISizeConstraint" {MaxSize = Vector2.new(360, math.huge)},
							},
						},
					},
				},
				Create "Frame" {
					Name = "Side",
					Size = UDim2.new(0, 300, 1, 0),
					BackgroundColor3 = Theme.Colors.Panel,
					LayoutOrder = 2,
					Visible = function()
						return Session.Panel() == "Reference" or Session.Panel() == "Emote"
					end,

					Create "Frame" {
						Name = "Edge",
						Size = UDim2.new(0, 1, 1, 0),
						BackgroundColor3 = Theme.Colors.Border,
					},
					ReferencePanel(),
					EmotePanel(),
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
		Create "TextButton" {
			Name = "Modal",
			Size = UDim2.fromScale(1, 1),
			BackgroundColor3 = Color3.new(),
			BackgroundTransparency = 0.5,
			Text = "",
			AutoButtonColor = false,
			ZIndex = 79,
			Visible = function()
				return Session.Panel() == "Insert"
			end,
			Activated = function()
				Session.Panel(nil)
			end,

			Vide.show(function()
				return Session.Panel() == "Insert"
			end, function()
				return InsertWindow {
					Close = function()
						Session.Panel(nil)
					end,
				}
			end),
		},
		Overlay.Layer(),
	}
end