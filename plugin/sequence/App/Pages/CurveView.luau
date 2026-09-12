--!strict
const UserInputService = game:GetService("UserInputService")
const Vide = require(script.Parent.Parent.Parent.Packages.vide)
const Sift = require(script.Parent.Parent.Parent.Packages.sift)
const Settings = require(script.Parent.Parent.Parent.Settings)
const Theme = require(script.Parent.Parent.Theme)
const Session = require(script.Parent.Parent.Parent.Editor.Session)
const Clip = require(script.Parent.Parent.Parent.Editor.Clip)
const Pose = require(script.Parent.Parent.Parent.Editor.Pose)

const Create = Vide.create

type Props = {
	XOf: (number) -> number,
	TimeAt: (number) -> number,
	NameWidth: number,
	LaneWidth: () -> number,
	Visible: () -> boolean,
}

type Channel = {
	Name: string,
	Colour: Color3,
	Read: (any) -> number,
	Write: (any, number) -> any,
}

const JointChannels: {Channel} = {
	{
		Name = "Position X",
		Colour = Color3.fromRGB(235, 90, 90),
		Read = function(Value: CFrame)
			return Value.X
		end,
		Write = function(Value: CFrame, Number: number)
			return Value.Rotation + Vector3.new(Number, Value.Y, Value.Z)
		end,
	},
	{
		Name = "Position Y",
		Colour = Color3.fromRGB(110, 210, 110),
		Read = function(Value: CFrame)
			return Value.Y
		end,
		Write = function(Value: CFrame, Number: number)
			return Value.Rotation + Vector3.new(Value.X, Number, Value.Z)
		end,
	},
	{
		Name = "Position Z",
		Colour = Color3.fromRGB(100, 150, 255),
		Read = function(Value: CFrame)
			return Value.Z
		end,
		Write = function(Value: CFrame, Number: number)
			return Value.Rotation + Vector3.new(Value.X, Value.Y, Number)
		end,
	},
	{
		Name = "Rotation X",
		Colour = Color3.fromRGB(255, 150, 150),
		Read = function(Value: CFrame)
			return math.deg((Value:ToEulerAnglesXYZ()))
		end,
		Write = function(Value: CFrame, Number: number)
			const _, Y, Z = Value:ToEulerAnglesXYZ()

			return CFrame.new(Value.Position) * CFrame.fromEulerAnglesXYZ(math.rad(Number), Y, Z)
		end,
	},
	{
		Name = "Rotation Y",
		Colour = Color3.fromRGB(170, 240, 170),
		Read = function(Value: CFrame)
			const _, Y = Value:ToEulerAnglesXYZ()

			return math.deg(Y)
		end,
		Write = function(Value: CFrame, Number: number)
			const X, _, Z = Value:ToEulerAnglesXYZ()

			return CFrame.new(Value.Position) * CFrame.fromEulerAnglesXYZ(X, math.rad(Number), Z)
		end,
	},
	{
		Name = "Rotation Z",
		Colour = Color3.fromRGB(160, 190, 255),
		Read = function(Value: CFrame)
			const _, _, Z = Value:ToEulerAnglesXYZ()

			return math.deg(Z)
		end,
		Write = function(Value: CFrame, Number: number)
			const X, Y = Value:ToEulerAnglesXYZ()

			return CFrame.new(Value.Position) * CFrame.fromEulerAnglesXYZ(X, Y, math.rad(Number))
		end,
	},
}

const function ChannelsFor(Value: any): {Channel}
	const Kind: string = typeof(Value)

	if Kind == "CFrame" then
		return JointChannels
	end

	if Kind == "number" then
		return {{
			Name = "Value",
			Colour = Color3.fromRGB(240, 200, 90),
			Read = function(Number: number)
				return Number
			end,
			Write = function(_, Number: number)
				return Number
			end,
		} :: Channel}
	end

	if Kind == "Vector3" or Kind == "Color3" then
		const Channels: {Channel} = {}

		for Index, Axis in {"X", "Y", "Z"} do
			const Field = if Kind == "Color3" then ({"R", "G", "B"})[Index] else Axis

			table.insert(Channels, {
				Name = Field,
				Colour = JointChannels[Index].Colour,
				Read = function(Vector: any)
					return Vector[Field]
				end,
				Write = function(Vector: any, Number: number)
					const Parts = {Vector[if Kind == "Color3" then "R" else "X"], Vector[if Kind == "Color3" then "G" else "Y"], Vector[if Kind == "Color3" then "B" else "Z"]}

					Parts[Index] = Number

					return if Kind == "Color3" then Color3.new(Parts[1], Parts[2], Parts[3]) else Vector3.new(Parts[1], Parts[2], Parts[3])
				end,
			})
		end

		return Channels
	end

	return {}
end

return function(Props: Props)
	const Hidden = Vide.source({} :: {[string]: boolean})
	const Height = Vide.source(200)
	local Dragging: {Channel: Channel, Time: number, StartValue: number, StartY: number, PerPixel: number}?

	const function TrackName(): string?
		const Selected = Session.SelectedJoint()

		if Selected then
			return Selected
		end

		const First = Session.SelectedKeys()[1]

		return if First then First.Joint else nil
	end

	const function Track(): Clip.Track?
		const Name = TrackName()

		return if Name then Session.Current().Tracks[Name] else nil
	end

	const function Channels(): {Channel}
		const Found = Track()

		if not Found or #Found.Keys == 0 then
			return if Session.SelectedJoint() then JointChannels else {}
		end

		return ChannelsFor(Found.Keys[1].Value)
	end

	const function Range(): (number, number)
		const Found = Track()
		local Low = math.huge
		local High = -math.huge

		if Found then
			for _, Channel in Channels() do
				if Hidden()[Channel.Name] then
					continue
				end

				for _, Key in Found.Keys do
					const Value = Channel.Read(Key.Value)

					Low = math.min(Low, Value)
					High = math.max(High, Value)
				end
			end
		end

		if Low == math.huge then
			return -1, 1
		end

		if High - Low < 0.001 then
			return Low - 1, High + 1
		end

		const Pad = (High - Low) * 0.15

		return Low - Pad, High + Pad
	end

	const function YOf(Value: number): number
		const Low, High = Range()

		return (1 - (Value - Low) / (High - Low)) * (Height() - 24) + 12
	end

	const function Segments(Channel: Channel): {{X1: number, Y1: number, X2: number, Y2: number}}
		const Found = Track()
		const Made = {}

		if not Found or #Found.Keys < 2 or Hidden()[Channel.Name] then
			return Made
		end

		const First = Found.Keys[1].Time
		const Last = Found.Keys[#Found.Keys].Time
		const Steps = math.clamp(math.floor((Props.XOf(Last) - Props.XOf(First)) / 3), 8, 400)
		local PreviousX = Props.XOf(First)
		local PreviousY = YOf(Channel.Read(Pose.SampleTrack(Found, First)))

		for Step = 1, Steps do
			const Time = First + (Last - First) * Step / Steps
			const X = Props.XOf(Time)
			const Y = YOf(Channel.Read(Pose.SampleTrack(Found, Time)))

			table.insert(Made, {
				X1 = PreviousX,
				Y1 = PreviousY,
				X2 = X,
				Y2 = Y,
			})
			PreviousX = X
			PreviousY = Y
		end

		return Made
	end

	const function WriteKey(Channel: Channel, Time: number, Number: number, MergeKey: string)
		const Name = TrackName()
		const Found = Track()
		const Key = if Name then Clip.FindKey(Session.Current(), Name, Time) else nil

		if not Name or not Found or not Key then
			return
		end

		Session.Edit(Clip.SetKey(Session.Current(), Name, Sift.Dictionary.merge(Key, {Value = Channel.Write(Key.Value, Number)}), Found.Object, Found.Property), MergeKey)
	end

	return Create "Frame" {
		Name = "Curves",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Theme.Colors.Background,
		LayoutOrder = 3,
		Visible = Props.Visible,
		InputChanged = function(Input: InputObject)
			const Active = Dragging

			if not Active or Input.UserInputType ~= Enum.UserInputType.MouseMovement then
				return
			end

			const Number = Active.StartValue - (Input.Position.Y - Active.StartY) * Active.PerPixel

			WriteKey(Active.Channel, Active.Time, if Session.Snap() then math.round(Number * 100) / 100 else Number, `Curve {Active.Channel.Name}`)
		end,

		Vide.action(function(Object: Frame)
			const function Measure()
				Height(Object.AbsoluteSize.Y)
			end

			Measure()
			Vide.cleanup(Object:GetPropertyChangedSignal("AbsoluteSize"):Connect(Measure))
			Vide.cleanup(UserInputService.InputEnded:Connect(function(Input: InputObject)
				if Input.UserInputType == Enum.UserInputType.MouseButton1 and Dragging then
					Dragging = nil
					Session.EndMerge()
				end
			end))
		end),

		Create "UIFlexItem" {FlexMode = Enum.UIFlexMode.Fill},
		Create "Frame" {
			Name = "Legend",
			Size = UDim2.new(0, Props.NameWidth, 1, 0),
			BackgroundColor3 = Theme.Colors.Panel,
			ZIndex = 3,

			Create "UIPadding" {
				PaddingLeft = UDim.new(0, 8),
				PaddingTop = UDim.new(0, 6),
			},
			Create "UIListLayout" {
				SortOrder = Enum.SortOrder.LayoutOrder,
				Padding = UDim.new(0, 2),
			},
			Create "TextLabel" {
				AutomaticSize = Enum.AutomaticSize.XY,
				BackgroundTransparency = 1,
				TextColor3 = Theme.Colors.Text,
				TextSize = Settings.TextSize,
				FontFace = Font.fromEnum(Enum.Font.BuilderSansMedium),
				LayoutOrder = 0,
				ZIndex = 4,
				Text = function()
					const Name = TrackName()
					const Found = Track()

					if not Name then
						return "Select a joint to see its curves"
					end

					return if Found and Found.Object then `{Found.Object.Name}.{Found.Property}` else Name
				end,
			},
			Vide.indexes(Channels, function(Channel, Index)
				return Create "TextButton" {
					AutomaticSize = Enum.AutomaticSize.XY,
					BackgroundTransparency = 1,
					TextColor3 = function()
						return if Hidden()[Channel().Name] then Theme.Colors.DimText() else Channel().Colour
					end,
					TextSize = Settings.SmallText,
					FontFace = Font.fromEnum(Enum.Font.BuilderSans),
					LayoutOrder = Index,
					ZIndex = 4,
					Text = function()
						return `{if Hidden()[Channel().Name] then "○" else "●"} {Channel().Name}`
					end,
					Activated = function()
						const Current = table.clone(Hidden())

						Current[Channel().Name] = not Current[Channel().Name]
						Hidden(Current)
					end,
				}
			end),
		},
		Create "Frame" {
			Name = "Graph",
			Position = UDim2.fromOffset(Props.NameWidth, 0),
			Size = UDim2.new(1, -Props.NameWidth, 1, 0),
			BackgroundTransparency = 1,
			ClipsDescendants = true,

			Create "Frame" {
				Name = "Edge",
				Size = UDim2.new(0, 1, 1, 0),
				BackgroundColor3 = Theme.Colors.Border,
				ZIndex = 4,
			},
			Create "Frame" {
				Name = "Zero",
				Position = function()
					return UDim2.fromOffset(0, YOf(0))
				end,
				Size = UDim2.new(1, 0, 0, 1),
				BackgroundColor3 = Theme.Colors.Border,
			},
			Vide.indexes(Channels, function(ChannelSource)
				const function Channel(): Channel
					return ChannelSource()
				end

				return Create "Frame" {
					Name = function()
						return Channel().Name
					end,
					Size = UDim2.fromScale(1, 1),
					BackgroundTransparency = 1,

					Vide.indexes(function()
						return Segments(Channel())
					end, function(Segment)
						return Create "Frame" {
							AnchorPoint = Vector2.new(0, 0.5),
							Position = function()
								return UDim2.fromOffset(Segment().X1, Segment().Y1)
							end,
							Size = function()
								const S = Segment()

								return UDim2.fromOffset(math.sqrt((S.X2 - S.X1) ^ 2 + (S.Y2 - S.Y1) ^ 2), 2)
							end,
							Rotation = function()
								const S = Segment()

								return math.deg(math.atan2(S.Y2 - S.Y1, S.X2 - S.X1))
							end,
							BackgroundColor3 = function()
								return Channel().Colour
							end,
							BorderSizePixel = 0,
						}
					end),
					Vide.values(function()
						const Found = Track()

						return if Found and not Hidden()[Channel().Name] then Found.Keys else {}
					end, function(Key: Clip.Key)
						return Create "TextButton" {
							AnchorPoint = Vector2.new(0.5, 0.5),
							Position = function()
								return UDim2.fromOffset(Props.XOf(Key.Time), YOf(Channel().Read(Key.Value)))
							end,
							Size = UDim2.fromOffset(12, 12),
							BackgroundColor3 = function()
								const Name = TrackName()

								return if Name and Session.IsSelected(Name, Key.Time) then Theme.Colors.Accent() else Channel().Colour
							end,
							Text = "",
							AutoButtonColor = false,
							ZIndex = 5,
							InputBegan = function(Input: InputObject)
								if Input.UserInputType ~= Enum.UserInputType.MouseButton1 then
									return
								end

								const Name = TrackName()

								if Name then
									Session.SelectKey(Name, Key.Time, UserInputService:IsKeyDown(Enum.KeyCode.LeftShift))
									Session.Seek(Key.Time)
								end

								const Low, High = Range()

								Dragging = {
									Channel = Channel(),
									Time = Key.Time,
									StartValue = Channel().Read(Key.Value),
									StartY = Input.Position.Y,
									PerPixel = (High - Low) / (Height() - 24),
								}
							end,

							Create "UICorner" {CornerRadius = UDim.new(1, 0)},
							Create "UIStroke" {
								Color = Theme.Colors.Background,
								Thickness = 1,
							},
						}
					end),
				}
			end),
			Create "TextLabel" {
				Name = "High",
				Position = UDim2.fromOffset(4, 0),
				AutomaticSize = Enum.AutomaticSize.XY,
				BackgroundTransparency = 1,
				TextColor3 = Theme.Colors.DimText,
				TextSize = Settings.SmallText,
				FontFace = Font.fromEnum(Enum.Font.BuilderSans),
				Text = function()
					const _, High = Range()

					return `{math.round(High * 100) / 100}`
				end,
			},
			Create "TextLabel" {
				Name = "Low",
				Position = UDim2.new(0, 4, 1, -14),
				AutomaticSize = Enum.AutomaticSize.XY,
				BackgroundTransparency = 1,
				TextColor3 = Theme.Colors.DimText,
				TextSize = Settings.SmallText,
				FontFace = Font.fromEnum(Enum.Font.BuilderSans),
				Text = function()
					const Low = Range()

					return `{math.round(Low * 100) / 100}`
				end,
			},
		},
	}
end