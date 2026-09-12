--!strict
const RunService = game:GetService("RunService")
const Vide = require(script.Parent.Parent.Packages.vide)
const Config = require(script.Parent.Parent.Config)
const Theme = require(script.Parent.Theme)
const Toolbar = require(script.Parent.Toolbar)
const Widget = require(script.Parent.Widget)
const Main = require(script.Parent.Pages.Main)
const ViewportPage = require(script.Parent.Pages.Viewport)
const Session = require(script.Parent.Parent.Editor.Session)
const Gizmo = require(script.Parent.Parent.Editor.Gizmo)
const OnionSkin = require(script.Parent.Parent.Editor.OnionSkin)
const PoseTool = require(script.Parent.Parent.Editor.PoseTool)
const Playtest = require(script.Parent.Parent.Editor.Playtest)
const Reference = require(script.Parent.Parent.Editor.Reference)
const Inserter = require(script.Parent.Parent.Editor.Inserter)

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
		Playtest.Refresh()
	end)

	const Unmount = Vide.mount(Main, Window)
	const Screen = Vide.create "ScreenGui" {
		Name = `{Config.Name}Viewport`,
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		DisplayOrder = 50,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		Parent = game:GetService("CoreGui"),
	}

	const UnmountScreen = Vide.mount(ViewportPage, Screen)

	return {
		Destroy = function()
			EnabledConnection:Disconnect()
			Unmount()
			UnmountScreen()
			Screen:Destroy()
			DestroyEditor()
			Session.Destroy()
			Gizmo.Destroy()
			OnionSkin.Destroy()
			PoseTool.Destroy()
			Playtest.Destroy()
			Reference.Destroy()
			Inserter.Destroy()

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
