--!strict
const KeyframeSequenceProvider = game:GetService("KeyframeSequenceProvider")
const Selection = game:GetService("Selection")
const Clip = require(script.Parent.Clip)
const Rig = require(script.Parent.Rig)
const ClipSchema = require(script.Parent.ClipSchema)

const Templates = script.Templates

const Saver = {}

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

function Saver.ToSequence(Current: Clip.Clip, Loaded: Rig.Rig): KeyframeSequence
	const Sequence = Templates.Sequence:Clone()

	Sequence.Name = Current.Name
	Sequence.Loop = Current.Looping
	Sequence.Priority = (Enum.AnimationPriority :: any)[Current.Priority]

	const Times = Clip.KeyTimes(Current)
	const Seen: {[number]: boolean} = {}

	for _, Time in Times do
		Seen[Time] = true
	end

	for _, Marker in Current.Markers do
		const Rounded = math.round(Marker.Time * 10000) / 10000

		if not Seen[Rounded] then
			Seen[Rounded] = true
			table.insert(Times, Rounded)
		end
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

	return Sequence
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

function Saver.FromSequence(Sequence: KeyframeSequence, Loaded: Rig.Rig): (Clip.Clip?, string?)
	local Read = Clip.New(Sequence.Name)

	Read.Looping = Sequence.Loop
	Read.Priority = Sequence.Priority.Name

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

	Read.Length = math.max(Length, 0.01)

	const Unknown = {}

	for Name in Read.Tracks do
		if not Loaded.ByName[Name] then
			table.insert(Unknown, Name)
		end
	end

	const Checked = ClipSchema.parse(Read)

	if not Checked.ok then
		return nil, ClipSchema.Describe(Checked.issues)
	end

	return Read, if #Unknown > 0 then `Ignored joints this rig does not have: {table.concat(Unknown, ", ")}` else nil
end

function Saver.SavesFolder(Loaded: Rig.Rig, Create: boolean): Instance?
	const Existing = Loaded.Model:FindFirstChild("AnimSaves")

	if Existing or not Create then
		return Existing
	end

	const Made = Templates.AnimSaves:Clone()

	Made.Parent = Loaded.Model

	return Made
end

function Saver.List(Loaded: Rig.Rig): {KeyframeSequence}
	const Folder = Saver.SavesFolder(Loaded, false)
	const Found = {}

	if not Folder then
		return Found
	end

	for _, Child in Folder:GetChildren() do
		if Child:IsA("KeyframeSequence") then
			table.insert(Found, Child)
		end
	end

	table.sort(Found, function(A: KeyframeSequence, B: KeyframeSequence)
		return A.Name < B.Name
	end)

	return Found
end

function Saver.Save(Current: Clip.Clip, Loaded: Rig.Rig): KeyframeSequence
	const Folder = Saver.SavesFolder(Loaded, true) :: Instance
	const Sequence = Saver.ToSequence(Current, Loaded)

	for _, Child in Folder:GetChildren() do
		if Child:IsA("KeyframeSequence") and Child.Name == Current.Name then
			Child:Destroy()
		end
	end

	Sequence.Parent = Folder

	return Sequence
end

function Saver.Publish(Current: Clip.Clip, Loaded: Rig.Rig, CurrentPlugin: Plugin)
	const Sequence = Saver.Save(Current, Loaded)

	Selection:Set({Sequence})
	CurrentPlugin:SaveSelectedToRoblox()
end

function Saver.Import(AssetId: number): (KeyframeSequence?, string?)
	const Fetched, Result = pcall(KeyframeSequenceProvider.GetKeyframeSequenceAsync, KeyframeSequenceProvider, `rbxassetid://{AssetId}`)

	if not Fetched then
		return nil, `Could not fetch animation {AssetId}: {Result}`
	end

	if not Result or not Result:IsA("KeyframeSequence") then
		return nil, `Asset {AssetId} is not an animation`
	end

	return Result, nil
end

return Saver