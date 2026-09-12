--!strict
const Rig = require(script.Parent.Rig)

const Ik = {}

const function WorldOf(Loaded: Rig.Rig, Pose: {[string]: CFrame}, Joint: Rig.Joint): CFrame
	const Parent = if Joint.Parent then WorldOf(Loaded, Pose, Joint.Parent) else Loaded.Root.CFrame

	return Parent * Joint.C0 * (Pose[Joint.Name] or CFrame.identity) * Joint.C1:Inverse()
end

function Ik.Chain(Loaded: Rig.Rig, MovedName: string?, PinName: string): {Rig.Joint}
	const Pin = Loaded.ByName[PinName]

	if not Pin then
		return {}
	end

	const Chain = {}
	local Walk: Rig.Joint? = Pin.Parent

	while Walk and Walk.Name ~= MovedName do
		table.insert(Chain, 1, Walk)
		Walk = Walk.Parent
	end

	if MovedName and not Walk then
		return {}
	end

	return Chain
end

function Ik.Solve(Loaded: Rig.Rig, Pose: {[string]: CFrame}, Chain: {Rig.Joint}, PinName: string, Target: CFrame): {[string]: CFrame}
	const Pin = Loaded.ByName[PinName]

	if not Pin or #Chain == 0 then
		return Pose
	end

	const Solved = table.clone(Pose)

	for _ = 1, 24 do
		for Index = #Chain, 1, -1 do
			const Joint = Chain[Index]
			const JointWorld = WorldOf(Loaded, Solved, Joint)
			const Pivot = if Joint.Parent then WorldOf(Loaded, Solved, Joint.Parent) * Joint.C0 else Loaded.Root.CFrame * Joint.C0
			const EndWorld = WorldOf(Loaded, Solved, Pin).Position
			const ToEnd = EndWorld - Pivot.Position
			const ToTarget = Target.Position - Pivot.Position

			if ToEnd.Magnitude < 0.001 or ToTarget.Magnitude < 0.001 then
				continue
			end

			const Axis = ToEnd:Cross(ToTarget)

			if Axis.Magnitude < 0.0001 then
				continue
			end

			const Angle = math.acos(math.clamp(ToEnd.Unit:Dot(ToTarget.Unit), -1, 1))
			const Rotation = CFrame.fromAxisAngle(Axis.Unit, Angle)
			const NewJointWorld = CFrame.new(Pivot.Position) * Rotation * CFrame.new(-Pivot.Position) * JointWorld
			const Local = Pivot:Inverse() * NewJointWorld * Joint.C1

			Solved[Joint.Name] = Local - Local.Position + (Solved[Joint.Name] or CFrame.identity).Position
		end

		if (WorldOf(Loaded, Solved, Pin).Position - Target.Position).Magnitude < 0.01 then
			break
		end
	end

	const PinParentWorld = if Pin.Parent then WorldOf(Loaded, Solved, Pin.Parent) else Loaded.Root.CFrame
	const Wanted = (PinParentWorld * Pin.C0):Inverse() * Target * Pin.C1

	Solved[Pin.Name] = Wanted.Rotation + (Solved[Pin.Name] or CFrame.identity).Position

	return Solved
end

function Ik.WorldOf(Loaded: Rig.Rig, Pose: {[string]: CFrame}, JointName: string): CFrame?
	const Joint = Loaded.ByName[JointName]

	return if Joint then WorldOf(Loaded, Pose, Joint) else nil
end

return Ik