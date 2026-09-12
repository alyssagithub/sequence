--!strict
const ChangeHistoryService = game:GetService("ChangeHistoryService")
const Selection = game:GetService("Selection")
const Rig = require(script.Parent.Rig)
const Clip = require(script.Parent.Clip)
const Pose = require(script.Parent.Pose)

const Bake = {}

function Bake.Pose(Loaded: Rig.Rig, Current: Clip.Clip, Time: number, Name: string): Model
	const Copy = Loaded.Model:Clone()

	Copy.Name = Name

	for _, Child in Copy:GetChildren() do
		if Child.Name == "AnimSaves" then
			Child:Destroy()
		end
	end

	for _, Descendant in Copy:GetDescendants() do
		if Descendant:IsA("LuaSourceContainer") then
			Descendant:Destroy()
		end
	end

	const BakedRig = Rig.Load(Copy)

	if BakedRig then
		const Sampled = Pose.Sample(Current, Time)

		for _, Joint in BakedRig.Joints do
			const Transform = Sampled[Joint.Name] or CFrame.identity

			Joint.C0 = Joint.C0 * Transform

			if Joint.Motor:IsA("Motor6D") then
				Joint.Motor.C0 = Joint.C0
			elseif Joint.Motor.Attachment0 then
				Joint.Motor.Attachment0.CFrame = Joint.C0
			end
		end

		for _, Joint in BakedRig.Joints do
			Joint.Part1.CFrame = Joint.Part0.CFrame * Joint.C0 * Joint.C1:Inverse()
		end
	end

	for _, Descendant in Copy:GetDescendants() do
		if Descendant:IsA("BasePart") then
			Descendant.Anchored = true
		end
	end

	const Humanoid = Copy:FindFirstChildOfClass("Humanoid")

	if Humanoid then
		Humanoid.PlatformStand = true
	end

	return Copy
end

function Bake.Place(Loaded: Rig.Rig, Current: Clip.Clip, Times: {number}): {Model}
	const Made = {}
	const Width = Loaded.Model:GetExtentsSize().X + 2

	for Index, Time in Times do
		const Copy = Bake.Pose(Loaded, Current, Time, `{Loaded.Model.Name} at {math.round(Time * 100) / 100}s`)

		Copy:PivotTo(Loaded.Model:GetPivot() * CFrame.new(Width * Index, 0, 0))
		Copy.Parent = workspace
		table.insert(Made, Copy)
	end

	Selection:Set(Made)
	ChangeHistoryService:SetWaypoint(`Bake {#Made} pose{if #Made == 1 then "" else "s"}`)

	return Made
end

return Bake