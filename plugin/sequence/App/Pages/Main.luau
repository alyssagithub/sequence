--!strict
const Vide = require(script.Parent.Parent.Parent.Packages.vide)
const Settings = require(script.Parent.Parent.Parent.Settings)
const Theme = require(script.Parent.Parent.Theme)
const Overlay = require(script.Parent.Parent.Overlay)
const Hotkeys = require(script.Parent.Parent.Hotkeys)
const Session = require(script.Parent.Parent.Parent.Editor.Session)
const Header = require(script.Parent.Header)
const Timeline = require(script.Parent.Timeline)
const Inspector = require(script.Parent.Inspector)
const ReferencePanel = require(script.Parent.ReferencePanel)
const EmotePanel = require(script.Parent.EmotePanel)
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

					Timeline(Header),
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

					Create "UISizeConstraint" {MaxSize = Vector2.new(300, math.huge)},

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
				Size = UDim2.new(1, 0, 0, 24),
				BackgroundTransparency = 1,
				LayoutOrder = 4,
				Visible = function()
					return Session.Rig() ~= nil and (Session.SelectedJoint() ~= nil or #Session.SelectedKeys() > 0 or Session.SelectedMarker() ~= nil or Session.Notice() ~= "")
				end,

				Inspector(),
			},
		},
		Create "TextButton" {
			Name = "OfferModal",
			Size = UDim2.fromScale(1, 1),
			BackgroundColor3 = Color3.new(),
			BackgroundTransparency = 0.45,
			Text = "",
			AutoButtonColor = false,
			ZIndex = 70,
			Visible = function()
				return Session.Offer() ~= nil
			end,
			Activated = function()
				Session.Offer(nil)
			end,

			Create "Frame" {
				Name = "Offer",
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, 0.5),
				AutomaticSize = Enum.AutomaticSize.XY,
				BackgroundColor3 = Theme.Colors.Panel,
				ZIndex = 71,

				Create "UICorner" {CornerRadius = UDim.new(0, 8)},
				Create "UIStroke" {
					Color = Theme.Colors.Accent,
					Thickness = 2,
				},
				Create "UIPadding" {
					PaddingLeft = UDim.new(0, 18),
					PaddingRight = UDim.new(0, 18),
					PaddingTop = UDim.new(0, 10),
					PaddingBottom = UDim.new(0, 10),
				},
				Create "UIListLayout" {
					FillDirection = Enum.FillDirection.Horizontal,
					VerticalAlignment = Enum.VerticalAlignment.Center,
					Padding = UDim.new(0, 14),
					SortOrder = Enum.SortOrder.LayoutOrder,
				},
				Icon {
					Name = "person-standing",
					Size = 22,
					Colour = Theme.Colors.Accent,
					LayoutOrder = 1,
				},
				Create "TextLabel" {
					AutomaticSize = Enum.AutomaticSize.XY,
					BackgroundTransparency = 1,
					TextColor3 = Theme.Colors.Text,
					TextSize = function()
						return Settings.TextSize() + 2
					end,
					FontFace = Font.fromEnum(Enum.Font.BuilderSansBold),
					LayoutOrder = 2,
					ZIndex = 72,
					Text = function()
						const Model = Session.Offer()

						return if Model then `Animate {Model.Name}?` else ""
					end,
				},
				Button {
					Text = "Yes",
					Primary = true,
					LayoutOrder = 3,
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
					LayoutOrder = 4,
					OnClick = function()
						Session.Offer(nil)
					end,
				},
			},
		},
		Overlay.Layer(),
	}
end