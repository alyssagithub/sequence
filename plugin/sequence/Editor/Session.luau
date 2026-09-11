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

export type KeyRef = {
	Joint: string,
	Time: number,
}

const Session = {
	Rig = Vide.source(nil :: Rig.Rig?),
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
	Dirty = Vide.source(false),
	Notice = Vide.source(""),
	UndoCount = Vide.source(0),
	RedoCount = Vide.source(0),
	ImportPrompt = Vide.source(false),
	SelectedMarker = Vide.source(nil :: Clip.Marker?),
	Confirming = Vide.source(nil :: string?),
	Collapsed = Vide.source({} :: {[string]: boolean}),
	Plugin = nil :: Plugin?,
}

const Undo: {Clip.Clip} = {}
const Redo: {Clip.Clip} = {}
local LastMergeKey: string?
local Heartbeat: RBXScriptConnection?
const JointConnections: {RBXScriptConnection} = {}
local SelectionConnection: RBXScriptConnection?
local ReleaseConnection: RBXScriptConnection?
local RigGoneConnection: RBXScriptConnection?
local NoticeToken = 0
local ConfirmToken = 0

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

function Session.SnapTime(Time: number): number
	const Clamped = math.clamp(Time, 0, Session.Current().Length)

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

function Session.Edit(NewClip: Clip.Clip, MergeKey: string?)
	if NewClip == Session.Current() then
		return
	end

	if MergeKey == nil or MergeKey ~= LastMergeKey then
		table.insert(Undo, Session.Current())

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

	table.insert(Redo, Session.Current())
	LastMergeKey = nil
	Session.Current(Previous)
	Prune(Previous)
	Session.Time(math.min(Session.Time(), Previous.Length))
	Session.UndoCount(#Undo)
	Session.RedoCount(#Redo)
end

function Session.Redo()
	const Next = table.remove(Redo)

	if not Next then
		return
	end

	table.insert(Undo, Session.Current())
	LastMergeKey = nil
	Session.Current(Next)
	Prune(Next)
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
	Session.Dirty(false)
	Session.UndoCount(0)
	Session.RedoCount(0)
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

	if Session.Time() >= Session.Current().Length then
		Session.Time(0)
	end

	Session.Playing(true)

	if Heartbeat then
		return
	end

	Heartbeat = RunService.Heartbeat:Connect(function(Delta: number)
		const Length = Session.Current().Length
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
	Session.Time(math.clamp(math.round(Session.Time() * Session.FrameRate() + Frames) / Session.FrameRate(), 0, Session.Current().Length))
end

function Session.Seek(Time: number)
	Session.Time(Session.SnapTime(Time))
end

function Session.KeyAt(JointName: string, Time: number): Clip.Key?
	return Clip.FindKey(Session.Current(), JointName, Time)
end

function Session.WriteKey(JointName: string, Value: CFrame, MergeKey: string?)
	const Time = Session.SnapTime(Session.Time())
	const Existing = Session.KeyAt(JointName, Time)
	const Track = Session.Current().Tracks[JointName]
	local Previous: Clip.Key?

	if Track then
		for _, Key in Track.Keys do
			if Key.Time < Time then
				Previous = Key
			end
		end
	end

	if Existing and Existing.Value:FuzzyEq(Value, 0.00001) then
		return
	end

	const Style = if Existing then Existing.EasingStyle elseif Previous then Previous.EasingStyle else "Linear"
	const Direction = if Existing then Existing.EasingDirection elseif Previous then Previous.EasingDirection else "In"

	Session.Edit(Clip.SetKey(Session.Current(), JointName, {
		Time = Time,
		Value = Value,
		EasingStyle = Style,
		EasingDirection = Direction,
	}), MergeKey)
end

function Session.SetJointTransform(JointName: string, Value: CFrame, MergeKey: string?)
	if Session.Time() ~= Session.SnapTime(Session.Time()) then
		Session.Time(Session.SnapTime(Session.Time()))
	end

	Session.WriteKey(JointName, Value, MergeKey)
end

function Session.AddKeys(JointNames: {string})
	const Loaded = Session.Rig()

	if not Loaded then
		return
	end

	const Sampled = Pose.Sample(Session.Current(), Session.SnapTime(Session.Time()))

	for _, Name in JointNames do
		Session.WriteKey(Name, Sampled[Name] or CFrame.identity, "AddKeys")
	end

	LastMergeKey = nil
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

function Session.DeleteSelectedKeys()
	local Edited = Session.Current()

	for _, Ref in Session.SelectedKeys() do
		Edited = Clip.RemoveKey(Edited, Ref.Joint, Ref.Time)
	end

	Session.Edit(Edited)
	Session.SelectedKeys({})
end

function Session.IsSelected(JointName: string, Time: number): boolean
	for _, Ref in Session.SelectedKeys() do
		if Ref.Joint == JointName and math.abs(Ref.Time - Time) < 0.0005 then
			return true
		end
	end

	return false
end

function Session.SelectKey(JointName: string, Time: number, Add: boolean)
	if Add then
		if Session.IsSelected(JointName, Time) then
			Session.SelectedKeys(Sift.Array.filter(Session.SelectedKeys(), function(Ref: KeyRef)
				return Ref.Joint ~= JointName or math.abs(Ref.Time - Time) >= 0.0005
			end))
		else
			Session.SelectedKeys(Sift.Array.push(Session.SelectedKeys(), {Joint = JointName, Time = Time}))
		end

		return
	end

	if Session.IsSelected(JointName, Time) then
		return
	end

	Session.SelectedKeys({{Joint = JointName, Time = Time}})
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

function Session.SelectAllKeys()
	const Refs = {}

	for Name, Track in Session.Current().Tracks do
		for _, Key in Track.Keys do
			table.insert(Refs, {Joint = Name, Time = Key.Time})
		end
	end

	Session.SelectedKeys(Refs)
end

function Session.MoveSelectedKeys(Offset: number, MergeKey: string?)
	const Refs = Session.SelectedKeys()

	if #Refs == 0 or Offset == 0 then
		return
	end

	local Lowest = math.huge
	local Highest = -math.huge

	for _, Ref in Refs do
		Lowest = math.min(Lowest, Ref.Time)
		Highest = math.max(Highest, Ref.Time)
	end

	const Clamped = math.clamp(Offset, -Lowest, Session.Current().Length - Highest)

	if Clamped == 0 then
		return
	end

	for _, Ref in Refs do
		const Blocking = Clip.FindKey(Session.Current(), Ref.Joint, Ref.Time + Clamped)

		if Blocking and not Session.IsSelected(Ref.Joint, Ref.Time + Clamped) then
			Session.Say(`{Ref.Joint} already has a keyframe there`)

			return
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
end

function Session.SetSelectedEasing(Style: string?, Direction: string?)
	local Edited = Session.Current()

	for _, Ref in Session.SelectedKeys() do
		const Key = Clip.FindKey(Edited, Ref.Joint, Ref.Time)

		if not Key then
			continue
		end

		Edited = Clip.SetKey(Edited, Ref.Joint, Sift.Dictionary.merge(Key, {
			EasingStyle = Style or Key.EasingStyle,
			EasingDirection = Direction or Key.EasingDirection,
		}))
	end

	Session.Edit(Edited)
end

function Session.Copy()
	const Refs = Session.SelectedKeys()

	if #Refs == 0 then
		return
	end

	local Lowest = math.huge

	for _, Ref in Refs do
		Lowest = math.min(Lowest, Ref.Time)
	end

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

		Edited = Clip.SetKey(Edited, Entry.Joint, Sift.Dictionary.merge(Entry.Key, {Time = Time}))
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

	local Lowest = math.huge
	local Highest = -math.huge

	for _, Ref in Refs do
		Lowest = math.min(Lowest, Ref.Time)
		Highest = math.max(Highest, Ref.Time)
	end

	local Edited = Session.Current()
	const Kept = {}

	for _, Ref in Refs do
		const Key = Session.KeyAt(Ref.Joint, Ref.Time)

		if Key then
			table.insert(Kept, {Joint = Ref.Joint, Key = Key})
			Edited = Clip.RemoveKey(Edited, Ref.Joint, Ref.Time)
		end
	end

	const Moved = {}

	for _, Entry in Kept do
		const Time = Lowest + Highest - Entry.Key.Time

		Edited = Clip.SetKey(Edited, Entry.Joint, Sift.Dictionary.merge(Entry.Key, {Time = Time}))
		table.insert(Moved, {Joint = Entry.Joint, Time = Time})
	end

	Session.Edit(Edited)
	Session.SelectedKeys(Moved)
end

const function Watch(Loaded: Rig.Rig)
	for _, Connection in JointConnections do
		Connection:Disconnect()
	end

	table.clear(JointConnections)

	for _, Joint in Loaded.Joints do
		table.insert(JointConnections, Joint.Part1:GetPropertyChangedSignal("CFrame"):Connect(function()
			if Loaded.Applying or Session.Playing() or Session.Rig() ~= Loaded or not Joint.Part1.Parent then
				return
			end

			const Read = Rig.ReadTransform(Joint)
			const Expected = Pose.Sample(Session.Current(), Session.Time())

			if Read:FuzzyEq(Expected[Joint.Name] or CFrame.identity, 0.001) then
				return
			end

			if UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) then
				Session.SetJointTransform(Joint.Name, Read, `Drag {Joint.Name}`)

				return
			end

			task.defer(function()
				if Session.Rig() == Loaded and not Loaded.Applying then
					Rig.Apply(Loaded, Expected)
				end
			end)
		end))
	end
end

function Session.LoadRig(Model: Model): boolean
	const Loaded = Rig.Load(Model)

	if not Loaded then
		return false
	end

	Session.ReleaseRig()
	Rig.Hold(Loaded)
	ChangeHistoryService:SetEnabled(false)
	Session.Rig(Loaded)
	Watch(Loaded)
	Session.Replace(Clip.New("Animation"))

	RigGoneConnection = Model.AncestryChanged:Connect(function()
		if Model:IsDescendantOf(workspace) then
			return
		end

		Session.ReleaseRig()
		Session.Say(`{Model.Name} left the workspace, so the rig was released`)
	end)

	return true
end

function Session.ReleaseRig()
	Session.Stop()

	const Loaded = Session.Rig()

	for _, Connection in JointConnections do
		Connection:Disconnect()
	end

	table.clear(JointConnections)

	if RigGoneConnection then
		RigGoneConnection:Disconnect()
		RigGoneConnection = nil
	end

	if not Loaded then
		return
	end

	Rig.Release(Loaded)
	ChangeHistoryService:SetEnabled(true)
	Session.Rig(nil)
	Session.SelectedJoint(nil)
	Session.SelectedKeys({})
	Session.SelectedMarker(nil)
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
		const Loaded = Session.Rig()

		if not Loaded then
			return
		end

		Rig.Apply(Loaded, Pose.Sample(Session.Current(), Session.Time()))
	end)

	ReleaseConnection = UserInputService.InputEnded:Connect(function(Input: InputObject)
		if Input.UserInputType == Enum.UserInputType.MouseButton1 then
			LastMergeKey = nil
		end
	end)

	SelectionConnection = Selection.SelectionChanged:Connect(function()
		const Loaded = Session.Rig()
		const Picked = Selection:Get()[1]

		if not Loaded or not Picked or not Picked:IsDescendantOf(Loaded.Model) then
			return
		end

		const Joint = Rig.JointOf(Loaded, Picked)

		if Joint and Session.SelectedJoint() ~= Joint.Name then
			Session.SelectedJoint(Joint.Name)
		end
	end)
end

function Session.Destroy()
	Session.ReleaseRig()

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