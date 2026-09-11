--!strict
const PluginGuiService = game:GetService("PluginGuiService")

const Widget = {}

function Widget.Create(CurrentPlugin: Plugin): DockWidgetPluginGui
	const Existing = PluginGuiService:FindFirstChild("SequenceTestWidget")

	if Existing then
		const Reused = Existing :: DockWidgetPluginGui

		Reused.Enabled = true

		return Reused
	end

	const Made, Created = pcall(CurrentPlugin.CreateDockWidgetPluginGuiAsync, CurrentPlugin, "SequenceTestWidget", DockWidgetPluginGuiInfo.new(Enum.InitialDockState.Bottom, true, true, 960, 420, 520, 260))

	if not Made then
		error(`Sequence could not open its testing window: {Created}`)
	end

	Created.Name = "SequenceTestWidget"
	Created.Title = "Sequence (testing)"
	Created.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

	return Created
end

return Widget