--!strict
const RunService = game:GetService("RunService")
const Vide = require(script.Parent.Parent.Packages.vide)
const Theme = require(script.Parent.Theme)
const Toolbar = require(script.Parent.Toolbar)
const Widget = require(script.Parent.Widget)
const Main = require(script.Parent.Pages.Main)
const Session = require(script.Parent.Parent.Editor.Session)
const Gizmo = require(script.Parent.Parent.Editor.Gizmo)
const OnionSkin = require(script.Parent.Parent.Editor.OnionSkin)

const App = {}

function App.New(CurrentPlugin: Plugin)
	Theme.Init()

	const Window = Widget.Create(CurrentPlugin)
	const Bar, Button = Toolbar.Create(CurrentPlugin, function()
		Window.Enabled = not Window.Enabled
	end)

	Button:SetActive(Window.Enabled)

	const EnabledConnection = Window:GetPropertyChangedSignal("Enabled"):Connect(function()
		Button:SetActive(Window.Enabled)
	end)

	const DestroyEditor = Vide.root(function()
		Session.Start(CurrentPlugin)
		Gizmo.Start()
		OnionSkin.Start()
	end)

	const Unmount = Vide.mount(Main, Window)

	return {
		Destroy = function()
			EnabledConnection:Disconnect()
			Unmount()
			DestroyEditor()
			Session.Destroy()
			Gizmo.Destroy()
			OnionSkin.Destroy()

			if RunService:IsRunning() then
				Window.Enabled = false
			else
				Window:Destroy()
				Button:Destroy()
				Bar:Destroy()
			end

			Theme.Destroy()
		end,
	}
end

return App
