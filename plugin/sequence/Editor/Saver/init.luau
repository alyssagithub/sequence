--!strict
const KeyframeSequenceProvider = game:GetService("KeyframeSequenceProvider")
const AnimationClipProvider = game:GetService("AnimationClipProvider")
const ServerStorage = game:GetService("ServerStorage")
const Selection = game:GetService("Selection")
const ChangeHistoryService = game:GetService("ChangeHistoryService")
const HttpService = game:GetService("HttpService")
const Clip = require(script.Parent.Clip)
const Rig = require(script.Parent.Rig)
const Pose = require(script.Parent.Pose)
const Easing = require(script.Parent.Easing)
const ClipSchema = require(script.Parent.ClipSchema)

const Templates = script.Templates

const Saver = {}

export type Location = "Rig" | "Roblox" | "Moon"

Saver.Locations = {
	"Rig",
	"Roblox",
	"Moon",
} :: {Location}

Saver.LocationLabels = {
	Rig = "Rig > AnimSaves",
	Roblox = "ServerStorage > AnimSaves",
	Moon = "ServerStorage > MoonAnimatorExport",
}

const function HasKeyBelow(Current: Clip.Clip, Joint: Rig.Joint, Time: number): boolean
	if Clip.FindKey(Current, Joint.Name, Time) then
		return true
	end

	for _, Child in Joint.Children do
		if HasKeyBelow(Current, Child, Time) then
			return true
		end
	end

	return false
end

const CurveNative = {
	Linear = true,
	Constant = true,
	Cubic = true,
}

function Saver.Baked(Current: Clip.Clip, FrameRate: number, ForCurves: boolean?): Clip.Clip
	local Edited = Current
	const Native = if ForCurves then CurveNative else Easing.Native

	for Name, Track in Clip.JointTracks(Current) do
		const Last = Track.Keys[#Track.Keys]

		if Last and not Native[Last.EasingStyle] then
			Edited = Clip.SetKey(Edited, Name, {
				Time = Last.Time,
				Value = Last.Value,
				EasingStyle = "Linear",
				EasingDirection = "In",
			})
		end

		for Index = 1, #Track.Keys - 1 do
			const From = Track.Keys[Index]
			const To = Track.Keys[Index + 1]

			if Native[From.EasingStyle] then
				continue
			end

			const Steps = math.floor((To.Time - From.Time) * FrameRate)

			for Step = 1, Steps - 1 do
				const Time = From.Time + Step / FrameRate

				Edited = Clip.SetKey(Edited, Name, {
					Time = Time,
					Value = Pose.SampleTrack(Track, Time),
					EasingStyle = "Linear",
					EasingDirection = "In",
				})
			end

			const _, Placed = Clip.FindKey(Edited, Name, From.Time)

			if Placed then
				Edited = Clip.SetKey(Edited, Name, {
					Time = From.Time,
					Value = From.Value,
					EasingStyle = "Linear",
					EasingDirection = "In",
				})
			end
		end
	end

	return Edited
end

const function WritePose(Current: Clip.Clip, Joint: Rig.Joint, Time: number, Parent: Instance)
	const Key = Clip.FindKey(Current, Joint.Name, Time)
	const Written = Templates.Pose:Clone()

	Written.Name = Joint.Name
	Written.Weight = if Key then 1 else 0
	Written.CFrame = if Key then Key.Value else CFrame.identity
	Written.EasingStyle = if not Key then Enum.PoseEasingStyle.Linear elseif Key.EasingStyle == "Cubic" then Enum.PoseEasingStyle.CubicV2 else (Enum.PoseEasingStyle :: any)[Key.EasingStyle]
	Written.EasingDirection = if Key then (Enum.PoseEasingDirection :: any)[Key.EasingDirection] else Enum.PoseEasingDirection.In
	Written.Parent = Parent

	for _, Child in Joint.Children do
		if HasKeyBelow(Current, Child, Time) then
			WritePose(Current, Child, Time, Written)
		end
	end
end

function Saver.ToSequence(Source: Clip.Clip, Loaded: Rig.Rig, FrameRate: number): KeyframeSequence
	const Current = Saver.Baked(Source, FrameRate)
	const Sequence = Templates.Sequence:Clone()

	Sequence.Name = Current.Name
	Sequence.Loop = Current.Looping
	Sequence.Priority = (Enum.AnimationPriority :: any)[Current.Priority]

	const Times = {}
	const Seen: {[number]: boolean} = {}

	for Name, Track in Clip.JointTracks(Current) do
		for _, Key in Track.Keys do
			const Rounded = math.round(Key.Time * 10000) / 10000

			if not Seen[Rounded] then
				Seen[Rounded] = true
				table.insert(Times, Rounded)
			end
		end
	end

	for _, Marker in Current.Markers do
		const Rounded = math.round(Marker.Time * 10000) / 10000

		if not Seen[Rounded] then
			Seen[Rounded] = true
			table.insert(Times, Rounded)
		end
	end

	if Current.Length > (Times[#Times] or 0) + 0.0005 then
		table.insert(Times, Current.Length)
	end

	table.sort(Times)

	if #Times == 0 then
		table.insert(Times, 0)
	end

	for _, Time in Times do
		const Keyframe = Templates.Keyframe:Clone()

		Keyframe.Name = `Keyframe {Time}`
		Keyframe.Time = Time

		const RootPose = Templates.Pose:Clone()

		RootPose.Name = Loaded.Root.Name
		RootPose.Weight = 1
		RootPose.Parent = Keyframe

		for _, Joint in Loaded.Joints do
			if Joint.Parent == nil and HasKeyBelow(Current, Joint, Time) then
				WritePose(Current, Joint, Time, RootPose)
			end
		end

		for _, Marker in Current.Markers do
			if math.abs(Marker.Time - Time) >= 0.0005 then
				continue
			end

			const Written = Templates.Marker:Clone()

			Written.Name = Marker.Name
			Written.Value = Marker.Value
			Written.Parent = Keyframe
		end

		Keyframe.Parent = Sequence
	end

	Saver.AttachProperties(Sequence, Current)

	return Sequence
end

const function Interpolation(Key: Clip.Key): Enum.KeyInterpolationMode
	if Key.EasingStyle == "Linear" then
		return Enum.KeyInterpolationMode.Linear
	end

	if Key.EasingStyle == "Constant" then
		return Enum.KeyInterpolationMode.Constant
	end

	return Enum.KeyInterpolationMode.Cubic
end

const function FillCurve(Curve: FloatCurve, Keys: {Clip.Key}, Read: (any) -> number)
	const Made = {}

	for Index, Key in Keys do
		const Value = Read(Key.Value)
		const Mode = Interpolation(Key)
		const Written = FloatCurveKey.new(Key.Time, Value, Mode)

		if Mode == Enum.KeyInterpolationMode.Cubic then
			const Next = Keys[Index + 1]
			const Previous = Keys[Index - 1]
			const OutSlope = if Next then (Read(Next.Value) - Value) / math.max(Next.Time - Key.Time, 0.0001) else 0
			const InSlope = if Previous then (Value - Read(Previous.Value)) / math.max(Key.Time - Previous.Time, 0.0001) else 0

			Written.RightTangent = OutSlope * Easing.Slope(Key.EasingStyle, Key.EasingDirection, true)
			Written.LeftTangent = if Previous and Interpolation(Previous) == Enum.KeyInterpolationMode.Cubic then InSlope * Easing.Slope(Previous.EasingStyle, Previous.EasingDirection, false) else InSlope
		end

		table.insert(Made, Written)
	end

	Curve:SetKeys(Made)
end

const function WriteCurveFolder(Current: Clip.Clip, Joint: Rig.Joint, Parent: Instance)
	const Folder = Templates.Folder:Clone()

	Folder.Name = Joint.Name

	const Track = Current.Tracks[Joint.Name]

	if Track and #Track.Keys > 0 then
		const Position = Templates.Position:Clone()
		const Rotation = Templates.Rotation:Clone()

		Rotation.RotationOrder = Enum.RotationOrder.XYZ

		const Angles = {}

		for _, Key in Track.Keys do
			const X, Y, Z = (Key.Value :: CFrame):ToEulerAnglesXYZ()

			Angles[Key] = Vector3.new(X, Y, Z)
		end

		FillCurve(Position:X(), Track.Keys, function(Value: CFrame)
			return Value.X
		end)
		FillCurve(Position:Y(), Track.Keys, function(Value: CFrame)
			return Value.Y
		end)
		FillCurve(Position:Z(), Track.Keys, function(Value: CFrame)
			return Value.Z
		end)

		local Unwrapped = {}
		local Previous: Vector3?

		for _, Key in Track.Keys do
			local Angle = Angles[Key]

			if Previous then
				const function Near(Value: number, Reference: number): number
					local Adjusted = Value

					while Adjusted - Reference > math.pi do
						Adjusted -= 2 * math.pi
					end

					while Reference - Adjusted > math.pi do
						Adjusted += 2 * math.pi
					end

					return Adjusted
				end

				Angle = Vector3.new(Near(Angle.X, Previous.X), Near(Angle.Y, Previous.Y), Near(Angle.Z, Previous.Z))
			end

			Unwrapped[Key] = Angle
			Previous = Angle
		end

		const function FillAxis(Curve: FloatCurve, Axis: string)
			const Made = {}

			for Index, Key in Track.Keys do
				const Value = (Unwrapped[Key] :: any)[Axis]
				const Mode = Interpolation(Key)
				const Written = FloatCurveKey.new(Key.Time, Value, Mode)

				if Mode == Enum.KeyInterpolationMode.Cubic then
					const Next = Track.Keys[Index + 1]
					const Before = Track.Keys[Index - 1]
					const OutSlope = if Next then ((Unwrapped[Next] :: any)[Axis] - Value) / math.max(Next.Time - Key.Time, 0.0001) else 0
					const InSlope = if Before then (Value - (Unwrapped[Before] :: any)[Axis]) / math.max(Key.Time - Before.Time, 0.0001) else 0

					Written.RightTangent = OutSlope * Easing.Slope(Key.EasingStyle, Key.EasingDirection, true)
					Written.LeftTangent = if Before and Interpolation(Before) == Enum.KeyInterpolationMode.Cubic then InSlope * Easing.Slope(Before.EasingStyle, Before.EasingDirection, false) else InSlope
				end

				table.insert(Made, Written)
			end

			Curve:SetKeys(Made)
		end

		FillAxis(Rotation:X(), "X")
		FillAxis(Rotation:Y(), "Y")
		FillAxis(Rotation:Z(), "Z")

		Position.Parent = Folder
		Rotation.Parent = Folder
	end

	for _, Child in Joint.Children do
		WriteCurveFolder(Current, Child, Folder)
	end

	Folder.Parent = Parent
end

function Saver.ToCurve(Source: Clip.Clip, Loaded: Rig.Rig, FrameRate: number, Emote: boolean?): CurveAnimation
	const Current = Saver.Baked(Source, FrameRate, true)
	const Curve = Templates.Curve:Clone()

	Curve.Name = Current.Name
	Curve.Loop = Current.Looping
	Curve.Priority = (Enum.AnimationPriority :: any)[Current.Priority]

	const RootFolder = Templates.Folder:Clone()

	RootFolder.Name = Loaded.Root.Name

	for _, Joint in Loaded.Joints do
		if Joint.Parent == nil then
			WriteCurveFolder(Current, Joint, RootFolder)
		end
	end

	RootFolder.Parent = Curve

	if #Current.Markers > 0 then
		const Markers = Templates.Markers:Clone()

		Markers.Name = "NamedKeyframeEvent"

		for _, Marker in Current.Markers do
			Markers:InsertMarkerAtTime(Marker.Time, Marker.Name)
		end

		Markers.Parent = Curve
	end

	if Emote and script.Parent:FindFirstChild("EmoteRigData") then
		const RigData = script.Parent.EmoteRigData:Clone()

		RigData.Name = "RigAnimationRigData"
		RigData.Parent = Curve
	end

	Saver.AttachProperties(Curve, Current)

	return Curve
end

const function ReadPose(Current: Clip.Clip, Read: Pose, Time: number): Clip.Clip
	local Edited = Current

	if Read.Weight > 0 then
		const LegacyCubic = Read.EasingStyle == Enum.PoseEasingStyle.Cubic
		const Swapped = if Read.EasingDirection == Enum.PoseEasingDirection.In then "Out" elseif Read.EasingDirection == Enum.PoseEasingDirection.Out then "In" else "InOut"

		Edited = Clip.SetKey(Edited, Read.Name, {
			Time = Time,
			Value = Read.CFrame,
			EasingStyle = if Read.EasingStyle == Enum.PoseEasingStyle.CubicV2 then "Cubic" else Read.EasingStyle.Name :: any,
			EasingDirection = if LegacyCubic then Swapped else Read.EasingDirection.Name :: any,
		})
	end

	for _, Child in Read:GetChildren() do
		if Child:IsA("Pose") then
			Edited = ReadPose(Edited, Child, Time)
		end
	end

	return Edited
end

const function Finish(Read: Clip.Clip, Length: number, Loaded: Rig.Rig, Source: Instance): (Clip.Clip?, string?)
	Read.Length = math.max(Length, 0.01)

	const Unknown = {}

	for Name in Clip.JointTracks(Read) do
		if not Loaded.ByName[Name] then
			table.insert(Unknown, Name)
		end
	end

	const WithProperties = Saver.ReadProperties(Source, Read)
	const Checked = ClipSchema.parse(WithProperties)

	if not Checked.ok then
		return nil, ClipSchema.Describe(Checked.issues)
	end

	return WithProperties, if #Unknown > 0 then `Ignored joints this rig does not have: {table.concat(Unknown, ", ")}` else nil
end

function Saver.FromSequence(Sequence: KeyframeSequence, Loaded: Rig.Rig): (Clip.Clip?, string?)
	local Read = Clip.New(Sequence.Name)

	Read.Looping = Sequence.Loop
	Read.Priority = if table.find(Clip.Priorities, Sequence.Priority.Name) then Sequence.Priority.Name else "Action"

	local Length = 0

	for _, Keyframe in Sequence:GetChildren() do
		if not Keyframe:IsA("Keyframe") then
			continue
		end

		Length = math.max(Length, Keyframe.Time)

		for _, Child in Keyframe:GetChildren() do
			if Child:IsA("Pose") then
				if Child.Name == Loaded.Root.Name then
					for _, Under in Child:GetChildren() do
						if Under:IsA("Pose") then
							Read = ReadPose(Read, Under, Keyframe.Time)
						end
					end
				else
					Read = ReadPose(Read, Child, Keyframe.Time)
				end
			elseif Child:IsA("KeyframeMarker") then
				Read = Clip.SetMarker(Read, {
					Time = Keyframe.Time,
					Name = Child.Name,
					Value = Child.Value,
				})
			end
		end
	end

	return Finish(Read, Length, Loaded, Sequence)
end

const function ReadCurveFolder(Current: Clip.Clip, Folder: Instance, Length: number): (Clip.Clip, number)
	local Edited = Current
	local Longest = Length
	const Position = Folder:FindFirstChild("Position")
	const Rotation = Folder:FindFirstChild("Rotation")

	if (Position and Position:IsA("Vector3Curve")) or (Rotation and (Rotation:IsA("EulerRotationCurve") or Rotation:IsA("RotationCurve"))) then
		const Seen: {[number]: Enum.KeyInterpolationMode} = {}
		const Times = {}

		const function Note(Curve: Instance?)
			if not Curve then
				return
			end

			const Floats: {FloatCurve} = if Curve:IsA("FloatCurve") then {Curve :: FloatCurve} else {}

			for _, Child in Curve:GetChildren() do
				if Child:IsA("FloatCurve") then
					table.insert(Floats, Child)
				end
			end

			for _, Float in Floats do
				for _, Key in Float:GetKeys() do
					const Rounded = math.round(Key.Time * 10000) / 10000

					if not Seen[Rounded] then
						table.insert(Times, Rounded)
					end

					Seen[Rounded] = if Seen[Rounded] == Enum.KeyInterpolationMode.Cubic then Seen[Rounded] else Key.Interpolation
				end
			end

			if Curve:IsA("RotationCurve") then
				for _, Key in Curve:GetKeys() do
					const Rounded = math.round(Key.Time * 10000) / 10000

					if not Seen[Rounded] then
						table.insert(Times, Rounded)
					end

					Seen[Rounded] = Key.Interpolation
				end
			end
		end

		Note(Position)
		Note(Rotation)
		table.sort(Times)

		for _, Time in Times do
			const Offset = if Position and Position:IsA("Vector3Curve") then Vector3.new(unpack(Position:GetValueAtTime(Time))) else Vector3.zero
			local Turn = CFrame.identity

			if Rotation and Rotation:IsA("EulerRotationCurve") then
				Turn = Rotation:GetRotationAtTime(Time)
			elseif Rotation and Rotation:IsA("RotationCurve") then
				Turn = Rotation:GetValueAtTime(Time) or CFrame.identity
			end

			const Mode = Seen[Time]

			Edited = Clip.SetKey(Edited, Folder.Name, {
				Time = Time,
				Value = Turn + Offset,
				EasingStyle = if Mode == Enum.KeyInterpolationMode.Constant then "Constant" elseif Mode == Enum.KeyInterpolationMode.Cubic then "Cubic" else "Linear",
				EasingDirection = "InOut",
			})
			Longest = math.max(Longest, Time)
		end
	end

	for _, Child in Folder:GetChildren() do
		if Child:IsA("Folder") and Child.Name ~= "FaceControls" then
			Edited, Longest = ReadCurveFolder(Edited, Child, Longest)
		end
	end

	return Edited, Longest
end

function Saver.FromCurve(Curve: CurveAnimation, Loaded: Rig.Rig): (Clip.Clip?, string?)
	local Read = Clip.New(Curve.Name)

	Read.Looping = Curve.Loop
	Read.Priority = if table.find(Clip.Priorities, Curve.Priority.Name) then Curve.Priority.Name else "Action"

	local Length = 0

	for _, Child in Curve:GetChildren() do
		if Child:IsA("Folder") then
			if Child.Name == Loaded.Root.Name then
				for _, Under in Child:GetChildren() do
					if Under:IsA("Folder") then
						Read, Length = ReadCurveFolder(Read, Under, Length)
					end
				end
			else
				Read, Length = ReadCurveFolder(Read, Child, Length)
			end
		elseif Child:IsA("MarkerCurve") then
			for _, Marker in Child:GetMarkers() do
				Read = Clip.SetMarker(Read, {
					Time = Marker.Time,
					Name = Marker.Value,
					Value = "",
				})
				Length = math.max(Length, Marker.Time)
			end
		end
	end

	return Finish(Read, Length, Loaded, Curve)
end

function Saver.FromInstance(Source: Instance, Loaded: Rig.Rig): (Clip.Clip?, string?)
	if Source:IsA("KeyframeSequence") then
		return Saver.FromSequence(Source, Loaded)
	end

	if Source:IsA("CurveAnimation") then
		return Saver.FromCurve(Source, Loaded)
	end

	return nil, `{Source.Name} is not an animation`
end

const function Encode(Value: any): any
	const Kind: string = typeof(Value)

	local Data: any = Value

	if Kind == "CFrame" then
		Data = {(Value :: CFrame):GetComponents()}
	elseif Kind == "Vector3" then
		Data = {Value.X, Value.Y, Value.Z}
	elseif Kind == "Vector2" then
		Data = {Value.X, Value.Y}
	elseif Kind == "Color3" then
		Data = {Value.R, Value.G, Value.B}
	elseif Kind == "UDim2" then
		Data = {Value.X.Scale, Value.X.Offset, Value.Y.Scale, Value.Y.Offset}
	elseif Kind == "EnumItem" then
		Data = {tostring(Value.EnumType), Value.Name}
	end

	return {Kind, Data}
end

const function Decode(Stored: any): any
	const Kind = Stored[1]
	const Data = Stored[2]

	if Kind == "CFrame" then
		return CFrame.new(unpack(Data))
	end

	if Kind == "Vector3" then
		return Vector3.new(Data[1], Data[2], Data[3])
	end

	if Kind == "Vector2" then
		return Vector2.new(Data[1], Data[2])
	end

	if Kind == "Color3" then
		return Color3.new(Data[1], Data[2], Data[3])
	end

	if Kind == "UDim2" then
		return UDim2.new(Data[1], Data[2], Data[3], Data[4])
	end

	if Kind == "EnumItem" then
		return (Enum :: any)[Data[1]][Data[2]]
	end

	return Data
end

function Saver.AttachProperties(Target: Instance, Current: Clip.Clip)
	const Tracks = {}
	local Count = 0

	for Name, Track in Current.Tracks do
		if not Clip.IsProperty(Name) or not Track.Object or not Track.Property then
			continue
		end

		const Keys = {}

		for _, Key in Track.Keys do
			table.insert(Keys, {
				Time = Key.Time,
				Value = Encode(Key.Value),
				EasingStyle = Key.EasingStyle,
				EasingDirection = Key.EasingDirection,
			})
		end

		const Link = Templates.RigLink:Clone()

		Link.Name = `Property{Count + 1}`
		Link.Value = Track.Object
		Link:SetAttribute("Property", Track.Property)
		Link:SetAttribute("Keys", HttpService:JSONEncode(Keys))
		table.insert(Tracks, Link)
		Count += 1
	end

	for _, Link in Tracks do
		Link.Parent = Target
	end
end

function Saver.ReadProperties(Source: Instance, Current: Clip.Clip): Clip.Clip
	local Edited = Current

	for _, Child in Source:GetChildren() do
		if not Child:IsA("ObjectValue") or not Child:GetAttribute("Property") or not Child.Value then
			continue
		end

		const Object = Child.Value :: Instance
		const Property = Child:GetAttribute("Property") :: string
		const Ok, Keys = pcall(HttpService.JSONDecode, HttpService, Child:GetAttribute("Keys") :: string)

		if not Ok then
			continue
		end

		for _, Key in Keys do
			Edited = Clip.SetKey(Edited, Clip.PropertyTrackName(Object, Property), {
				Time = Key.Time,
				Value = Decode(Key.Value),
				EasingStyle = Key.EasingStyle,
				EasingDirection = Key.EasingDirection,
			}, Object, Property)
		end
	end

	return Edited
end

const function RobloxFolder(Loaded: Rig.Rig, Create: boolean): Instance?
	local Root = ServerStorage:FindFirstChild("AnimSaves")

	if not Root and not Create then
		return nil
	end

	if not Root then
		Root = Templates.AnimSaves:Clone()
		Root.Parent = ServerStorage
	end

	for _, Child in Root:GetChildren() do
		for _, Link in Child:GetChildren() do
			if Link:IsA("ObjectValue") and Link.Value == Loaded.Model then
				return Child
			end
		end

		if Child.Name == Loaded.Model.Name and not Child:FindFirstChildOfClass("ObjectValue") then
			return Child
		end
	end

	if not Create then
		return nil
	end

	const Made = Templates.Folder:Clone()

	Made.Name = Loaded.Model.Name

	const Link = Templates.RigLink:Clone()

	Link.Name = "Rig"
	Link.Value = Loaded.Model
	Link.Parent = Made
	Made.Parent = Root

	return Made
end

function Saver.Folder(Loaded: Rig.Rig, Where: Location, Create: boolean): Instance?
	if Where == "Roblox" then
		return RobloxFolder(Loaded, Create)
	end

	if Where == "Moon" then
		const Found = ServerStorage:FindFirstChild("MoonAnimatorExport") or ServerStorage:FindFirstChild("MoonAnimatorSaves")

		if Found or not Create then
			return Found
		end

		const Made = Templates.Folder:Clone()

		Made.Name = "MoonAnimatorExport"
		Made.Parent = ServerStorage

		return Made
	end

	const Existing = Loaded.Model:FindFirstChild("AnimSaves")

	if Existing or not Create then
		return Existing
	end

	const Made = Templates.AnimSaves:Clone()

	Made.Parent = Loaded.Model

	return Made
end

function Saver.List(Loaded: Rig.Rig): {{Animation: Instance, Where: Location}}
	const Found: {{Animation: Instance, Where: Location}} = {}

	for _, Where in Saver.Locations do
		const Folder = Saver.Folder(Loaded, Where :: Location, false)

		if not Folder then
			continue
		end

		for _, Child in Folder:GetChildren() do
			if Child:IsA("KeyframeSequence") or Child:IsA("CurveAnimation") then
				table.insert(Found, {Animation = Child :: Instance, Where = Where :: Location})
			end
		end
	end

	table.sort(Found, function(A, B)
		return A.Animation.Name < B.Animation.Name
	end)

	return Found
end

function Saver.Save(Current: Clip.Clip, Loaded: Rig.Rig, Where: Location, AsCurve: boolean, FrameRate: number): Instance
	const Folder = Saver.Folder(Loaded, Where, true) :: Instance
	const Written: Instance = if AsCurve then Saver.ToCurve(Current, Loaded, FrameRate, false) else Saver.ToSequence(Current, Loaded, FrameRate)

	for _, Child in Folder:GetChildren() do
		if (Child:IsA("KeyframeSequence") or Child:IsA("CurveAnimation")) and Child.Name == Current.Name then
			Child:Destroy()
		end
	end

	Written.Parent = Folder
	ChangeHistoryService:SetWaypoint(`Save animation {Current.Name}`)

	return Written
end

function Saver.Convert(Source: Instance, Loaded: Rig.Rig, FrameRate: number): (Instance?, string?)
	const Read, Problem = Saver.FromInstance(Source, Loaded)

	if not Read then
		return nil, Problem
	end

	if Problem then
		return nil, `Not converted, that animation has joints {Loaded.Model.Name} does not: load the rig it was made for first`
	end

	const Made: Instance = if Source:IsA("KeyframeSequence") then Saver.ToCurve(Read, Loaded, FrameRate, false) else Saver.ToSequence(Read, Loaded, FrameRate)

	Made.Name = Source.Name
	Made.Parent = Source.Parent
	Source:Destroy()
	ChangeHistoryService:SetWaypoint(`Convert animation {Made.Name}`)

	return Made, Problem
end

function Saver.Publish(Current: Clip.Clip, Loaded: Rig.Rig, CurrentPlugin: Plugin, Where: Location, AsCurve: boolean, FrameRate: number)
	const Written = Saver.Save(Current, Loaded, Where, AsCurve, FrameRate)

	Selection:Set({Written})
	CurrentPlugin:SaveSelectedToRoblox()
end

function Saver.EmoteExport(Current: Clip.Clip, Loaded: Rig.Rig, FrameRate: number, ThumbnailTime: number, Rotation: number): Instance
	const Folder = Saver.Folder(Loaded, "Rig", true) :: Instance
	const Curve = Saver.ToCurve(Current, Loaded, FrameRate, true)

	Curve.Name = `{Current.Name} emote`

	for _, Child in Folder:GetChildren() do
		if Child.Name == Curve.Name then
			Child:Destroy()
		end
	end

	for Name, Value in {
		ThumbnailTime = ThumbnailTime,
		ThumbnailKeyframe = math.round(ThumbnailTime * FrameRate),
		ThumbnailCharacterRotation = Rotation,
	} do
		const Number = Templates.Number:Clone()

		Number.Name = Name
		Number.Value = Value
		Number.Parent = Curve
	end

	Curve.Parent = Folder
	ChangeHistoryService:SetWaypoint(`Export emote {Current.Name}`)

	return Curve
end

function Saver.Import(AssetId: number): (Instance?, string?)
	const Fetched, Result = pcall(AnimationClipProvider.GetAnimationClipAsync, AnimationClipProvider, `rbxassetid://{AssetId}`)

	if Fetched and Result and (Result:IsA("KeyframeSequence") or Result:IsA("CurveAnimation")) then
		return Result, nil
	end

	const Again, Sequence = pcall(KeyframeSequenceProvider.GetKeyframeSequenceAsync, KeyframeSequenceProvider, `rbxassetid://{AssetId}`)

	if not Again then
		return nil, `Could not fetch animation {AssetId}: {Sequence}`
	end

	if not Sequence or not Sequence:IsA("KeyframeSequence") then
		return nil, `Asset {AssetId} is not an animation`
	end

	return Sequence, nil
end

return Saver