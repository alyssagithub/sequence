--!strict
const RunService = game:GetService("RunService")
const Selection = game:GetService("Selection")
const UserInputService = game:GetService("UserInputService")
const ChangeHistoryService = game:GetService("ChangeHistoryService")
const Vide = require(script.Parent.Parent.Packages.vide)
const Sift = require(script.Parent.Parent.Packages.sift)
const Clip = require(script.Parent.Clip)
const Rig = require(script.Parent.Rig)
const Pose = require(script.Parent.Pose)
const Ik = require(script.Parent.Ik)
const Emote = require(script.Parent.Emote)

export type KeyRef = {
	Joint: string,
	Time: number,
}

export type Entry = {
	Model: Model,
	Loaded: Rig.Rig,
	Clip: Clip.Clip,
	Connections: {RBXScriptConnection},
}

type Snapshot = {
	Active: Model?,
	Clips: {[Model]: Clip.Clip},
}

const Session = {
	Rig = Vide.source(nil :: Rig.Rig?),
	Rigs = Vide.source({} :: {Entry}),
	Current = Vide.source(Clip.New("Animation")),
	Time = Vide.source(0),
	Playing = Vide.source(false),
	Speed = Vide.source(1),
	FrameRate = Vide.source(30),
	Snap = Vide.source(true),
	SelectedJoint = Vide.source(nil :: string?),
	SelectedKeys = Vide.source({} :: {KeyRef}),
	Clipboard = Vide.source({} :: {{Joint: string, Offset: number, Key: Clip.Key}}),
	Tool = Vide.source("Rotate" :: "Rotate" | "Move"),
	OnionSkin = Vide.source(false),
	AutoKey = Vide.source(true),
	Pins = Vide.source({} :: {[string]: CFrame}),
	Scratch = Vide.source({} :: {[string]: CFrame}),
	Dirty = Vide.source(false),
	Notice = Vide.source(""),
	UndoCount = Vide.source(0),
	RedoCount = Vide.source(0),
	ImportPrompt = Vide.source(false),
	SelectedMarker = Vide.source(nil :: Clip.Marker?),
	Confirming = Vide.source(nil :: string?),
	Collapsed = Vide.source({} :: {[string]: boolean}),
	View = Vide.source("Sheet" :: "Sheet" | "Curves"),
	Panel = Vide.source(nil :: string?),
	EmoteChecks = Vide.source(false),
	Problems = Vide.source({} :: {Emote.Problem}),
	Plugin = nil :: Plugin?,
}

const Undo: {Snapshot} = {}
const Redo: {Snapshot} = {}
local LastMergeKey: string?
local Heartbeat: RBXScriptConnection?
local SelectionConnection: RBXScriptConnection?
local ReleaseConnection: RBXScriptConnection?
local HistoryConnections: {RBXScriptConnection} = {}
local NoticeToken = 0
local ConfirmToken = 0
local Applying = false
local Reapplying = false
local LastKeyboard = 0
const Parked: {[Model]: Clip.Clip} = {}

function Session.Say(Text: string)
	NoticeToken += 1
	Session.Notice(Text)

	const Token = NoticeToken

	task.delay(4, function()
		if NoticeToken == Token then
			Session.Notice("")
		end
	end)
end

function Session.Entry(Model: Model?): Entry?
	const Loaded = Session.Rig()

	for _, Found in Session.Rigs() do
		if Found.Model == (Model or (Loaded and Loaded.Model)) then
			return Found
		end
	end

	return nil
end

function Session.EntryOfJoint(JointName: string): Entry?
	for _, Found in Session.Rigs() do
		if Found.Loaded.ByName[JointName] then
			return Found
		end
	end

	return nil
end

function Session.SnapTime(Time: number): number
	const Clamped = math.clamp(Time, 0, Session.SceneLength())

	if not Session.Snap() then
		return Clamped
	end

	return math.round(Clamped * Session.FrameRate()) / Session.FrameRate()
end

function Session.ToFrame(Time: number): number
	if not Session.Snap() then
		return math.max(0, Time)
	end

	return math.max(0, math.round(Time * Session.FrameRate()) / Session.FrameRate())
end

function Session.Confirm(Label: string, Action: () -> ())
	if not Session.Dirty() or Session.Confirming() == Label then
		Session.Confirming(nil)
		Action()

		return
	end

	ConfirmToken += 1
	Session.Confirming(Label)
	Session.Say(`Unsaved changes will be lost, press {Label} again to go ahead`)

	const Token = ConfirmToken

	task.delay(5, function()
		if ConfirmToken == Token then
			Session.Confirming(nil)
		end
	end)
end

function Session.EndMerge()
	LastMergeKey = nil
end

const function Prune(Current: Clip.Clip)
	const Kept = Sift.Array.filter(Session.SelectedKeys(), function(Ref: KeyRef)
		return Clip.FindKey(Current, Ref.Joint, Ref.Time) ~= nil
	end)

	if #Kept ~= #Session.SelectedKeys() then
		Session.SelectedKeys(Kept)
	end

	const Marker = Session.SelectedMarker()

	if Marker and not table.find(Current.Markers, Marker) then
		Session.SelectedMarker(Clip.FindMarker(Current, Marker.Time, Marker.Name))
	end
end

const function TakeSnapshot(): Snapshot
	const Clips = {}
	const Active = Session.Rig()

	for _, Found in Session.Rigs() do
		Clips[Found.Model] = if Active and Found.Model == Active.Model then Session.Current() else Found.Clip
	end

	return {
		Active = if Active then Active.Model else nil,
		Clips = Clips,
	}
end

const function RestoreSnapshot(Snapshot: Snapshot)
	for _, Found in Session.Rigs() do
		const Stored = Snapshot.Clips[Found.Model]

		if Stored then
			Found.Clip = Stored
		end
	end

	const Active = Session.Rig()

	if Active and Snapshot.Clips[Active.Model] then
		Session.Current(Snapshot.Clips[Active.Model])
		Prune(Snapshot.Clips[Active.Model])
	end
end

function Session.Edit(NewClip: Clip.Clip, MergeKey: string?)
	if NewClip == Session.Current() then
		return
	end

	if MergeKey == nil or MergeKey ~= LastMergeKey then
		table.insert(Undo, TakeSnapshot())

		if #Undo > 200 then
			table.remove(Undo, 1)
		end

		table.clear(Redo)
	end

	LastMergeKey = MergeKey
	Session.Current(NewClip)
	Prune(NewClip)
	Session.Dirty(true)
	Session.UndoCount(#Undo)
	Session.RedoCount(#Redo)
end

function Session.Undo()
	const Previous = table.remove(Undo)

	if not Previous then
		return
	end

	table.insert(Redo, TakeSnapshot())
	LastMergeKey = nil
	RestoreSnapshot(Previous)
	Session.Time(math.min(Session.Time(), Session.Current().Length))
	Session.UndoCount(#Undo)
	Session.RedoCount(#Redo)
end

function Session.Redo()
	const Next = table.remove(Redo)

	if not Next then
		return
	end

	table.insert(Undo, TakeSnapshot())
	LastMergeKey = nil
	RestoreSnapshot(Next)
	Session.UndoCount(#Undo)
	Session.RedoCount(#Redo)
end

function Session.Replace(NewClip: Clip.Clip)
	table.clear(Undo)
	table.clear(Redo)
	LastMergeKey = nil
	Session.Current(NewClip)
	Session.Time(0)
	Session.SelectedKeys({})
	Session.SelectedMarker(nil)
	Session.Scratch({})
	Session.Dirty(false)
	Session.UndoCount(0)
	Session.RedoCount(0)
end

function Session.SceneLength(): number
	local Length = Session.Current().Length

	for _, Found in Session.Rigs() do
		Length = math.max(Length, Found.Clip.Length)
	end

	return Length
end

function Session.Stop()
	Session.Playing(false)

	if not Heartbeat then
		return
	end

	Heartbeat:Disconnect()
	Heartbeat = nil
end

function Session.Play()
	if not Session.Rig() then
		return
	end

	if Session.Time() >= Session.SceneLength() then
		Session.Time(0)
	end

	Session.Playing(true)

	if Heartbeat then
		return
	end

	Heartbeat = RunService.Heartbeat:Connect(function(Delta: number)
		const Length = Session.SceneLength()
		const Next = Session.Time() + Delta * Session.Speed()

		if Next < Length then
			Session.Time(Next)

			return
		end

		if Session.Current().Looping and Length > 0 then
			Session.Time(Next % Length)

			return
		end

		Session.Time(Length)
		Session.Stop()
	end)
end

function Session.TogglePlay()
	if Session.Playing() then
		Session.Stop()
	else
		Session.Play()
	end
end

function Session.StepFrames(Frames: number)
	Session.Stop()
	Session.Time(math.clamp(math.round(Session.Time() * Session.FrameRate() + Frames) / Session.FrameRate(), 0, Session.SceneLength()))
end

function Session.Seek(Time: number)
	Session.Time(Session.SnapTime(Time))
end

function Session.KeyAt(TrackName: string, Time: number): Clip.Key?
	return Clip.FindKey(Session.Current(), TrackName, Time)
end

function Session.WriteKey(TrackName: string, Value: any, MergeKey: string?, Object: Instance?, Property: string?)
	const Time = Session.SnapTime(Session.Time())
	const Existing = Session.KeyAt(TrackName, Time)
	const Track = Session.Current().Tracks[TrackName]
	local Previous: Clip.Key?

	if Track then
		for _, Key in Track.Keys do
			if Key.Time < Time then
				Previous = Key
			end
		end
	end

	if Existing and typeof(Value) == "CFrame" and Existing.Value:FuzzyEq(Value, 0.00001) then
		return
	end

	if Existing and typeof(Value) ~= "CFrame" and Existing.Value == Value then
		return
	end

	const Style = if Existing then Existing.EasingStyle elseif Previous then Previous.EasingStyle else "Linear"
	const Direction = if Existing then Existing.EasingDirection elseif Previous then Previous.EasingDirection else "In"

	Session.Edit(Clip.SetKey(Session.Current(), TrackName, {
		Time = Time,
		Value = Value,
		EasingStyle = Style,
		EasingDirection = Direction,
	}, Object, Property), MergeKey)
end

function Session.PoseNow(): {[string]: CFrame}
	const Sampled = Pose.Sample(Session.Current(), Session.Time())

	for Name, Value in Session.Scratch() do
		Sampled[Name] = Value
	end

	return Sampled
end

const function SolvePins(Loaded: Rig.Rig, MovedName: string, Sampled: {[string]: CFrame}): {[string]: CFrame}
	local Solved = Sampled

	for PinName, Target in Session.Pins() do
		const Chain = Ik.Chain(Loaded, MovedName, PinName)

		if #Chain == 0 or PinName == MovedName then
			continue
		end

		Solved = Ik.Solve(Loaded, Solved, Chain, PinName, Target)
	end

	return Solved
end

function Session.SetJointTransform(JointName: string, Value: CFrame, MergeKey: string?)
	if Session.Time() ~= Session.SnapTime(Session.Time()) then
		Session.Time(Session.SnapTime(Session.Time()))
	end

	const Entry = Session.EntryOfJoint(JointName)
	const Sampled = Session.PoseNow()

	Sampled[JointName] = Value

	const Solved: {[string]: CFrame} = if Entry then SolvePins(Entry.Loaded, JointName, Sampled) else Sampled
	const Changed = {}

	for Name, Transform in Solved do
		const Pinned = Session.Pins()[Name] ~= nil and Entry ~= nil and #Ik.Chain(Entry.Loaded, JointName, Name) > 0

		if Name == JointName or not (Sampled[Name] or CFrame.identity):FuzzyEq(Transform, 0.0001) or Pinned then
			Changed[Name] = Transform
		end
	end

	if not Session.AutoKey() then
		const Scratch = table.clone(Session.Scratch())

		for Name, Transform in Changed do
			Scratch[Name] = Transform
		end

		Session.Scratch(Scratch)

		return
	end

	const Merge = MergeKey or `Pose {JointName}`

	Session.WriteKey(JointName, Value, Merge)

	for Name, Transform in Changed do
		if Name ~= JointName then
			Session.WriteKey(Name, Transform, Merge)
		end
	end
end

function Session.CommitScratch()
	const Scratch = Session.Scratch()

	if next(Scratch) == nil then
		return
	end

	for Name, Transform in Scratch do
		Session.WriteKey(Name, Transform, "CommitScratch")
	end

	LastMergeKey = nil
	Session.Scratch({})
end

function Session.AddKeys(JointNames: {string})
	const Loaded = Session.Rig()

	if not Loaded then
		return
	end

	const Sampled = Session.PoseNow()

	for _, Name in JointNames do
		Session.WriteKey(Name, Sampled[Name] or CFrame.identity, "AddKeys")
	end

	LastMergeKey = nil

	const Scratch = table.clone(Session.Scratch())

	for _, Name in JointNames do
		Scratch[Name] = nil
	end

	Session.Scratch(Scratch)
end

function Session.KeyAll()
	const Loaded = Session.Rig()

	if not Loaded then
		return
	end

	const Chosen = Session.SelectedJoint()

	if Chosen then
		Session.AddKeys({Chosen})

		return
	end

	const Names = {}

	for _, Joint in Loaded.Joints do
		table.insert(Names, Joint.Name)
	end

	Session.AddKeys(Names)
end

function Session.TogglePin(JointName: string)
	const Loaded = Session.Rig()
	const Pins = table.clone(Session.Pins())

	if Pins[JointName] then
		Pins[JointName] = nil
	elseif Loaded then
		Pins[JointName] = Ik.WorldOf(Loaded, Session.PoseNow(), JointName) or CFrame.identity
	end

	Session.Pins(Pins)
end

function Session.RefreshPins()
	const Loaded = Session.Rig()

	if not Loaded or next(Session.Pins()) == nil then
		return
	end

	const Pins = {}
	const Sampled = Session.PoseNow()

	for Name in Session.Pins() do
		Pins[Name] = Ik.WorldOf(Loaded, Sampled, Name) or CFrame.identity
	end

	Session.Pins(Pins)
end

function Session.MirrorPose(JointNames: {string}?)
	const Loaded = Session.Rig()

	if not Loaded then
		return
	end

	const Sampled = Session.PoseNow()
	const Names: {string} = JointNames or {}

	if not JointNames then
		for _, Joint in Loaded.Joints do
			table.insert(Names, Joint.Name)
		end
	end

	const Written: {[string]: boolean} = {}

	for _, Name in Names do
		const Other = Pose.MirrorName(Name)

		if Written[Name] or not Loaded.ByName[Other] then
			continue
		end

		const Mine = Sampled[Name] or CFrame.identity
		const Theirs = Sampled[Other] or CFrame.identity

		Session.WriteKey(Name, Pose.Mirror(Theirs), "Mirror")
		Session.WriteKey(Other, Pose.Mirror(Mine), "Mirror")
		Written[Name] = true
		Written[Other] = true
	end

	LastMergeKey = nil
end

function Session.DeleteSelectedKeys()
	local Edited = Session.Current()

	for _, Ref in Session.SelectedKeys() do
		Edited = Clip.RemoveKey(Edited, Ref.Joint, Ref.Time)
	end

	Session.Edit(Edited)
	Session.SelectedKeys({})
end

function Session.IsSelected(TrackName: string, Time: number): boolean
	for _, Ref in Session.SelectedKeys() do
		if Ref.Joint == TrackName and math.abs(Ref.Time - Time) < 0.0005 then
			return true
		end
	end

	return false
end

function Session.SelectKey(TrackName: string, Time: number, Add: boolean)
	if Add then
		if Session.IsSelected(TrackName, Time) then
			Session.SelectedKeys(Sift.Array.filter(Session.SelectedKeys(), function(Ref: KeyRef)
				return Ref.Joint ~= TrackName or math.abs(Ref.Time - Time) >= 0.0005
			end))
		else
			Session.SelectedKeys(Sift.Array.push(Session.SelectedKeys(), {Joint = TrackName, Time = Time}))
		end

		return
	end

	if Session.IsSelected(TrackName, Time) then
		return
	end

	Session.SelectedKeys({{Joint = TrackName, Time = Time}})
end

function Session.SelectColumn(Time: number, Add: boolean)
	const Refs = if Add then table.clone(Session.SelectedKeys()) else {}

	for Name, Track in Session.Current().Tracks do
		for _, Key in Track.Keys do
			if math.abs(Key.Time - Time) < 0.0005 and not (Add and Session.IsSelected(Name, Key.Time)) then
				table.insert(Refs, {Joint = Name, Time = Key.Time})
			end
		end
	end

	Session.SelectedKeys(Refs)
end

function Session.SelectBox(TrackNames: {string}, From: number, To: number, Add: boolean)
	const Refs = if Add then table.clone(Session.SelectedKeys()) else {}
	const Low = math.min(From, To)
	const High = math.max(From, To)

	for _, Name in TrackNames do
		const Track = Session.Current().Tracks[Name]

		if not Track then
			continue
		end

		for _, Key in Track.Keys do
			if Key.Time >= Low - 0.0005 and Key.Time <= High + 0.0005 and not (Add and Session.IsSelected(Name, Key.Time)) then
				table.insert(Refs, {Joint = Name, Time = Key.Time})
			end
		end
	end

	Session.SelectedKeys(Refs)
end

function Session.SelectAllKeys()
	const Refs = {}

	for Name, Track in Session.Current().Tracks do
		for _, Key in Track.Keys do
			table.insert(Refs, {Joint = Name, Time = Key.Time})
		end
	end

	Session.SelectedKeys(Refs)
end

function Session.SelectionSpan(): (number, number)
	local Lowest = math.huge
	local Highest = -math.huge

	for _, Ref in Session.SelectedKeys() do
		Lowest = math.min(Lowest, Ref.Time)
		Highest = math.max(Highest, Ref.Time)
	end

	return Lowest, Highest
end

function Session.MoveSelectedKeys(Offset: number, MergeKey: string?): number
	const Refs = Session.SelectedKeys()

	if #Refs == 0 or Offset == 0 then
		return 0
	end

	const Lowest, Highest = Session.SelectionSpan()
	const Clamped = math.clamp(Offset, -Lowest, Session.Current().Length - Highest)

	if Clamped == 0 then
		return 0
	end

	for _, Ref in Refs do
		const Blocking = Clip.FindKey(Session.Current(), Ref.Joint, Ref.Time + Clamped)

		if Blocking and not Session.IsSelected(Ref.Joint, Ref.Time + Clamped) then
			Session.Say(`{Ref.Joint} already has a keyframe there`)

			return 0
		end
	end

	const Ordered = table.clone(Refs)

	table.sort(Ordered, function(A: KeyRef, B: KeyRef)
		return if Clamped > 0 then A.Time > B.Time else A.Time < B.Time
	end)

	local Edited = Session.Current()
	const Moved = {}

	for _, Ref in Ordered do
		Edited = Clip.MoveKey(Edited, Ref.Joint, Ref.Time, Ref.Time + Clamped)
		table.insert(Moved, {Joint = Ref.Joint, Time = Ref.Time + Clamped})
	end

	Session.Edit(Edited, MergeKey)
	Session.SelectedKeys(Moved)

	return Clamped
end

function Session.Duplicate()
	if #Session.SelectedKeys() == 0 then
		return
	end

	const _, Highest = Session.SelectionSpan()

	Session.Copy()
	Session.Time(Session.ToFrame(Highest + 1 / Session.FrameRate()))
	Session.Paste()
end

function Session.ScaleSelectedKeys(NewSpan: number)
	const Refs = Session.SelectedKeys()
	const Lowest, Highest = Session.SelectionSpan()
	const Span = Highest - Lowest

	if #Refs < 2 or Span <= 0 or NewSpan <= 0 then
		return
	end

	local Edited = Session.Current()
	const Kept = {}

	for _, Ref in Refs do
		const Key = Session.KeyAt(Ref.Joint, Ref.Time)

		if Key then
			table.insert(Kept, {Joint = Ref.Joint, Key = Key, Track = Edited.Tracks[Ref.Joint]})
			Edited = Clip.RemoveKey(Edited, Ref.Joint, Ref.Time)
		end
	end

	const Moved = {}

	for _, Entry in Kept do
		const Time = Session.ToFrame(Lowest + (Entry.Key.Time - Lowest) / Span * NewSpan)

		if Clip.FindKey(Edited, Entry.Joint, Time) then
			Session.Say("That span would land two keys on the same frame, so nothing was changed")

			return
		end

		Edited = Clip.SetKey(Edited, Entry.Joint, Sift.Dictionary.merge(Entry.Key, {Time = Time}), Entry.Track.Object, Entry.Track.Property)
		table.insert(Moved, {Joint = Entry.Joint, Time = Time})
	end

	Session.Edit(Edited)
	Session.SelectedKeys(Moved)
end

function Session.SetSelectedEasing(Style: string?, Direction: string?)
	local Edited = Session.Current()

	for _, Ref in Session.SelectedKeys() do
		const Key = Clip.FindKey(Edited, Ref.Joint, Ref.Time)

		if not Key then
			continue
		end

		const Track = Edited.Tracks[Ref.Joint]

		Edited = Clip.SetKey(Edited, Ref.Joint, Sift.Dictionary.merge(Key, {
			EasingStyle = Style or Key.EasingStyle,
			EasingDirection = Direction or Key.EasingDirection,
		}), Track.Object, Track.Property)
	end

	Session.Edit(Edited)
end

function Session.Copy()
	const Refs = Session.SelectedKeys()

	if #Refs == 0 then
		return
	end

	const Lowest = Session.SelectionSpan()
	const Copied = {}

	for _, Ref in Refs do
		const Key = Session.KeyAt(Ref.Joint, Ref.Time)

		if Key then
			table.insert(Copied, {
				Joint = Ref.Joint,
				Offset = Ref.Time - Lowest,
				Key = Key,
			})
		end
	end

	Session.Clipboard(Copied)
	Session.Say(`Copied {#Copied} keyframe{if #Copied == 1 then "" else "s"}`)
end

function Session.Paste()
	const Copied = Session.Clipboard()

	if #Copied == 0 then
		return
	end

	const Start = Session.SnapTime(Session.Time())
	local Edited = Session.Current()
	const Pasted = {}

	for _, Entry in Copied do
		const Time = Session.ToFrame(Start + Entry.Offset)
		const Track = Edited.Tracks[Entry.Joint]

		Edited = Clip.SetKey(Edited, Entry.Joint, Sift.Dictionary.merge(Entry.Key, {Time = Time}), if Track then Track.Object else nil, if Track then Track.Property else nil)
		table.insert(Pasted, {Joint = Entry.Joint, Time = Time})
	end

	Session.Edit(Edited)
	Session.SelectedKeys(Pasted)
end

function Session.ReverseSelected()
	const Refs = Session.SelectedKeys()

	if #Refs < 2 then
		return
	end

	const Lowest, Highest = Session.SelectionSpan()
	local Edited = Session.Current()
	const Kept = {}

	for _, Ref in Refs do
		const Key = Session.KeyAt(Ref.Joint, Ref.Time)

		if Key then
			table.insert(Kept, {Joint = Ref.Joint, Key = Key, Track = Edited.Tracks[Ref.Joint]})
			Edited = Clip.RemoveKey(Edited, Ref.Joint, Ref.Time)
		end
	end

	const Moved = {}

	for _, Entry in Kept do
		const Time = Lowest + Highest - Entry.Key.Time

		Edited = Clip.SetKey(Edited, Entry.Joint, Sift.Dictionary.merge(Entry.Key, {Time = Time}), Entry.Track.Object, Entry.Track.Property)
		table.insert(Moved, {Joint = Entry.Joint, Time = Time})
	end

	Session.Edit(Edited)
	Session.SelectedKeys(Moved)
end

const Animatable = {
	number = true,
	boolean = true,
	string = true,
	CFrame = true,
	Vector3 = true,
	Vector2 = true,
	Color3 = true,
	UDim2 = true,
	EnumItem = true,
}

function Session.AddPropertyTrack(Object: Instance, Property: string): boolean
	const Ok, Value = pcall(function()
		return (Object :: any)[Property]
	end)

	if not Ok then
		Session.Say(`{Object.Name} has no property called {Property}`)

		return false
	end

	if not Animatable[typeof(Value)] then
		Session.Say(`{Property} is a {typeof(Value)}, which cannot be keyframed`)

		return false
	end

	const Name = Clip.PropertyTrackName(Object, Property)

	if Session.Current().Tracks[Name] then
		Session.Say(`{Object.Name}.{Property} is already a track`)

		return false
	end

	Session.WriteKey(Name, Value, nil, Object, Property)
	LastMergeKey = nil

	return true
end

function Session.KeyProperty(TrackName: string)
	const Track = Session.Current().Tracks[TrackName]

	if not Track or not Track.Object or not Track.Property then
		return
	end

	const Ok, Value = pcall(function()
		return (Track.Object :: any)[Track.Property]
	end)

	if Ok then
		Session.WriteKey(TrackName, Value, nil, Track.Object, Track.Property)
		LastMergeKey = nil
	end
end

const function ApplyAll()
	Applying = true

	const Time = Session.Time()
	const Active = Session.Rig()

	for _, Found in Session.Rigs() do
		const Current = if Active and Found.Model == Active.Model then Session.Current() else Found.Clip
		const Sampled = Pose.Sample(Current, Time)

		if Active and Found.Model == Active.Model then
			for Name, Value in Session.Scratch() do
				Sampled[Name] = Value
			end
		end

		Rig.Apply(Found.Loaded, Sampled)

		for _, Sample in Pose.SampleProperties(Current, Time) do
			if Sample.Value ~= nil and Sample.Object.Parent then
				pcall(function()
					(Sample.Object :: any)[Sample.Property] = Sample.Value
				end)
			end
		end
	end

	Applying = false
end

const function Watch(Entry: Entry)
	const Loaded = Entry.Loaded

	for _, Joint in Loaded.Joints do
		table.insert(Entry.Connections, Joint.Part1:GetPropertyChangedSignal("CFrame"):Connect(function()
			if Applying or Loaded.Applying or Session.Playing() or not Joint.Part1.Parent then
				return
			end

			const Read = Rig.ReadTransform(Joint)
			const Active = Session.Rig()
			const IsActive = Active ~= nil and Active.Model == Entry.Model
			const Expected = if IsActive then Session.PoseNow() else Pose.Sample(Entry.Clip, Session.Time())

			if Read:FuzzyEq(Expected[Joint.Name] or CFrame.identity, 0.001) then
				return
			end

			if UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) or os.clock() - LastKeyboard < 1 then
				if not IsActive then
					Session.Activate(Entry.Model)
				end

				Session.SetJointTransform(Joint.Name, Read, `Drag {Joint.Name}`)

				return
			end

			if Reapplying then
				return
			end

			Reapplying = true

			task.delay(0, function()
				Reapplying = false

				if not Loaded.Applying and Session.Entry(Entry.Model) then
					ApplyAll()
				end
			end)
		end))
	end

	table.insert(Entry.Connections, Entry.Model.AncestryChanged:Connect(function()
		if Entry.Model:IsDescendantOf(workspace) then
			return
		end

		Session.RemoveRig(Entry.Model, true)
		Session.Say(`{Entry.Model.Name} left the workspace, so it was released. Its animation comes back if the model does`)
	end))
end

function Session.Activate(Model: Model)
	const Active = Session.Rig()

	if Active and Active.Model == Model then
		return
	end

	const Target = Session.Entry(Model)

	if not Target then
		return
	end

	const Previous = Session.Entry()

	if Previous then
		Previous.Clip = Session.Current()
	end

	Session.Rig(Target.Loaded)
	Session.Current(Target.Clip)
	Session.SelectedKeys({})
	Session.SelectedMarker(nil)
	Session.SelectedJoint(nil)
	Session.Scratch({})
	Session.Pins({})
end

function Session.LoadRig(Model: Model): boolean
	if Session.Entry(Model) then
		Session.Activate(Model)

		return true
	end

	const Loaded = Rig.Load(Model)

	if not Loaded then
		return false
	end

	Rig.Hold(Loaded)

	const Entry: Entry = {
		Model = Model,
		Loaded = Loaded,
		Clip = Parked[Model] or Clip.New("Animation"),
		Connections = {},
	}

	Parked[Model] = nil

	Watch(Entry)

	const Previous = Session.Entry()

	if Previous then
		Previous.Clip = Session.Current()
	end

	Session.Rigs(Sift.Array.push(Session.Rigs(), Entry))
	Session.Rig(Loaded)
	Session.SelectedJoint(nil)
	Session.SelectedKeys({})
	Session.SelectedMarker(nil)
	Session.Scratch({})
	Session.Pins({})
	LastMergeKey = nil
	Session.Current(Entry.Clip)
	Session.Time(0)

	return true
end

function Session.RemoveRig(Model: Model, Keep: boolean?)
	const Target = Session.Entry(Model)

	if not Target then
		return
	end

	Session.Stop()

	if Keep then
		const Active = Session.Rig()

		Parked[Model] = if Active and Active.Model == Model then Session.Current() else Target.Clip
	end

	for _, Connection in Target.Connections do
		Connection:Disconnect()
	end

	Rig.Release(Target.Loaded)

	const Remaining = Sift.Array.filter(Session.Rigs(), function(Found: Entry)
		return Found ~= Target
	end)

	Session.Rigs(Remaining)

	const Active = Session.Rig()

	if Active and Active.Model == Model then
		Session.Rig(nil)
		Session.SelectedJoint(nil)
		Session.SelectedKeys({})
		Session.SelectedMarker(nil)
		Session.Pins({})
		Session.Scratch({})

		if Remaining[1] then
			Session.Activate(Remaining[1].Model)
		else
			Session.Replace(Clip.New("Animation"))
		end
	end
end

function Session.ReleaseRig()
	const Active = Session.Rig()

	if Active then
		Session.RemoveRig(Active.Model)
	end
end

function Session.ReleaseAll()
	const Copies: {Entry} = table.clone(Session.Rigs())

	for _, Found in Copies do
		Session.RemoveRig(Found.Model)
	end
end

function Session.SelectJoint(JointName: string?)
	Session.SelectedJoint(JointName)

	const Loaded = Session.Rig()
	const Joint = if Loaded and JointName then Loaded.ByName[JointName] else nil

	if Joint then
		Selection:Set({Joint.Part1})
	end
end

function Session.Start(CurrentPlugin: Plugin)
	Session.Plugin = CurrentPlugin

	Vide.effect(function()
		Session.Rigs()
		Session.Current()
		Session.Time()
		Session.Scratch()
		ApplyAll()
	end)

	Vide.effect(function()
		Session.Time()

		if not UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) then
			Vide.untrack(Session.RefreshPins)
		end
	end)

	Vide.effect(function()
		const Loaded = Session.Rig()

		if not Session.EmoteChecks() or not Loaded then
			Session.Problems({})

			return
		end

		Session.Problems(Emote.Check(Session.Current(), Loaded, Session.FrameRate()))
	end)

	ReleaseConnection = UserInputService.InputEnded:Connect(function(Input: InputObject)
		if Input.UserInputType == Enum.UserInputType.MouseButton1 then
			LastMergeKey = nil
			Session.RefreshPins()
		end
	end)

	table.insert(HistoryConnections, UserInputService.InputBegan:Connect(function(Input: InputObject)
		if Input.UserInputType == Enum.UserInputType.Keyboard then
			LastKeyboard = os.clock()
		end
	end))

	for _, Signal in {ChangeHistoryService.OnUndo, ChangeHistoryService.OnRedo} do
		table.insert(HistoryConnections, Signal:Connect(function()
			if #Session.Rigs() > 0 then
				task.defer(ApplyAll)
			end
		end))
	end

	SelectionConnection = Selection.SelectionChanged:Connect(function()
		const Picked = Selection:Get()[1]

		if not Picked then
			return
		end

		for _, Found in Session.Rigs() do
			if not Picked:IsDescendantOf(Found.Model) then
				continue
			end

			const Joint = Rig.JointOf(Found.Loaded, Picked)

			if not Joint then
				return
			end

			Session.Activate(Found.Model)

			if Session.SelectedJoint() ~= Joint.Name then
				Session.SelectedJoint(Joint.Name)
			end

			return
		end
	end)
end

function Session.Destroy()
	Session.ReleaseAll()

	for _, Connection in HistoryConnections do
		Connection:Disconnect()
	end

	table.clear(HistoryConnections)

	if SelectionConnection then
		SelectionConnection:Disconnect()
		SelectionConnection = nil
	end

	if ReleaseConnection then
		ReleaseConnection:Disconnect()
		ReleaseConnection = nil
	end
end

return Session