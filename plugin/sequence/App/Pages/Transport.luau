--!strict
const Selection = game:GetService("Selection")
const Vide = require(script.Parent.Parent.Parent.Packages.vide)
const Sift = require(script.Parent.Parent.Parent.Packages.sift)
const Settings = require(script.Parent.Parent.Parent.Settings)
const Format = require(script.Parent.Parent.Parent.Format)
const Theme = require(script.Parent.Parent.Theme)
const Overlay = require(script.Parent.Parent.Overlay)
const Session = require(script.Parent.Parent.Parent.Editor.Session)
const Clip = require(script.Parent.Parent.Parent.Editor.Clip)
const PoseTool = require(script.Parent.Parent.Parent.Editor.PoseTool)
const Playtest = require(script.Parent.Parent.Parent.Editor.Playtest)
const Bake = require(script.Parent.Parent.Parent.Editor.Bake)
const IconButton = require(script.Parent.Parent.Components.IconButton)
const Dropdown = require(script.Parent.Parent.Components.Dropdown)
const NumberField = require(script.Parent.Parent.Components.NumberField)

const Create = Vide.create

const Properties = {
	"Transparency",
	"Color",
	"Size",
	"CFrame",
	"Position",
	"Orientation",
	"Reflectance",
	"Brightness",
	"Range",
	"Enabled",
	"Value",
	"Volume",
	"PlaybackSpeed",
	"TextTransparency",
	"ImageTransparency",
	"BackgroundTransparency",
	"Rotation",
	"FieldOfView",
}

const function Label(Text: string, Order: number)
	return Create "TextLabel" {
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromScale(0, 1),
		BackgroundTransparency = 1,
		TextColor3 = Theme.Colors.DimText,
		TextSize = Settings.SmallText,
		FontFace = Font.fromEnum(Enum.Font.BuilderSans),
		Text = Text,
		LayoutOrder = Order,
	}
end

const function Divider(Order: number)
	return Create "Frame" {
		Name = "Divider",
		Size = UDim2.new(0, 1, 0, 18),
		BackgroundColor3 = Theme.Colors.Border,
		LayoutOrder = Order,
	}
end

const function PropertyMenu(Anchor: GuiObject)
	const Picked = Selection:Get()[1]

	if not Picked then
		Session.Say("Select the object to animate in the Explorer first")

		return
	end

	const Entries: {Overlay.Entry} = {}

	for _, Property in Properties do
		const Ok = pcall(function()
			return (Picked :: any)[Property]
		end)

		if Ok then
			table.insert(Entries, {
				Label = `{Picked.Name}.{Property}`,
				Action = function()
					if Session.AddPropertyTrack(Picked, Property) then
						Session.Say(`Keyframe {Picked.Name}.{Property} by changing it in the Properties window, then pressing its diamond`)
					end
				end,
			})
		end
	end

	if #Entries == 0 then
		table.insert(Entries, {
			Label = `{Picked.Name} has nothing here to animate`,
			Disabled = true,
		})
	end

	Overlay.Menu(Anchor, Entries, 240)
end

const function BakeMenu(Anchor: GuiObject)
	const Loaded = Session.Rig()

	if not Loaded then
		return
	end

	Overlay.Menu(Anchor, {
		{
			Label = "Bake this pose as a frozen copy",
			Action = function()
				Bake.Place(Loaded, Session.Current(), {Session.Time()})
				Session.Say("A posed copy of the rig was placed beside it and selected")
			end,
		},
		{
			Label = "Bake every keyframe as a copy",
			Action = function()
				const Times = Clip.KeyTimes(Session.Current())

				Bake.Place(Loaded, Session.Current(), Times)
				Session.Say(`{#Times} posed copies were placed beside the rig`)
			end,
		},
	}, 260)
end

return function()
	local PropertyAnchor: GuiObject
	local BakeAnchor: GuiObject

	const function NoRig(): boolean
		return Session.Rig() == nil
	end

	const function Anchored(Name: string, Order: number, Button: Instance, Set: (GuiObject) -> ())
		return Create "TextButton" {
			Name = Name,
			Size = function()
				return UDim2.fromOffset(Settings.TextSize() + 12, Settings.TextSize() + 8)
			end,
			BackgroundTransparency = 1,
			Text = "",
			LayoutOrder = Order,

			Vide.action(function(Object: TextButton)
				Set(Object)
			end),

			Button,
		}
	end

	return Create "Frame" {
		Name = "Transport",
		Size = UDim2.new(1, 0, 0, 36),
		BackgroundColor3 = Theme.Colors.Background,

		Create "UIPadding" {
			PaddingLeft = UDim.new(0, 6),
			PaddingRight = UDim.new(0, 8),
		},
		Create "UIListLayout" {
			FillDirection = Enum.FillDirection.Horizontal,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			Padding = UDim.new(0, 4),
			SortOrder = Enum.SortOrder.LayoutOrder,
		},
		IconButton {
			Icon = "skip-back",
			Tooltip = "Go to start (Home)",
			LayoutOrder = 1,
			Disabled = NoRig,
			OnClick = function()
				Session.Stop()
				Session.Time(0)
			end,
		},
		IconButton {
			Icon = "step-back",
			Tooltip = "Previous frame (Left)",
			LayoutOrder = 2,
			Disabled = NoRig,
			OnClick = function()
				Session.StepFrames(-1)
			end,
		},
		IconButton {
			Icon = function()
				return if Session.Playing() then "pause" else "play"
			end,
			Tooltip = "Play or pause (Space)",
			Size = function()
				return Settings.TextSize() + 4
			end,
			LayoutOrder = 3,
			Disabled = NoRig,
			Active = Session.Playing,
			OnClick = Session.TogglePlay,
		},
		IconButton {
			Icon = "step-forward",
			Tooltip = "Next frame (Right)",
			LayoutOrder = 4,
			Disabled = NoRig,
			OnClick = function()
				Session.StepFrames(1)
			end,
		},
		IconButton {
			Icon = "skip-forward",
			Tooltip = "Go to end (End)",
			LayoutOrder = 5,
			Disabled = NoRig,
			OnClick = function()
				Session.Stop()
				Session.Time(Session.SceneLength())
			end,
		},
		Create "TextLabel" {
			Name = "Clock",
			AutomaticSize = Enum.AutomaticSize.X,
			Size = UDim2.fromScale(0, 1),
			BackgroundTransparency = 1,
			TextColor3 = Theme.Colors.Text,
			TextSize = Settings.TextSize,
			FontFace = Font.fromEnum(Enum.Font.RobotoMono),
			LayoutOrder = 6,
			Text = function()
				return `{Format.Timecode(Session.Time(), Session.FrameRate())} / {Format.Timecode(Session.Current().Length, Session.FrameRate())}`
			end,
		},
		Divider(7),
		Label("Length", 8),
		NumberField {
			Value = function()
				return Session.Current().Length
			end,
			Minimum = 1 / 60,
			Maximum = 600,
			Width = 62,
			Suffix = "s",
			LayoutOrder = 9,
			Disabled = NoRig,
			OnChange = function(Length: number)
				Session.Edit(Clip.SetLength(Session.Current(), Length))
				Session.Time(math.min(Session.Time(), Session.Current().Length))
			end,
		},
		Label("Rate", 10),
		NumberField {
			Value = Session.FrameRate,
			Minimum = 1,
			Maximum = 240,
			Width = 52,
			Suffix = "fps",
			LayoutOrder = 11,
			OnChange = function(Rate: number)
				Session.FrameRate(math.round(Rate))
				Settings.Set("FrameRate", math.round(Rate))
			end,
		},
		IconButton {
			Icon = "magnet",
			Tooltip = "Snap to frames",
			LayoutOrder = 12,
			Active = Session.Snap,
			OnClick = function()
				Session.Snap(not Session.Snap())
			end,
		},
		IconButton {
			Icon = "repeat",
			Tooltip = "Loop",
			LayoutOrder = 13,
			Disabled = NoRig,
			Active = function()
				return Session.Current().Looping
			end,
			OnClick = function()
				Session.Edit(Sift.Dictionary.merge(Session.Current(), {Looping = not Session.Current().Looping}))
			end,
		},
		Dropdown {
			Options = {
				"0.25",
				"0.5",
				"1",
				"2",
			},
			Labels = {
				["0.25"] = "¼ speed",
				["0.5"] = "½ speed",
				["1"] = "1× speed",
				["2"] = "2× speed",
			},
			Chosen = function()
				return `{Session.Speed()}`
			end,
			Width = 92,
			LayoutOrder = 14,
			OnChange = function(Value: string)
				Session.Speed(tonumber(Value) or 1)
			end,
		},
		Divider(15),
		Label("Priority", 16),
		Dropdown {
			Options = Clip.Priorities,
			Chosen = function()
				return Session.Current().Priority
			end,
			Width = 96,
			LayoutOrder = 17,
			Disabled = NoRig,
			OnChange = function(Value: string)
				Session.Edit(Sift.Dictionary.merge(Session.Current(), {Priority = Value}))
			end,
		},
		Create "Frame" {
			Name = "Spacer",
			Size = UDim2.fromScale(1, 0),
			BackgroundTransparency = 1,
			LayoutOrder = 18,

			Create "UIFlexItem" {FlexMode = Enum.UIFlexMode.Fill},
		},
		IconButton {
			Icon = "hand",
			Tooltip = "Pose tool: click a part in the viewport and drag to turn it (Escape to leave)",
			LayoutOrder = 19,
			Disabled = NoRig,
			Active = PoseTool.Active,
			OnClick = PoseTool.Toggle,
		},
		IconButton {
			Icon = "rotate-3d",
			Tooltip = "Rotate joints (R)",
			LayoutOrder = 20,
			Disabled = NoRig,
			Active = function()
				return Session.Tool() == "Rotate"
			end,
			OnClick = function()
				Session.Tool("Rotate")
			end,
		},
		IconButton {
			Icon = "move-3d",
			Tooltip = "Move joints (T)",
			LayoutOrder = 21,
			Disabled = NoRig,
			Active = function()
				return Session.Tool() == "Move"
			end,
			OnClick = function()
				Session.Tool("Move")
			end,
		},
		IconButton {
			Icon = "key-round",
			Tooltip = function()
				return if Session.AutoKey() then "Auto key is on, every pose change writes a keyframe" else "Auto key is off, pose freely then press K to keep it"
			end,
			LayoutOrder = 22,
			Disabled = NoRig,
			Active = Session.AutoKey,
			OnClick = function()
				if Session.AutoKey() then
					Session.AutoKey(false)
				else
					Session.CommitScratch()
					Session.AutoKey(true)
				end
			end,
		},
		IconButton {
			Icon = "flip-horizontal-2",
			Tooltip = "Mirror the pose left to right at the playhead",
			LayoutOrder = 23,
			Disabled = NoRig,
			OnClick = function()
				Session.MirrorPose(nil)
			end,
		},
		IconButton {
			Icon = "ghost",
			Tooltip = "Onion skin",
			LayoutOrder = 24,
			Disabled = NoRig,
			Active = Session.OnionSkin,
			OnClick = function()
				Session.OnionSkin(not Session.OnionSkin())
			end,
		},
		Divider(25),
		Anchored("PropertyAnchor", 26, IconButton {
			Icon = "sliders-horizontal",
			Tooltip = "Animate a property of the selected object",
			Disabled = NoRig,
			OnClick = function()
				PropertyMenu(PropertyAnchor)
			end,
		}, function(Object: GuiObject)
			PropertyAnchor = Object
		end),
		IconButton {
			Icon = "diamond",
			Tooltip = "Add keyframe for the selected joint, or every joint (K)",
			LayoutOrder = 27,
			Disabled = NoRig,
			OnClick = function()
				Session.CommitScratch()
				Session.KeyAll()
			end,
		},
		Divider(28),
		IconButton {
			Icon = "gamepad-2",
			Tooltip = function()
				return if Playtest.Ready() then "Playtest scripts are in place, press Play in Studio. Click to remove them" else "Set up a playtest that plays this on your character without uploading"
			end,
			LayoutOrder = 29,
			Disabled = NoRig,
			Active = Playtest.Ready,
			OnClick = Playtest.Toggle,
		},
		Anchored("BakeAnchor", 30, IconButton {
			Icon = "snowflake",
			Tooltip = "Bake a frozen posed copy of the rig",
			Disabled = NoRig,
			OnClick = function()
				BakeMenu(BakeAnchor)
			end,
		}, function(Object: GuiObject)
			BakeAnchor = Object
		end),
	}
end