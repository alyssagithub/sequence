--!strict
const Vide = require(script.Parent.Parent.Parent.Packages.vide)
const Settings = require(script.Parent.Parent.Parent.Settings)
const Format = require(script.Parent.Parent.Parent.Format)
const Theme = require(script.Parent.Parent.Theme)
const Session = require(script.Parent.Parent.Parent.Editor.Session)
const Emote = require(script.Parent.Parent.Parent.Editor.Emote)
const Rig = require(script.Parent.Parent.Parent.Editor.Rig)
const Pose = require(script.Parent.Parent.Parent.Editor.Pose)
const Saver = require(script.Parent.Parent.Parent.Editor.Saver)
const Button = require(script.Parent.Parent.Components.Button)
const NumberField = require(script.Parent.Parent.Components.NumberField)
const Toggle = require(script.Parent.Parent.Components.Toggle)

const Create = Vide.create

const function Label(Text: string | () -> string, Order: number, Strong: boolean?)
	return Create "TextLabel" {
		AutomaticSize = Enum.AutomaticSize.XY,
		BackgroundTransparency = 1,
		TextColor3 = if Strong then Theme.Colors.Text else Theme.Colors.DimText,
		TextSize = if Strong then Settings.TextSize else Settings.SmallText,
		FontFace = Font.fromEnum(if Strong then Enum.Font.BuilderSansBold else Enum.Font.BuilderSans),
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = Text,
		LayoutOrder = Order,

		Create "UISizeConstraint" {MaxSize = Vector2.new(276, math.huge)},
	}
end

const function Row(Order: number, ...: Instance)
	return Create "Frame" {
		AutomaticSize = Enum.AutomaticSize.Y,
		Size = UDim2.fromScale(1, 0),
		BackgroundTransparency = 1,
		LayoutOrder = Order,

		Create "UIListLayout" {
			FillDirection = Enum.FillDirection.Horizontal,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			Padding = UDim.new(0, 6),
			SortOrder = Enum.SortOrder.LayoutOrder,
			Wraps = true,
		},
		...,
	}
end

return function()
	const ThumbnailTime = Vide.source(0)
	const Rotation = Vide.source(0)
	local Mannequin: Rig.Rig?

	const Problems = Vide.derive(function()
		const Loaded = Session.Rig()

		if not Session.EmoteChecks() or not Loaded then
			return {}
		end

		return Emote.Check(Session.Current(), Loaded)
	end)

	const function LoadMannequin(Viewport: ViewportFrame): Rig.Rig?
		const Ok, Objects = pcall(game.GetObjects, game, "rbxasset://models/Thumbnails/Mannequins/Rthro.rbxm")

		if not Ok or not Objects[1] then
			return nil
		end

		const Model = Objects[1] :: Model

		for _, Descendant in Model:GetDescendants() do
			if Descendant:IsA("BasePart") then
				Descendant.Anchored = true
				Descendant.Color = Color3.fromRGB(159, 159, 159)
				Descendant.Material = Enum.Material.SmoothPlastic
			elseif Descendant:IsA("Decal") or Descendant:IsA("SurfaceAppearance") then
				Descendant:Destroy()
			end
		end

		Model:PivotTo(CFrame.new())
		Model.Parent = Viewport

		return Rig.Load(Model)
	end

	return Create "ScrollingFrame" {
		Name = "EmotePanel",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		ScrollBarThickness = 6,
		ScrollBarImageColor3 = Theme.Colors.DimText,
		Visible = function()
			return Session.Panel() == "Emote"
		end,

		Create "UIPadding" {
			PaddingLeft = UDim.new(0, 12),
			PaddingRight = UDim.new(0, 12),
			PaddingTop = UDim.new(0, 10),
			PaddingBottom = UDim.new(0, 10),
		},
		Create "UIListLayout" {
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 8),
		},
		Label("Emote", 1, true),
		Row(2,
			Toggle {
				On = Session.EmoteChecks,
				LayoutOrder = 1,
				OnChange = Session.EmoteChecks,
			},
			Label("Check against the Marketplace emote rules", 2)
		),
		Label(function()
			if not Session.EmoteChecks() then
				return "Rules come from Studio's own upload validator: 10 seconds or shorter, standard R15 joints, nothing below 3.1 studs under the root or 25 studs away from it, no faster than 45 studs or 1750 degrees per second, only LowerTorso may move off its joint, and Cubic is the only curve style Roblox keeps."
			end

			const Count = #Problems()

			return if Count == 0 then "No problems found, this would pass the upload checks" else `{Count} problem{if Count == 1 then "" else "s"}, click one to jump to it`
		end, 3),
		Create "Frame" {
			Name = "Problems",
			AutomaticSize = Enum.AutomaticSize.Y,
			Size = UDim2.fromScale(1, 0),
			BackgroundTransparency = 1,
			LayoutOrder = 4,
			Visible = function()
				return #Problems() > 0
			end,

			Create "UIListLayout" {
				SortOrder = Enum.SortOrder.LayoutOrder,
				Padding = UDim.new(0, 4),
			},
			Vide.indexes(Problems, function(Problem, Index)
				return Create "TextButton" {
					AutomaticSize = Enum.AutomaticSize.Y,
					Size = UDim2.fromScale(1, 0),
					BackgroundColor3 = Theme.Colors.Background,
					Text = "",
					AutoButtonColor = true,
					LayoutOrder = Index,
					Activated = function()
						const Time = Problem().Time

						if Time then
							Session.Stop()
							Session.Time(math.min(Time, Session.Current().Length))
						end

						if Problem().Joint then
							Session.SelectJoint(Problem().Joint)
						end
					end,

					Create "UICorner" {CornerRadius = UDim.new(0, 4)},
					Create "UIStroke" {Color = Theme.Colors.Error},
					Create "UIPadding" {
						PaddingLeft = UDim.new(0, 8),
						PaddingRight = UDim.new(0, 8),
						PaddingTop = UDim.new(0, 4),
						PaddingBottom = UDim.new(0, 4),
					},
					Create "TextLabel" {
						AutomaticSize = Enum.AutomaticSize.Y,
						Size = UDim2.fromScale(1, 0),
						BackgroundTransparency = 1,
						TextColor3 = Theme.Colors.Text,
						TextSize = Settings.SmallText,
						FontFace = Font.fromEnum(Enum.Font.BuilderSans),
						TextWrapped = true,
						TextXAlignment = Enum.TextXAlignment.Left,
						Text = function()
							const Time = Problem().Time

							return `{if Time then `{Format.Timecode(Time, Session.FrameRate())}  ` else ""}{Problem().Text}`
						end,
					},
				}
			end),
		},
		Label("Thumbnail", 5, true),
		Label("Roblox renders the Marketplace thumbnail on its Rthro mannequin as a flat grey silhouette, from the front, at the first frame. This preview uses the same mannequin file Studio ships.", 6),
		Create "ViewportFrame" {
			Name = "Thumbnail",
			Size = UDim2.fromOffset(276, 276),
			BackgroundColor3 = Theme.Colors.Background,
			Ambient = Color3.new(1, 1, 1),
			LightColor = Color3.new(0, 0, 0),
			LayoutOrder = 7,

			Vide.action(function(Viewport: ViewportFrame)
				const Camera = Instance.new("Camera")

				Camera.FieldOfView = 40
				Camera.Parent = Viewport
				Viewport.CurrentCamera = Camera
				Mannequin = LoadMannequin(Viewport)

				Vide.effect(function()
					const Loaded = Session.Rig()
					const Shown = Mannequin

					if not Shown then
						return
					end

					const Sampled = if Loaded and Emote.IsR15(Loaded) then Pose.Sample(Session.Current(), ThumbnailTime()) else {}

					Shown.Root.CFrame = CFrame.Angles(0, math.rad(Rotation()), 0)
					Rig.Apply(Shown, Sampled)

					const Center = Shown.Model:GetBoundingBox().Position
					const Height = Shown.Model:GetExtentsSize().Y
					const Distance = (Height / 2 + 0.4) / math.tan(math.rad(20))

					Camera.CFrame = CFrame.lookAt(Center + Vector3.new(0, 0, -Distance), Center)
				end)
			end),
		},
		Row(8,
			Label("Time", 1),
			NumberField {
				Value = ThumbnailTime,
				Minimum = 0,
				Width = 64,
				Suffix = "s",
				LayoutOrder = 2,
				OnChange = ThumbnailTime,
			},
			Button {
				Text = "Use playhead",
				LayoutOrder = 3,
				OnClick = function()
					ThumbnailTime(Session.SnapTime(Session.Time()))
				end,
			},
			Label("Turn", 4),
			NumberField {
				Value = Rotation,
				Width = 60,
				Suffix = "°",
				LayoutOrder = 5,
				OnChange = Rotation,
			}
		),
		Label("Export writes a CurveAnimation with Roblox's R15 rig data plus ThumbnailTime and ThumbnailCharacterRotation values, the fields Roblox's thumbnailer reads when they are present. Publish that one for the emote.", 9),
		Button {
			Text = "Export emote CurveAnimation",
			Icon = "upload",
			Primary = true,
			LayoutOrder = 10,
			Disabled = function()
				const Loaded = Session.Rig()

				return Loaded == nil or not Emote.IsR15(Loaded)
			end,
			OnClick = function()
				const Loaded = Session.Rig()

				if not Loaded then
					return
				end

				const Made = Saver.EmoteExport(Session.Current(), Loaded, Session.FrameRate(), ThumbnailTime(), Rotation())

				Session.Say(`Wrote {Made.Name} into {Loaded.Model.Name}.AnimSaves, select it and use Save to Roblox as an animation`)
			end,
		},
	}
end