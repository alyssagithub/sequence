--!strict
const RunService = game:GetService("RunService")

if not plugin or RunService:IsRunning() then
	return
end

const Settings = require(script.Parent.Settings)
const App = require(script.Parent.App.App)

Settings.Load(plugin)

const Running = App.New(plugin)

plugin.Unloading:Connect(function()
	Running.Destroy()
end)