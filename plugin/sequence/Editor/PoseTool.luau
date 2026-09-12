--!strict
const UserInputService = game:GetService("UserInputService")
const Vide = require(script.Parent.Parent.Packages.vide)
const Session = require(script.Parent.Session)
const Rig = require(script.Parent.Rig)

const PoseTool = {
	Active = Vide.source(false),
}

local Connections: {RBXScriptConnection} = {}

const function Clear()
	for _, Connection in Connections do
		Connection:Disconnect()
	end

	table.clear(Connections)
end

function PoseTool.Toggle()
	const Plugin = Session.Plugin

	if not Plugin then
		return
	end

	if PoseTool.Active() then
		Plugin:Deactivate()
		PoseTool.Active(false)
		Clear()

		return
	end

	Plugin:Activate(true)
	PoseTool.Active(true)

	const Made = Plugin:GetMouse()
	local Dragging: {Joint: Rig.Joint, Start: CFrame, Origin: Vector2, Mode: "Rotate" | "Move"}?

	table.insert(Connections, Made.Button1Down:Connect(function()
		const Target = Made.Target

		if not Target then
			return
		end

		for _, Found in Session.Rigs() do
			if not Target:IsDescendantOf(Found.Model) then
				continue
			end

			const Joint = Rig.JointOf(Found.Loaded, Target)

			if not Joint then
				return
			end

			Session.Activate(Found.Model)
			Session.Stop()
			Session.SelectJoint(Joint.Name)
			Dragging = {
				Joint = Joint,
				Start = Session.PoseNow()[Joint.Name] or CFrame.identity,
				Origin = Vector2.new(Made.X, Made.Y),
				Mode = Session.Tool(),
			}

			return
		end
	end))

	table.insert(Connections, Made.Move:Connect(function()
		const Active = Dragging

		if not Active then
			return
		end

		const Delta = Vector2.new(Made.X, Made.Y) - Active.Origin
		const Camera = workspace.CurrentCamera
		const Joint = Active.Joint
		const PivotWorld = Joint.Part0.CFrame * Joint.C0

		if Active.Mode == "Move" then
			const Offset = (Camera.CFrame.RightVector * Delta.X - Camera.CFrame.UpVector * Delta.Y) * 0.01
			const Local = PivotWorld:VectorToObjectSpace(Offset)
			const Snapped = if Session.Snap() ~= "Off" then Vector3.new(math.round(Local.X * 4) / 4, math.round(Local.Y * 4) / 4, math.round(Local.Z * 4) / 4) else Local

			Session.SetJointTransform(Joint.Name, Active.Start + Snapped, `Pose {Joint.Name}`)

			return
		end

		const AxisX = PivotWorld:VectorToObjectSpace(Camera.CFrame.UpVector)
		const AxisY = PivotWorld:VectorToObjectSpace(Camera.CFrame.RightVector)
		local Yaw = math.rad(Delta.X * 0.5)
		local Pitch = math.rad(Delta.Y * 0.5)

		if Session.Snap() ~= "Off" then
			Yaw = math.rad(math.round(math.deg(Yaw) / 5) * 5)
			Pitch = math.rad(math.round(math.deg(Pitch) / 5) * 5)
		end

		const Turn = CFrame.fromAxisAngle(AxisX, -Yaw) * CFrame.fromAxisAngle(AxisY, -Pitch)

		Session.SetJointTransform(Joint.Name, Turn * Active.Start.Rotation + Active.Start.Position, `Pose {Joint.Name}`)
	end))

	table.insert(Connections, Made.Button1Up:Connect(function()
		Dragging = nil
		Session.EndMerge()
		Session.RefreshPins()
	end))

	table.insert(Connections, Plugin.Deactivation:Connect(function()
		PoseTool.Active(false)
		Clear()
	end))

	table.insert(Connections, UserInputService.InputBegan:Connect(function(Input: InputObject, Processed: boolean)
		if not Processed and Input.KeyCode == Enum.KeyCode.Escape then
			PoseTool.Toggle()
		end
	end))
end

function PoseTool.Destroy()
	if PoseTool.Active() and Session.Plugin then
		Session.Plugin:Deactivate()
	end

	PoseTool.Active(false)
	Clear()
end

return PoseTool