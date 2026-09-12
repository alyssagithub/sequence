--!strict
const Vide = require(script.Parent.Parent.Parent.Packages.vide)
const Settings = require(script.Parent.Parent.Parent.Settings)
const Theme = require(script.Parent.Parent.Theme)
const Session = require(script.Parent.Parent.Parent.Editor.Session)
const Reference = require(script.Parent.Parent.Parent.Editor.Reference)
const Button = require(script.Parent.Parent.Components.Button)
const IconButton = require(script.Parent.Parent.Components.IconButton)
const Dropdown = require(script.Parent.Parent.Components.Dropdown)
const NumberField = require(script.Parent.Parent.Components.NumberField)
const TextField = require(script.Parent.Parent.Components.TextField)
const Toggle = require(script.Parent.Parent.Components.Toggle)

const Create = Vide.create

const function Label(Text: string | () -> string, Order: number)
	return Create "TextLabel" {
		AutomaticSize = Enum.AutomaticSize.XY,
		BackgroundTransparency = 1,
		TextColor3 = Theme.Colors.DimText,
		TextSize = Settings.SmallText,
		FontFace = Font.fromEnum(Enum.Font.BuilderSans),
		TextWrapped = true,
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

const function Viewer(Order: number, Board: boolean)
	const function Item()
		return Reference.Current()
	end

	return Create "Frame" {
		Name = if Board then "Board" else "Viewer",
		Size = if Board then UDim2.fromScale(1, 1) else UDim2.new(1, 0, 0, 200),
		BackgroundColor3 = Theme.Colors.Background,
		LayoutOrder = Order,

		Create "ImageLabel" {
			Name = "Image",
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			ScaleType = Enum.ScaleType.Fit,
			Visible = function()
				const Current = Item()

				return Current ~= nil and Current.Kind ~= "Video"
			end,
			ImageContent = function()
				const Current = Item()

				if not Current then
					return Content.none
				end

				return Reference.FrameAt(Current) or Content.none
			end,
		},
		Create "VideoFrame" {
			Name = "Video",
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			Looped = true,
			Volume = 0,
			Visible = function()
				const Current = Item()

				return Current ~= nil and Current.Kind == "Video"
			end,
			Video = function()
				const Current = Item()

				return if Current and Current.VideoId then Current.VideoId else ""
			end,

			Vide.action(function(Frame: VideoFrame)
				Vide.effect(function()
					const Current = Item()

					if not Current or Current.Kind ~= "Video" then
						Frame:Pause()

						return
					end

					const Wanted = math.max(0, Session.Time() - Current.Offset)

					if Session.Playing() then
						if not Frame.IsPlaying then
							Frame.TimePosition = Wanted
							Frame:Play()
						elseif math.abs(Frame.TimePosition - Wanted) > 0.25 then
							Frame.TimePosition = Wanted
						end
					else
						Frame:Pause()
						Frame.TimePosition = Wanted
					end
				end)
			end),
		},
		Create "TextLabel" {
			Name = "Empty",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			AutomaticSize = Enum.AutomaticSize.XY,
			BackgroundTransparency = 1,
			TextColor3 = Theme.Colors.DimText,
			TextSize = Settings.SmallText,
			FontFace = Font.fromEnum(Enum.Font.BuilderSans),
			Text = "No reference yet",
			Visible = function()
				return Item() == nil
			end,
		},
	}
end

return function()
	const AssetText = Vide.source("")
	local Board: Part?
	local Unmount: (() -> ())?

	Vide.effect(function()
		const Loaded = Session.Rig()
		const Wanted = Reference.InWorld() and Loaded ~= nil and Reference.Current() ~= nil

		if not Wanted then
			if Unmount then
				Unmount()
				Unmount = nil
			end

			if Board then
				Board:Destroy()
				Board = nil
			end

			return
		end

		if not Board and Loaded then
			const Made = Instance.new("Part")

			Made.Name = "Sequence reference"
			Made.Anchored = true
			Made.CanCollide = false
			Made.CanQuery = false
			Made.CanTouch = false
			Made.CastShadow = false
			Made.Transparency = 1
			Made.Size = Vector3.new(8, 6, 0.1)

			const Extent = Loaded.Model:GetExtentsSize()

			Made.CFrame = Loaded.Root.CFrame * CFrame.new(-(Extent.X / 2 + 5), 1, 0) * CFrame.Angles(0, math.rad(20), 0)

			const Surface = Instance.new("SurfaceGui")

			Surface.Face = Enum.NormalId.Front
			Surface.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
			Surface.PixelsPerStud = 100
			Surface.LightInfluence = 0
			Surface.AlwaysOnTop = true
			Surface.Parent = Made

			Unmount = Vide.mount(function()
				return Viewer(1, true)
			end, Surface)

			Made.Parent = workspace
			Board = Made
		end
	end)

	Vide.cleanup(function()
		if Unmount then
			Unmount()
			Unmount = nil
		end

		if Board then
			Board:Destroy()
			Board = nil
		end
	end)

	const function Chosen(): Reference.Item?
		return Reference.Current()
	end

	return Create "ScrollingFrame" {
		Name = "ReferencePanel",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		ScrollBarThickness = 6,
		ScrollBarImageColor3 = Theme.Colors.DimText,
		Visible = function()
			return Session.Panel() == "Reference"
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
		Create "TextLabel" {
			AutomaticSize = Enum.AutomaticSize.XY,
			BackgroundTransparency = 1,
			TextColor3 = Theme.Colors.Text,
			TextSize = Settings.TextSize,
			FontFace = Font.fromEnum(Enum.Font.BuilderSansBold),
			Text = "Reference",
			LayoutOrder = 1,
		},
		Viewer(2, false),
		Dropdown {
			Options = function()
				const Names = {}

				for Index, Item in Reference.Items() do
					table.insert(Names, `{Index}. {Item.Name}`)
				end

				return Names
			end,
			Chosen = function()
				const Item = Chosen()

				return if Item then `{Reference.Chosen()}. {Item.Name}` else "Nothing loaded"
			end,
			Width = 276,
			LayoutOrder = 3,
			OnChange = function(Value: string)
				Reference.Chosen(tonumber(Value:match("^(%d+)%.")) or 1)
			end,
		},
		Row(4,
			Button {
				Text = "Image file",
				Icon = "image",
				LayoutOrder = 1,
				OnClick = function()
					const Problem = Reference.ImportImage()

					if Problem then
						Session.Say(Problem)
					end
				end,
			},
			Button {
				Text = "Video file",
				Icon = "film",
				LayoutOrder = 2,
				OnClick = function()
					const Problem = Reference.ImportVideo()

					if Problem then
						Session.Say(Problem)
					end
				end,
			},
			IconButton {
				Icon = "trash-2",
				Tooltip = "Remove this reference",
				LayoutOrder = 3,
				Disabled = function()
					return Chosen() == nil
				end,
				OnClick = function()
					Reference.Remove(Reference.Chosen())
				end,
			}
		),
		Row(5,
			TextField {
				Value = AssetText,
				Placeholder = "Asset id",
				Width = 120,
				LayoutOrder = 1,
				OnChange = AssetText,
			},
			Button {
				Text = "Image",
				LayoutOrder = 2,
				OnClick = function()
					const Id = tonumber(AssetText():match("%d+"))

					if Id then
						Reference.AddAssetImage(Id)
					else
						Session.Say("Type an image asset id first")
					end
				end,
			},
			Button {
				Text = "Video",
				LayoutOrder = 3,
				OnClick = function()
					const Id = tonumber(AssetText():match("%d+"))

					if Id then
						Reference.AddVideo(Id)
					else
						Session.Say("Type a video asset id first")
					end
				end,
			}
		),
		Label("Local files are read straight from disk and never uploaded: images through EditableImage, videos as a temporary asset. Videos follow the playhead.", 6),
		Row(7,
			Label("Starts at", 3),
			NumberField {
				Value = function()
					const Item = Chosen()

					return if Item then Item.Offset else 0
				end,
				Width = 60,
				Suffix = "s",
				LayoutOrder = 4,
				Disabled = function()
					const Item = Chosen()

					return Item == nil or Item.Kind == "Image"
				end,
				OnChange = function(Offset: number)
					Reference.Update(Reference.Chosen(), {Offset = Offset})
				end,
			}
		),
		Row(8,
			Toggle {
				On = Reference.InWorld,
				LayoutOrder = 1,
				OnChange = Reference.InWorld,
			},
			Label("Also show it on a board beside the rig", 2)
		),
	}
end