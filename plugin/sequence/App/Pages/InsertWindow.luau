--!strict
const Vide = require(script.Parent.Parent.Parent.Packages.vide)
const Settings = require(script.Parent.Parent.Parent.Settings)
const Theme = require(script.Parent.Parent.Theme)
const Session = require(script.Parent.Parent.Parent.Editor.Session)
const Inserter = require(script.Parent.Parent.Parent.Editor.Inserter)
const Vow = require(script.Parent.Parent.Parent.Packages.vow)
const Button = require(script.Parent.Parent.Components.Button)
const IconButton = require(script.Parent.Parent.Components.IconButton)
const TextField = require(script.Parent.Parent.Components.TextField)
const Toggle = require(script.Parent.Parent.Components.Toggle)

const Create = Vide.create

type Tab = "Account" | "Presets"

const function Label(Text: string | () -> string, Order: number, Strong: boolean?)
	return Create "TextLabel" {
		AutomaticSize = Enum.AutomaticSize.XY,
		BackgroundTransparency = 1,
		TextColor3 = if Strong then Theme.Colors.Text else Theme.Colors.DimText,
		TextSize = Settings.TextSize,
		FontFace = Font.fromEnum(if Strong then Enum.Font.BuilderSansMedium else Enum.Font.BuilderSans),
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = Text,
		LayoutOrder = Order,
	}
end

const function Radio(Text: string, Order: number, On: () -> boolean, Pick: () -> ())
	return Create "TextButton" {
		AutomaticSize = Enum.AutomaticSize.XY,
		BackgroundTransparency = 1,
		Text = "",
		LayoutOrder = Order,
		Activated = Pick,

		Create "UIListLayout" {
			FillDirection = Enum.FillDirection.Horizontal,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			Padding = UDim.new(0, 8),
		},
		Create "Frame" {
			Size = UDim2.fromOffset(16, 16),
			BackgroundColor3 = Theme.Colors.Input,
			LayoutOrder = 1,

			Create "UICorner" {CornerRadius = UDim.new(1, 0)},
			Create "UIStroke" {
				Color = function()
					return if On() then Theme.Colors.Accent() else Theme.Colors.Border()
				end,
				Thickness = 1.5,
			},
			Create "Frame" {
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, 0.5),
				Size = UDim2.fromOffset(8, 8),
				BackgroundColor3 = Theme.Colors.Accent,
				Visible = On,

				Create "UICorner" {CornerRadius = UDim.new(1, 0)},
			},
		},
		Label(Text, 2, true),
	}
end

const function Preview(Model: () -> Model?, Turn: () -> number)
	return Create "ViewportFrame" {
		Name = "Preview",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Theme.Colors.Background,
		Ambient = Color3.fromRGB(140, 140, 150),
		LightColor = Color3.fromRGB(255, 250, 240),
		LightDirection = Vector3.new(-1, -1.2, -2),

		Vide.action(function(Viewport: ViewportFrame)
			const Camera = Instance.new("Camera")

			Camera.FieldOfView = 35
			Camera.Parent = Viewport
			Viewport.CurrentCamera = Camera

			Vide.effect(function()
				const Shown = Model()

				for _, Child in Viewport:GetChildren() do
					if Child:IsA("Model") then
						Child:Destroy()
					end
				end

				if not Shown then
					return
				end

				const Copy = Shown:Clone()

				Copy:PivotTo(CFrame.Angles(0, math.rad(Turn()), 0))
				Copy.Parent = Viewport

				const Center = Copy:GetBoundingBox().Position
				const Height = Copy:GetExtentsSize().Y
				const Distance = (Height / 2 + 0.6) / math.tan(math.rad(17.5))

				Camera.CFrame = CFrame.lookAt(Center + Vector3.new(0, 0.2, -Distance), Center)
			end)
		end),
	}
end

return function(Props: {Close: () -> ()})
	const Tab = Vide.source("Account" :: Tab)
	const Turn = Vide.source(0)
	local Pending: {Vow.Vow}?

	const function Release()
		if not Pending then
			return
		end

		for _, Handle in Pending do
			if Vow.isAlive(Handle) then
				Vow.destroy(Handle)
			end
		end

		Pending = nil
	end

	const function Settle(Model: Model?, Failed: string?)
		const Old = Inserter.Preview()

		if Old then
			Old:Destroy()
		end

		Inserter.Preview(Model)
		Inserter.Notice(Failed or "")
		Inserter.Building(false)
		task.defer(Release)
	end

	const function Rebuild()
		Release()
		Inserter.Building(true)

		const Started = Inserter.BuildPreview()

		Pending = {Started, Vow.andThen(Started, function(Model: Model)
			Settle(Model, nil)
		end, function(Failed: string)
			Settle(nil, Failed)
		end)}
	end

	Vide.cleanup(Release)

	if not Inserter.Preview() then
		Rebuild()
	end

	const function Insert(Make: (() -> Model?)?)
		task.spawn(function()
			local Model: Model?

			if Make then
				Inserter.Building(true)
				Model = Make()
				Inserter.Building(false)
			else
				const Built = Inserter.Preview()

				Model = if Built then Built:Clone() else nil
			end

			if not Model then
				Session.Say("Nothing to insert yet")

				return
			end

			Inserter.Place(Model)

			if Session.LoadRig(Model) then
				Session.Say(`{Model.Name} is in the scene and loaded`)
			else
				Session.Say(`{Model.Name} was inserted but has no joints to animate`)
			end

			Props.Close()
		end)
	end

	const function TabButton(Name: Tab, Order: number)
		return Create "TextButton" {
			Size = UDim2.new(1 / 3, 0, 1, 0),
			BackgroundTransparency = 1,
			TextColor3 = function()
				return if Tab() == Name then Theme.Colors.Text() else Theme.Colors.DimText()
			end,
			TextSize = Settings.TextSize,
			FontFace = Font.fromEnum(Enum.Font.BuilderSansMedium),
			Text = Name,
			LayoutOrder = Order,
			Activated = function()
				Tab(Name)
			end,

			Create "Frame" {
				Position = UDim2.new(0, 0, 1, -2),
				Size = UDim2.new(1, 0, 0, 2),
				BackgroundColor3 = Theme.Colors.Accent,
				Visible = function()
					return Tab() == Name
				end,
			},
		}
	end

	const function PresetCard(Preset: Inserter.Preset, Order: number)
		const Built = Vide.source(nil :: Model?)

		task.spawn(function()
			Built(Preset.Build())
		end)

		return Create "TextButton" {
			Size = UDim2.new(0.5, -4, 0, 150),
			BackgroundColor3 = Theme.Colors.Background,
			Text = "",
			AutoButtonColor = true,
			LayoutOrder = Order,
			Activated = function()
				Insert(Preset.Build)
			end,

			Create "UICorner" {CornerRadius = UDim.new(0, 4)},
			Create "UIStroke" {Color = Theme.Colors.Border},
			Create "TextLabel" {
				Size = UDim2.new(1, 0, 0, 22),
				BackgroundTransparency = 1,
				TextColor3 = Theme.Colors.Text,
				TextSize = Settings.TextSize,
				FontFace = Font.fromEnum(Enum.Font.BuilderSansMedium),
				Text = Preset.Name,
			},
			Create "Frame" {
				Position = UDim2.fromOffset(0, 22),
				Size = UDim2.new(1, 0, 1, -22),
				BackgroundTransparency = 1,

				Preview(Built, function()
					return 0
				end),
			},
		}
	end

	return Create "Frame" {
		Name = "InsertWindow",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(520, 300),
		BackgroundColor3 = Theme.Colors.Panel,
		ZIndex = 80,

		Create "UICorner" {CornerRadius = UDim.new(0, 6)},
		Create "UIStroke" {Color = Theme.Colors.Border},
		Create "Frame" {
			Name = "Title",
			Size = UDim2.new(1, 0, 0, 30),
			BackgroundColor3 = Theme.Colors.Accent,
			ZIndex = 81,

			Create "UICorner" {CornerRadius = UDim.new(0, 6)},
			Create "Frame" {
				Position = UDim2.new(0, 0, 1, -6),
				Size = UDim2.new(1, 0, 0, 6),
				BackgroundColor3 = Theme.Colors.Accent,
				ZIndex = 81,
			},
			Create "TextLabel" {
				Position = UDim2.fromOffset(10, 0),
				Size = UDim2.new(1, -40, 1, 0),
				BackgroundTransparency = 1,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextColor3 = Theme.Colors.AccentText,
				TextSize = Settings.TextSize,
				FontFace = Font.fromEnum(Enum.Font.BuilderSansBold),
				Text = "Insert a character",
				ZIndex = 82,
			},
			IconButton {
				Icon = "x",
				Tooltip = "Close",
				Position = UDim2.new(1, -4, 0.5, 0),
				AnchorPoint = Vector2.new(1, 0.5),
				OnClick = Props.Close,
			},
		},
		Create "Frame" {
			Name = "Left",
			Position = UDim2.fromOffset(10, 40),
			Size = UDim2.new(0, 200, 1, -50),
			BackgroundColor3 = Theme.Colors.Background,
			ZIndex = 81,

			Create "UICorner" {CornerRadius = UDim.new(0, 4)},
			Create "UIStroke" {Color = Theme.Colors.Border},
			Create "Frame" {
				Position = UDim2.fromOffset(24, 0),
				Size = UDim2.new(1, -48, 1, -22),
				BackgroundTransparency = 1,

				Preview(Inserter.Preview, Turn),
			},
			IconButton {
				Icon = "chevron-left",
				Tooltip = "Turn",
				Position = UDim2.new(0, 2, 0.5, 0),
				AnchorPoint = Vector2.new(0, 0.5),
				OnClick = function()
					Turn(Turn() - 45)
				end,
			},
			IconButton {
				Icon = "chevron-right",
				Tooltip = "Turn",
				Position = UDim2.new(1, -2, 0.5, 0),
				AnchorPoint = Vector2.new(1, 0.5),
				OnClick = function()
					Turn(Turn() + 45)
				end,
			},
			Create "TextLabel" {
				Position = UDim2.new(0, 0, 1, -22),
				Size = UDim2.new(1, 0, 0, 22),
				BackgroundTransparency = 1,
				TextColor3 = Theme.Colors.Accent,
				TextSize = Settings.SmallText,
				FontFace = Font.fromEnum(Enum.Font.BuilderSans),
				Text = function()
					if Inserter.Building() then
						return "Building..."
					end

					const Notice = Inserter.Notice()

					if Notice ~= "" then
						return Notice
					end

					const Shown = Inserter.Preview()

					return if Shown then Shown.Name else ""
				end,
			},
		},
		Create "Frame" {
			Name = "Right",
			Position = UDim2.fromOffset(220, 40),
			Size = UDim2.new(1, -230, 1, -50),
			BackgroundColor3 = Theme.Colors.Background,
			ZIndex = 81,

			Create "UICorner" {CornerRadius = UDim.new(0, 4)},
			Create "UIStroke" {Color = Theme.Colors.Border},
			Create "Frame" {
				Name = "Tabs",
				Size = UDim2.new(1, 0, 0, 30),
				BackgroundTransparency = 1,

				Create "UIListLayout" {
					FillDirection = Enum.FillDirection.Horizontal,
					SortOrder = Enum.SortOrder.LayoutOrder,
				},
				TabButton("Account", 1),
				TabButton("Presets", 2),
			},
			Create "Frame" {
				Name = "Account",
				Position = UDim2.fromOffset(12, 38),
				Size = UDim2.new(1, -24, 1, -80),
				BackgroundTransparency = 1,
				Visible = function()
					return Tab() == "Account"
				end,

				Create "UIListLayout" {
					SortOrder = Enum.SortOrder.LayoutOrder,
					Padding = UDim.new(0, 6),
				},
				Create "Frame" {
					Size = UDim2.new(1, 0, 0, 26),
					BackgroundTransparency = 1,
					LayoutOrder = 1,

					Create "UIListLayout" {
						FillDirection = Enum.FillDirection.Horizontal,
						VerticalAlignment = Enum.VerticalAlignment.Center,
						Padding = UDim.new(0, 8),
					},
					Label("Account name or id", 1),
					TextField {
						Value = Inserter.Account,
						Placeholder = "yours when empty",
						Width = 130,
						LayoutOrder = 2,
						OnChange = function(Text: string)
							Inserter.Account(Text)
							Rebuild()
						end,
					},
				},
				Create "Frame" {
					Size = UDim2.new(1, 0, 0, 22),
					BackgroundTransparency = 1,
					LayoutOrder = 2,

					Create "UIListLayout" {
						FillDirection = Enum.FillDirection.Horizontal,
						VerticalAlignment = Enum.VerticalAlignment.Center,
						Padding = UDim.new(0, 8),
					},
					Toggle {
						On = Inserter.DefaultBody,
						LayoutOrder = 1,
						OnChange = function(On: boolean)
							Inserter.DefaultBody(On)
							Rebuild()
						end,
					},
					Label("Default body, keep only the rig type", 2),
				},
				Vide.indexes(function()
					return Inserter.Bodies
				end, function(Body, Index)
					return Radio(Body(), 2 + Index, function()
						return Inserter.Body() == Body()
					end, function()
						Inserter.Body(Body())
						Rebuild()
					end)
				end),
			},
			Create "ScrollingFrame" {
				Name = "Presets",
				Position = UDim2.fromOffset(12, 38),
				Size = UDim2.new(1, -24, 1, -46),
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				AutomaticCanvasSize = Enum.AutomaticSize.Y,
				CanvasSize = UDim2.new(),
				ScrollBarThickness = 4,
				ScrollBarImageColor3 = Theme.Colors.DimText,
				Visible = function()
					return Tab() == "Presets"
				end,

				Create "UIGridLayout" {
					CellSize = UDim2.new(0.5, -4, 0, 150),
					CellPadding = UDim2.fromOffset(8, 8),
					SortOrder = Enum.SortOrder.LayoutOrder,
				},
				Vide.indexes(function()
					return Inserter.Presets
				end, function(Preset, Index)
					return PresetCard(Preset(), Index)
				end),
			},
			Create "Frame" {
				Name = "Foot",
				Position = UDim2.new(0, 12, 1, -38),
				Size = UDim2.new(1, -24, 0, 30),
				BackgroundTransparency = 1,
				Visible = function()
					return Tab() ~= "Presets"
				end,

				Button {
					Text = "Insert",
					Icon = "plus",
					Primary = true,
					Disabled = function()
						return Inserter.Building() or Inserter.Preview() == nil
					end,
					OnClick = function()
						Insert(nil)
					end,
				},
			},
		},
	}
end