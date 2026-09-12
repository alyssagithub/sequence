--!strict
const ReplicatedStorage = game:GetService("ReplicatedStorage")
const StarterPlayer = game:GetService("StarterPlayer")
const ChangeHistoryService = game:GetService("ChangeHistoryService")
const Vide = require(script.Parent.Parent.Packages.vide)
const Session = require(script.Parent.Session)
const Saver = require(script.Parent.Saver)

const Playtest = {
	Ready = Vide.source(false),
}

const function Remove()
	const Runtime = ReplicatedStorage:FindFirstChild("SequencePlaytest")

	if Runtime then
		Runtime:Destroy()
	end

	const Runner = StarterPlayer.StarterPlayerScripts:FindFirstChild("SequencePlaytestRunner")

	if Runner then
		Runner:Destroy()
	end

	Playtest.Ready(false)
end

function Playtest.Refresh()
	Playtest.Ready(ReplicatedStorage:FindFirstChild("SequencePlaytest") ~= nil)
end

function Playtest.Toggle()
	if Playtest.Ready() then
		Remove()
		ChangeHistoryService:SetWaypoint("Remove Sequence playtest")
		Session.Say("Playtest scripts removed")

		return
	end

	if #Session.Rigs() == 0 then
		return
	end

	Remove()

	const Runtime = script.Runtime:Clone()

	Runtime.Name = "SequencePlaytest"
	Runtime:SetAttribute("Speed", Session.Speed())

	const Packages = script.Runtime:Clone()

	Packages.Name = "Packages"

	const Index = script.Runtime:Clone()

	Index.Name = "_Index"

	const ReelFolder = script.Parent.Parent.Packages._Index:FindFirstChild("unityjaeger_reel@0.2.0"):Clone()

	ReelFolder.Parent = Index
	Index.Parent = Packages
	script.Parent.Parent.Packages.reel:Clone().Parent = Packages
	Packages.Parent = Runtime
	script.Parent.Easing:Clone().Parent = Runtime

	const Clips = script.Runtime:Clone()

	Clips.Name = "Clips"

	const Active = Session.Rig()

	for _, Entry in Session.Rigs() do
		const Current = if Active and Entry.Model == Active.Model then Session.Current() else Entry.Clip
		const Sequence = Saver.ToSequence(Current, Entry.Loaded, Session.FrameRate())
		const Humanoid = Entry.Model:FindFirstChildOfClass("Humanoid")

		Sequence.Name = `{Entry.Model.Name} {Current.Name}`
		Sequence:SetAttribute("IsCharacter", Humanoid ~= nil and Entry.Loaded.Root.Name == "HumanoidRootPart")
		Sequence:SetAttribute("RootName", Entry.Loaded.Root.Name)

		const Link = Instance.new("ObjectValue")

		Link.Name = "Target"
		Link.Value = Entry.Model
		Link.Parent = Sequence
		Sequence.Parent = Clips
	end

	Clips.Parent = Runtime
	Runtime.Parent = ReplicatedStorage

	const Runner = script.Runner:Clone()

	Runner.Name = "SequencePlaytestRunner"
	Runner.Disabled = false
	Runner.Parent = StarterPlayer.StarterPlayerScripts

	ChangeHistoryService:SetWaypoint("Add Sequence playtest")
	Playtest.Ready(true)
	Session.Say("Press Play in Studio, the animation runs on your character through reel. Press this again to remove the scripts")
end

function Playtest.Destroy()
	Remove()
end

return Playtest