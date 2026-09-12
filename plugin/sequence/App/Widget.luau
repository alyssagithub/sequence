--!strict
const Config = require(script.Parent.Parent.Config)

const Widget = {}

function Widget.Create(CurrentPlugin: Plugin): DockWidgetPluginGui
	const Made, Created = pcall(CurrentPlugin.CreateDockWidgetPluginGuiAsync, CurrentPlugin, Config.WidgetId, DockWidgetPluginGuiInfo.new(Enum.InitialDockState.Bottom, true, true, 960, 420, 520, 260))

	if not Made then
		error(`{Config.Name} could not open its window — {Created}`, 0)
	end

	Created.Name = Config.WidgetId
	Created.Title = `{Config.Name} {Config.Version}`
	Created.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

	return Created
end

return Widget