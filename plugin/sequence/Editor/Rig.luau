--!strict
export type Joint = {
	Name: string,
	Motor: Motor6D | AnimationConstraint,
	C0: CFrame,
	C1: CFrame,
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

export type Link = {
	Joint: Motor6D | AnimationConstraint,
	Part0: BasePart,
	Part1: BasePart,
	C0: CFrame,
	C1: CFrame,
}

function Rig.FindMotors(Model: Model): {Link}
	const Motors = {}

	for _, Descendant in Model:GetDescendants() do
		if Descendant:IsA("Motor6D") and Descendant.Part0 and Descendant.Part1 and Descendant.Part0:IsDescendantOf(Model) and Descendant.Part1:IsDescendantOf(Model) then
			table.insert(Motors, {
				Joint = Descendant,
				Part0 = Descendant.Part0 :: BasePart,
				Part1 = Descendant.Part1 :: BasePart,
				C0 = Descendant.C0,
				C1 = Descendant.C1,
			})
		elseif Descendant:IsA("AnimationConstraint") and Descendant.Attachment0 and Descendant.Attachment1 then
			const Part0 = Descendant.Attachment0.Parent
			const Part1 = Descendant.Attachment1.Parent

			if Part0 and Part1 and Part0:IsA("BasePart") and Part1:IsA("BasePart") and Part0:IsDescendantOf(Model) and Part1:IsDescendantOf(Model) then
				table.insert(Motors, {
					Joint = Descendant,
					Part0 = Part0,
					Part1 = Part1,
					C0 = Descendant.Attachment0.CFrame,
					C1 = Descendant.Attachment1.CFrame,
				})
			end
		end
	end

	return Motors
end

function Rig.Load(Model: Model): Rig?
	const Motors = Rig.FindMotors(Model)

	if #Motors == 0 then
		return nil
	end

	const ByPart1: {[BasePart]: Link} = {}

	for _, Motor in Motors do
		ByPart1[Motor.Part1] = Motor
	end

	local Root: BasePart? = Model.PrimaryPart

	if not Root or ByPart1[Root :: BasePart] then
		Root = nil

		for _, Motor in Motors do
			if not ByPart1[Motor.Part0] then
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

		const SeenPart1: {[BasePart]: boolean} = {}

		for _, Motor in Motors do
			if Motor.Part0 == Part and Motor.Part1 ~= Part and not Loaded.ByName[Motor.Part1.Name] and not SeenPart1[Motor.Part1] then
				SeenPart1[Motor.Part1] = true
				table.insert(Attached, Motor)
			end
		end

		table.sort(Attached, function(A: Link, B: Link)
			return A.Part1.Name < B.Part1.Name
		end)

		for _, Motor in Attached do
			const Part1 = Motor.Part1
			const Joint: Joint = {
				Name = Part1.Name,
				Motor = Motor.Joint,
				C0 = Motor.C0,
				C1 = Motor.C1,
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
		if not Joint.Part1.Parent or not Joint.Part0.Parent then
			continue
		end

		const Transform = Pose[Joint.Name] or CFrame.identity
		const Wanted = Joint.Part0.CFrame * Joint.C0 * Transform * Joint.C1:Inverse()

		if Joint.Motor:IsA("AnimationConstraint") then
			Joint.Motor.Transform = Transform
		end

		if not Joint.Part1.CFrame:FuzzyEq(Wanted, 0.00001) then
			Joint.Part1.CFrame = Wanted
		end
	end

	Loaded.Applying = false
end

function Rig.ReadTransform(Joint: Joint): CFrame
	return Joint.C0:Inverse() * Joint.Part0.CFrame:Inverse() * Joint.Part1.CFrame * Joint.C1
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