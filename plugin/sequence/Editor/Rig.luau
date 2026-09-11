--!strict
export type Joint = {
	Name: string,
	Motor: Motor6D,
	Part0: BasePart,
	Part1: BasePart,
	Parent: Joint?,
	Depth: number,
	Children: {Joint},
}

export type Rig = {
	Model: Model,
	Root: BasePart,
	Joints: {Joint},
	ByName: {[string]: Joint},
	Originals: {[BasePart]: {CFrame: CFrame, Anchored: boolean}},
	Applying: boolean,
}

const Rig = {}

function Rig.FindMotors(Model: Model): {Motor6D}
	const Motors = {}

	for _, Descendant in Model:GetDescendants() do
		if Descendant:IsA("Motor6D") and Descendant.Part0 and Descendant.Part1 and Descendant.Part0:IsDescendantOf(Model) and Descendant.Part1:IsDescendantOf(Model) then
			table.insert(Motors, Descendant)
		end
	end

	return Motors
end

function Rig.Load(Model: Model): Rig?
	const Motors = Rig.FindMotors(Model)

	if #Motors == 0 then
		return nil
	end

	const ByPart1: {[BasePart]: Motor6D} = {}

	for _, Motor in Motors do
		ByPart1[Motor.Part1 :: BasePart] = Motor
	end

	local Root: BasePart? = Model.PrimaryPart

	if not Root or ByPart1[Root :: BasePart] then
		Root = nil

		for _, Motor in Motors do
			if not ByPart1[Motor.Part0 :: BasePart] then
				Root = Motor.Part0
				break
			end
		end
	end

	if not Root then
		return nil
	end

	const Loaded: Rig = {
		Model = Model,
		Root = Root :: BasePart,
		Joints = {},
		ByName = {},
		Originals = {},
		Applying = false,
	}

	const function Descend(Part: BasePart, Parent: Joint?, Depth: number)
		const Attached = {}

		for _, Motor in Motors do
			if Motor.Part0 == Part and Motor.Part1 ~= Part and not Loaded.ByName[(Motor.Part1 :: BasePart).Name] then
				table.insert(Attached, Motor)
			end
		end

		table.sort(Attached, function(A: Motor6D, B: Motor6D)
			return (A.Part1 :: BasePart).Name < (B.Part1 :: BasePart).Name
		end)

		for _, Motor in Attached do
			const Part1 = Motor.Part1 :: BasePart
			const Joint: Joint = {
				Name = Part1.Name,
				Motor = Motor,
				Part0 = Part,
				Part1 = Part1,
				Parent = Parent,
				Depth = Depth,
				Children = {},
			}

			Loaded.ByName[Joint.Name] = Joint
			table.insert(Loaded.Joints, Joint)

			if Parent then
				table.insert(Parent.Children, Joint)
			end

			Descend(Part1, Joint, Depth + 1)
		end
	end

	Descend(Loaded.Root, nil, 0)

	return Loaded
end

function Rig.Hold(Loaded: Rig)
	for _, Part in Loaded.Model:GetDescendants() do
		if not Part:IsA("BasePart") then
			continue
		end

		Loaded.Originals[Part] = {
			CFrame = Part.CFrame,
			Anchored = Part.Anchored,
		}
		Part.Anchored = true
	end
end

function Rig.Release(Loaded: Rig)
	Loaded.Applying = true

	for Part, Original in Loaded.Originals do
		if Part.Parent then
			Part.CFrame = Original.CFrame
			Part.Anchored = Original.Anchored
		end
	end

	Loaded.Applying = false
	Loaded.Originals = {}
end

function Rig.Apply(Loaded: Rig, Pose: {[string]: CFrame})
	Loaded.Applying = true

	for _, Joint in Loaded.Joints do
		if Joint.Part1.Parent and Joint.Part0.Parent then
			Joint.Part1.CFrame = Joint.Part0.CFrame * Joint.Motor.C0 * (Pose[Joint.Name] or CFrame.identity) * Joint.Motor.C1:Inverse()
		end
	end

	Loaded.Applying = false
end

function Rig.ReadTransform(Joint: Joint): CFrame
	return Joint.Motor.C0:Inverse() * Joint.Part0.CFrame:Inverse() * Joint.Part1.CFrame * Joint.Motor.C1
end

function Rig.JointOf(Loaded: Rig, Part: Instance): Joint?
	for _, Joint in Loaded.Joints do
		if Joint.Part1 == Part then
			return Joint
		end
	end

	return nil
end

return Rig