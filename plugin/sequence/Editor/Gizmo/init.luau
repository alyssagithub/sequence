--!strict
const CoreGui = game:GetService("CoreGui")
const Vide = require(script.Parent.Parent.Packages.vide)
const Scythe = require(script.Parent.Parent.Packages.scythe)
const Session = require(script.Parent.Session)
const Rig = require(script.Parent.Rig)

const Gizmo = {}

local Holder: Folder?
const Scope = Scythe.scope()
local DestroyScope: (() -> ())?

const function Clear()
	Scythe.clean(Scope)

	if DestroyScope then
		DestroyScope()
		DestroyScope = nil
	end

	if Holder then
		Holder:Destroy()
		Holder = nil
	end
end

const function Build(Loaded: Rig.Rig, Joint: Rig.Joint)
	const Made = script.Handles:Clone()
	const Pivot = Made.Pivot :: BasePart
	const Arcs = Made.Arcs :: ArcHandles
	const Movers = Made.Movers :: Handles

	Arcs.Adornee = Pivot
	Movers.Adornee = Pivot
	Made.Parent = CoreGui
	Holder = Made

	local StartTransform = CFrame.identity
	local Dragging = false

	const function Place()
		if Dragging then
			return
		end

		Pivot.CFrame = Joint.Part0.CFrame * Joint.C0 * (Session.PoseNow()[Joint.Name] or CFrame.identity)
	end

	const function Begin()
		Session.Stop()
		Dragging = true
		StartTransform = Session.PoseNow()[Joint.Name] or CFrame.identity
	end

	const function Finish()
		Dragging = false
		Session.EndMerge()
		Place()
	end

	const AxisVectors = {
		[Enum.Axis.X] = Vector3.xAxis,
		[Enum.Axis.Y] = Vector3.yAxis,
		[Enum.Axis.Z] = Vector3.zAxis,
	}

	Scythe.add(Scope, Arcs.MouseButton1Down:Connect(Begin))
	Scythe.add(Scope, Arcs.MouseButton1Up:Connect(Finish))
	Scythe.add(Scope, Arcs.MouseDrag:Connect(function(Axis: Enum.Axis, Angle: number)
		const Snapped = if Session.Snap() ~= "Off" then math.rad(math.round(math.deg(Angle) / 5) * 5) else Angle

		Session.SetJointTransform(Joint.Name, StartTransform * CFrame.fromAxisAngle(AxisVectors[Axis], Snapped), `Rotate {Joint.Name}`)
		Pivot.CFrame = Joint.Part0.CFrame * Joint.C0 * StartTransform * CFrame.fromAxisAngle(AxisVectors[Axis], Snapped)
	end))
	Scythe.add(Scope, Movers.MouseButton1Down:Connect(Begin))
	Scythe.add(Scope, Movers.MouseButton1Up:Connect(Finish))
	Scythe.add(Scope, Movers.MouseDrag:Connect(function(Face: Enum.NormalId, Distance: number)
		const Snapped = if Session.Snap() ~= "Off" then math.round(Distance * 4) / 4 else Distance

		Session.SetJointTransform(Joint.Name, StartTransform * CFrame.new(Vector3.fromNormalId(Face) * Snapped), `Move {Joint.Name}`)
		Pivot.CFrame = Joint.Part0.CFrame * Joint.C0 * StartTransform * CFrame.new(Vector3.fromNormalId(Face) * Snapped)
	end))

	Vide.effect(function()
		Arcs.Visible = Session.Tool() == "Rotate" and not Session.Playing()
		Movers.Visible = Session.Tool() == "Move" and not Session.Playing()
	end)

	Vide.effect(function()
		Session.Current()
		Session.Time()
		Session.Scratch()
		Place()
	end)

	Scythe.add(Scope, Joint.Part0:GetPropertyChangedSignal("CFrame"):Connect(Place))
end

function Gizmo.Start()
	Vide.effect(function()
		const Loaded = Session.Rig()
		const Name = Session.SelectedJoint()
		const Joint = if Loaded and Name then Loaded.ByName[Name] else nil

		Clear()

		if not Loaded or not Joint then
			return
		end

		DestroyScope = Vide.root(function()
			Build(Loaded, Joint)
		end)
	end)
end

function Gizmo.Destroy()
	Clear()
end

return Gizmo