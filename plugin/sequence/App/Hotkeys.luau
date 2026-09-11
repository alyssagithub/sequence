--!strict
const UserInputService = game:GetService("UserInputService")
const Session = require(script.Parent.Parent.Editor.Session)
const Overlay = require(script.Parent.Overlay)

const Hotkeys = {}

const function Held(...: Enum.KeyCode): boolean
	for _, Key in {...} do
		if UserInputService:IsKeyDown(Key) then
			return true
		end
	end

	return false
end

function Hotkeys.Handle(Input: InputObject)
	if Input.UserInputType ~= Enum.UserInputType.Keyboard or not Session.Rig() or UserInputService:GetFocusedTextBox() then
		return
	end

	if Overlay.Open() then
		if Input.KeyCode == Enum.KeyCode.Escape then
			Overlay.Close()
		end

		return
	end

	const Control = Held(Enum.KeyCode.LeftControl, Enum.KeyCode.RightControl)
	const Shift = Held(Enum.KeyCode.LeftShift, Enum.KeyCode.RightShift)
	const Key = Input.KeyCode

	if Key == Enum.KeyCode.Space then
		Session.TogglePlay()
	elseif Key == Enum.KeyCode.K then
		Session.KeyAll()
	elseif Key == Enum.KeyCode.Delete then
		Session.DeleteSelectedKeys()
	elseif Key == Enum.KeyCode.Left then
		Session.StepFrames(if Shift then -5 else -1)
	elseif Key == Enum.KeyCode.Right then
		Session.StepFrames(if Shift then 5 else 1)
	elseif Key == Enum.KeyCode.Home then
		Session.Stop()
		Session.Time(0)
	elseif Key == Enum.KeyCode.End then
		Session.Stop()
		Session.Time(Session.Current().Length)
	elseif Key == Enum.KeyCode.R and not Control then
		Session.Tool("Rotate")
	elseif Key == Enum.KeyCode.T and not Control then
		Session.Tool("Move")
	elseif Key == Enum.KeyCode.Escape then
		Session.SelectedKeys({})
		Session.SelectJoint(nil)
	elseif Control and Key == Enum.KeyCode.Z then
		if Shift then
			Session.Redo()
		else
			Session.Undo()
		end
	elseif Control and Key == Enum.KeyCode.Y then
		Session.Redo()
	elseif Control and Key == Enum.KeyCode.C then
		Session.Copy()
	elseif Control and Key == Enum.KeyCode.V then
		Session.Paste()
	elseif Control and Key == Enum.KeyCode.D then
		Session.Copy()
		Session.Paste()
	elseif Control and Key == Enum.KeyCode.A then
		Session.SelectAllKeys()
	end
end

return Hotkeys