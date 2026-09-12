--!strict
const Clip = require(script.Parent.Clip)
const Rig = require(script.Parent.Rig)
const Pose = require(script.Parent.Pose)
const Ik = require(script.Parent.Ik)
const Saver = require(script.Parent.Saver)

export type Problem = {
	Time: number?,
	Joint: string?,
	Text: string,
}

const Emote = {}

Emote.Limits = {
	MaxLength = 10,
	MinHeight = -3.1,
	MaxDistance = 25,
	MaxStudsPerSecond = 45,
	MaxDegreesPerSecond = 1750,
	MaxOffset = 0.3,
	SampleRate = 70,
	MinKeyGap = 0.85 / 70,
}

Emote.R15Parts = {
	"LowerTorso",
	"UpperTorso",
	"Head",
	"LeftUpperArm",
	"LeftLowerArm",
	"LeftHand",
	"RightUpperArm",
	"RightLowerArm",
	"RightHand",
	"LeftUpperLeg",
	"LeftLowerLeg",
	"LeftFoot",
	"RightUpperLeg",
	"RightLowerLeg",
	"RightFoot",
}

function Emote.IsR15(Loaded: Rig.Rig): boolean
	if Loaded.Root.Name ~= "HumanoidRootPart" then
		return false
	end

	for _, Name in Emote.R15Parts do
		if not Loaded.ByName[Name] then
			return false
		end
	end

	return true
end

function Emote.Check(Source: Clip.Clip, Loaded: Rig.Rig, FrameRate: number): {Problem}
	const Current = Saver.Baked(Source, FrameRate, true)
	const Problems: {Problem} = {}
	const Limits = Emote.Limits

	const function Add(Text: string, Time: number?, Joint: string?)
		table.insert(Problems, {
			Time = Time,
			Joint = Joint,
			Text = Text,
		})
	end

	if not Emote.IsR15(Loaded) then
		Add("The rig is not a standard R15 character, so it cannot be uploaded as an emote")

		return Problems
	end

	local JointTracks = 0

	for Name, Track in Clip.JointTracks(Current) do
		JointTracks += 1

		if not table.find(Emote.R15Parts, Name) then
			Add(`{Name} is not an R15 body part, the emote validator rejects extra joints`, nil, Name)
		end

		for Index, Key in Track.Keys do
			const Previous = Track.Keys[Index - 1]

			if Previous and Key.Time - Previous.Time < Limits.MinKeyGap - 0.0001 then
				Add(`Keys on {Name} are closer than 1/70 of a second apart`, Key.Time, Name)
			end

			if Name ~= "LowerTorso" and (Key.Value :: CFrame).Position.Magnitude > Limits.MaxOffset then
				Add(`{Name} moves {math.round((Key.Value :: CFrame).Position.Magnitude * 100) / 100} studs off its joint, only LowerTorso may move more than {Limits.MaxOffset}`, Key.Time, Name)
			end
		end
	end

	if JointTracks == 0 then
		Add("No joint has a keyframe, an emote has to move at least one body part")
	end

	const Length = Clip.LastTime(Current)

	if Length <= 0 then
		Add("The animation has no length")
	elseif Length > Limits.MaxLength then
		Add(`The animation is {math.round(Length * 100) / 100} seconds, emotes must be {Limits.MaxLength} seconds or shorter`, Length)
	end

	const Step = 1 / Limits.SampleRate
	const RootInverse = Loaded.Root.CFrame:Inverse()
	local Previous: {[string]: CFrame}?
	local Time = 0
	const Reported: {[string]: boolean} = {}

	while Time <= Length + 0.0001 do
		const Sampled = Pose.Sample(Current, math.min(Time, Length))
		const Frame: {[string]: CFrame} = {}

		for _, Name in Emote.R15Parts do
			const World = Ik.WorldOf(Loaded, Sampled, Name)

			if World then
				Frame[Name] = RootInverse * World
			end
		end

		for Name, Relative in Frame do
			if Relative.Position.Y < Limits.MinHeight and not Reported[`Low{Name}`] then
				Reported[`Low{Name}`] = true
				Add(`{Name} drops {math.round(Relative.Position.Y * 100) / 100} studs below the root, the limit is {Limits.MinHeight}`, Time, Name)
			end

			if Relative.Position.Magnitude > Limits.MaxDistance and not Reported[`Far{Name}`] then
				Reported[`Far{Name}`] = true
				Add(`{Name} is {math.round(Relative.Position.Magnitude * 10) / 10} studs from the root, the limit is {Limits.MaxDistance}`, Time, Name)
			end

			const Before = Previous and Previous[Name]

			if not Before then
				continue
			end

			const Speed = (Relative.Position - Before.Position).Magnitude / Step

			if Speed > Limits.MaxStudsPerSecond and not Reported[`Fast{Name}`] then
				Reported[`Fast{Name}`] = true
				Add(`{Name} moves at {math.round(Speed)} studs per second, the limit is {Limits.MaxStudsPerSecond}`, Time, Name)
			end

			const Turn = math.deg(Relative:AngleBetween(Before)) / Step

			if Turn > Limits.MaxDegreesPerSecond and not Reported[`Spin{Name}`] then
				Reported[`Spin{Name}`] = true
				Add(`{Name} turns at {math.round(Turn)} degrees per second, the limit is {Limits.MaxDegreesPerSecond}`, Time, Name)
			end
		end

		Previous = Frame
		Time += Step
	end

	table.sort(Problems, function(A: Problem, B: Problem)
		return (A.Time or -1) < (B.Time or -1)
	end)

	return Problems
end

return Emote