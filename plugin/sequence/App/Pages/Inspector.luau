--!strict
const Vide = require(script.Parent.Parent.Parent.Packages.vide)
const Settings = require(script.Parent.Parent.Parent.Settings)
const Format = require(script.Parent.Parent.Parent.Format)
const Theme = require(script.Parent.Parent.Theme)
const Session = require(script.Parent.Parent.Parent.Editor.Session)
const Clip = require(script.Parent.Parent.Parent.Editor.Clip)
const Pose = require(script.Parent.Parent.Parent.Editor.Pose)
const Easing = require(script.Parent.Parent.Parent.Editor.Easing)
const Dropdown = require(script.Parent.Parent.Components.Dropdown)
const NumberField = require(script.Parent.Parent.Components.NumberField)
const TextField = require(script.Parent.Parent.Components.TextField)
const Button = require(script.Parent.Parent.Components.Button)

const Create = Vide.create

const function Label(Text: string | () -> string, Order: number, Strong: boolean?)
	return Create "TextLabel" {
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromScale(0, 1),
		BackgroundTransparency = 1,
		TextColor3 = if Strong then Theme.Colors.Text else Theme.Colors.DimText,
		TextSize = if Strong then Settings.TextSize else Settings.SmallText,
		FontFace = Font.fromEnum(if Strong then Enum.Font.BuilderSansMedium else Enum.Font.BuilderSans),
		Text = Text,
		LayoutOrder = Order,
	}
end

const function Strip(Name: string, Order: number, Visible: () -> boolean, ...: Instance)
	return Create "Frame" {
		Name = Name,
		Size = UDim2.new(1, 0, 0, 30),
		BackgroundTransparency = 1,
		LayoutOrder = Order,
		Visible = Visible,

		Create "UIListLayout" {
			FillDirection = Enum.FillDirection.Horizontal,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			Padding = UDim.new(0, 6),
			SortOrder = Enum.SortOrder.LayoutOrder,
		},
		...,
	}
end

return function()
	const function SelectedKeyList(): {Clip.Key}
		const Found = {}

		for _, Ref in Session.SelectedKeys() do
			const Key = Session.KeyAt(Ref.Joint, Ref.Time)

			if Key then
				table.insert(Found, Key)
			end
		end

		return Found
	end

	const function FirstKey(): Clip.Key?
		return SelectedKeyList()[1]
	end

	const function JointTransform(): CFrame
		const Name = Session.SelectedJoint()

		if not Name then
			return CFrame.identity
		end

		return Pose.Sample(Session.Current(), Session.Time())[Name] or CFrame.identity
	end

	const function WriteTransform(Value: CFrame)
		const Name = Session.SelectedJoint()

		if Name then
			Session.SetJointTransform(Name, Value)
		end
	end

	const function Marker(): Clip.Marker?
		return Session.SelectedMarker()
	end

	const function ShowKeys(): boolean
		return Session.Rig() ~= nil and #Session.SelectedKeys() > 0 and Marker() == nil
	end

	const function ShowMarker(): boolean
		return Session.Rig() ~= nil and Marker() ~= nil
	end

	const function ShowJoint(): boolean
		return Session.Rig() ~= nil and not ShowKeys() and not ShowMarker() and Session.SelectedJoint() ~= nil
	end

	const function ShowHint(): boolean
		return not ShowKeys() and not ShowMarker() and not ShowJoint()
	end

	const function Axis(Order: number, Name: string, Read: () -> number, Write: (number) -> (), Rotation: boolean)
		return NumberField {
			Value = Read,
			Width = 66,
			Suffix = if Rotation then "°" else Name,
			LayoutOrder = Order,
			Format = function(Value: number)
				return if Rotation then Format.Degrees(Value) else `{math.round(Value * 100) / 100}`
			end,
			OnChange = function(Value: number)
				Write(if Rotation then math.rad(Value) else Value)
			end,
		}
	end

	const function Rotation(): (number, number, number)
		return JointTransform():ToEulerAnglesXYZ()
	end

	const function SetRotation(X: number, Y: number, Z: number)
		WriteTransform(CFrame.new(JointTransform().Position) * CFrame.fromEulerAnglesXYZ(X, Y, Z))
	end

	const function SetPosition(Position: Vector3)
		WriteTransform(JointTransform().Rotation + Position)
	end

	return Create "Frame" {
		Name = "Inspector",
		Size = UDim2.new(1, 0, 0, 40),
		BackgroundColor3 = Theme.Colors.Panel,

		Create "UIPadding" {
			PaddingLeft = UDim.new(0, 8),
			PaddingRight = UDim.new(0, 8),
		},
		Create "Frame" {
			Name = "Edge",
			Size = UDim2.new(1, 0, 0, 1),
			BackgroundColor3 = Theme.Colors.Border,
		},
		Strip("Hint", 1, ShowHint,
			Label(function()
				if not Session.Rig() then
					return "Pick a rig to start animating"
				end

				return "Select a joint to pose it, or a keyframe to change its easing. Right click the timeline for more."
			end, 1)
		),
		Strip("Joint", 2, ShowJoint,
			Label(function()
				return Session.SelectedJoint() or ""
			end, 1, true),
			Label("Position", 2),
			Axis(3, "x", function()
				return JointTransform().X
			end, function(Value: number)
				SetPosition(Vector3.new(Value, JointTransform().Y, JointTransform().Z))
			end, false),
			Axis(4, "y", function()
				return JointTransform().Y
			end, function(Value: number)
				SetPosition(Vector3.new(JointTransform().X, Value, JointTransform().Z))
			end, false),
			Axis(5, "z", function()
				return JointTransform().Z
			end, function(Value: number)
				SetPosition(Vector3.new(JointTransform().X, JointTransform().Y, Value))
			end, false),
			Label("Rotation", 6),
			Axis(7, "x", function()
				const X = Rotation()

				return X
			end, function(Value: number)
				const _, Y, Z = Rotation()

				SetRotation(Value, Y, Z)
			end, true),
			Axis(8, "y", function()
				const _, Y = Rotation()

				return Y
			end, function(Value: number)
				const X, _, Z = Rotation()

				SetRotation(X, Value, Z)
			end, true),
			Axis(9, "z", function()
				const _, _, Z = Rotation()

				return Z
			end, function(Value: number)
				const X, Y = Rotation()

				SetRotation(X, Y, Value)
			end, true),
			Button {
				Text = "Reset",
				LayoutOrder = 10,
				OnClick = function()
					WriteTransform(CFrame.identity)
				end,
			},
			Button {
				Text = "Mirror",
				LayoutOrder = 11,
				OnClick = function()
					const Name = Session.SelectedJoint()

					if Name then
						Session.MirrorPose({Name})
					end
				end,
			},
			Button {
				Text = function()
					const Name = Session.SelectedJoint()

					return if Name and Session.Pins()[Name] then "Unpin" else "Pin"
				end,
				LayoutOrder = 12,
				OnClick = function()
					const Name = Session.SelectedJoint()

					if Name then
						Session.TogglePin(Name)
					end
				end,
			}
		),
		Strip("Keys", 3, ShowKeys,
			Label(function()
				const Count = #Session.SelectedKeys()
				const First = Session.SelectedKeys()[1]

				if Count == 1 and First then
					return `{First.Joint} at {Format.Timecode(First.Time, Session.FrameRate())}`
				end

				return `{Count} keyframes`
			end, 1, true),
			Label("Easing", 2),
			Dropdown {
				Options = Easing.Styles,
				Chosen = function()
					const Key = FirstKey()

					return if Key then Key.EasingStyle else "Linear"
				end,
				Width = 100,
				LayoutOrder = 3,
				OnChange = function(Style: string)
					Session.SetSelectedEasing(Style, nil)
				end,
			},
			Dropdown {
				Options = Easing.Directions,
				Chosen = function()
					const Key = FirstKey()

					return if Key then Key.EasingDirection else "In"
				end,
				Width = 80,
				LayoutOrder = 4,
				Disabled = function()
					const Key = FirstKey()

					return Key == nil or Key.EasingStyle == "Linear" or Key.EasingStyle == "Constant" or Key.EasingStyle == "Smooth"
				end,
				OnChange = function(Direction: string)
					Session.SetSelectedEasing(nil, Direction)
				end,
			},
			Label("Time", 5),
			NumberField {
				Value = function()
					const First = Session.SelectedKeys()[1]

					return if First then First.Time else 0
				end,
				Minimum = 0,
				Width = 64,
				Suffix = "s",
				LayoutOrder = 6,
				OnChange = function(Time: number)
					const First = Session.SelectedKeys()[1]

					if First then
						Session.MoveSelectedKeys(Session.SnapTime(Time) - First.Time)
						Session.EndMerge()
					end
				end,
			},
			Label("Span", 7),
			NumberField {
				Value = function()
					const Lowest, Highest = Session.SelectionSpan()

					return if Highest > Lowest then Highest - Lowest else 0
				end,
				Minimum = 0,
				Width = 64,
				Suffix = "s",
				LayoutOrder = 8,
				Disabled = function()
					return #Session.SelectedKeys() < 2
				end,
				OnChange = function(Span: number)
					Session.ScaleSelectedKeys(Span)
				end,
			},
			Button {
				Text = "Delete",
				Danger = true,
				LayoutOrder = 9,
				OnClick = Session.DeleteSelectedKeys,
			}
		),
		Strip("Marker", 4, ShowMarker,
			Label("Event", 1, true),
			TextField {
				Value = function()
					const Found = Marker()

					return if Found then Found.Name else ""
				end,
				Placeholder = "Name",
				Width = 120,
				LayoutOrder = 2,
				OnChange = function(Name: string)
					const Found = Marker()

					if not Found or Name == "" then
						return
					end

					if Clip.FindMarker(Session.Current(), Found.Time, Name) then
						Session.Say("An event with that name is already on this frame")

						return
					end

					Session.Edit(Clip.SetMarker(Clip.RemoveMarker(Session.Current(), Found), {
						Time = Found.Time,
						Name = Name,
						Value = Found.Value,
					}))
					Session.SelectedMarker(Clip.FindMarker(Session.Current(), Found.Time, Name))
				end,
			},
			Label("Value", 3),
			TextField {
				Value = function()
					const Found = Marker()

					return if Found then Found.Value else ""
				end,
				Placeholder = "Optional",
				Width = 140,
				LayoutOrder = 4,
				OnChange = function(Value: string)
					const Found = Marker()

					if not Found then
						return
					end

					Session.Edit(Clip.SetMarker(Clip.RemoveMarker(Session.Current(), Found), {
						Time = Found.Time,
						Name = Found.Name,
						Value = Value,
					}))
					Session.SelectedMarker(Clip.FindMarker(Session.Current(), Found.Time, Found.Name))
				end,
			},
			Label(function()
				const Found = Marker()

				return if Found then `at {Format.Timecode(Found.Time, Session.FrameRate())}` else ""
			end, 5),
			Button {
				Text = "Delete",
				Danger = true,
				LayoutOrder = 6,
				OnClick = function()
					const Found = Marker()

					if Found then
						Session.Edit(Clip.RemoveMarker(Session.Current(), Found))
						Session.SelectedMarker(nil)
					end
				end,
			}
		),
		Create "TextLabel" {
			Name = "Notice",
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, 0, 0.5, 0),
			AutomaticSize = Enum.AutomaticSize.X,
			Size = UDim2.fromScale(0, 1),
			BackgroundTransparency = 1,
			TextColor3 = Theme.Colors.Accent,
			TextSize = Settings.SmallText,
			FontFace = Font.fromEnum(Enum.Font.BuilderSansMedium),
			Text = Session.Notice,
			ZIndex = 8,
		},
	}
end