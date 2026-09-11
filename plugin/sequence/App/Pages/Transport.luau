--!strict
const Vide = require(script.Parent.Parent.Parent.Packages.vide)
const Sift = require(script.Parent.Parent.Parent.Packages.sift)
const Settings = require(script.Parent.Parent.Parent.Settings)
const Format = require(script.Parent.Parent.Parent.Format)
const Theme = require(script.Parent.Parent.Theme)
const Session = require(script.Parent.Parent.Parent.Editor.Session)
const Clip = require(script.Parent.Parent.Parent.Editor.Clip)
const IconButton = require(script.Parent.Parent.Components.IconButton)
const Dropdown = require(script.Parent.Parent.Components.Dropdown)
const NumberField = require(script.Parent.Parent.Components.NumberField)

const Create = Vide.create

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

return function()
	const function NoRig(): boolean
		return Session.Rig() == nil
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
				Session.Time(Session.Current().Length)
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
				Session.Time(math.min(Session.Time(), Length))
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
			Icon = "rotate-3d",
			Tooltip = "Rotate joints (R)",
			LayoutOrder = 19,
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
			LayoutOrder = 20,
			Disabled = NoRig,
			Active = function()
				return Session.Tool() == "Move"
			end,
			OnClick = function()
				Session.Tool("Move")
			end,
		},
		IconButton {
			Icon = "ghost",
			Tooltip = "Onion skin",
			LayoutOrder = 21,
			Disabled = NoRig,
			Active = Session.OnionSkin,
			OnClick = function()
				Session.OnionSkin(not Session.OnionSkin())
			end,
		},
		Divider(22),
		IconButton {
			Icon = "diamond",
			Tooltip = "Add keyframe for the selected joint, or every joint (K)",
			LayoutOrder = 23,
			Disabled = NoRig,
			OnClick = function()
				Session.KeyAll()
			end,
		},
	}
end