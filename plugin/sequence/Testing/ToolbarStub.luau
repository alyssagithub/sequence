--!strict
const Toolbar = {}

function Toolbar.Create(CurrentPlugin: Plugin, OnClick: () -> ()): (PluginToolbar, PluginToolbarButton)
	if not _G.SequenceTestBar then
		const Bar = CurrentPlugin:CreateToolbar("sequence testing")

		_G.SequenceTestBar = Bar
		_G.SequenceTestButton = Bar:CreateButton("SequenceTestOpen", "Open the sequence test editor", "", "sequence")
	end

	const Button = _G.SequenceTestButton :: PluginToolbarButton

	Button.ClickableWhenViewportHidden = true

	if _G.SequenceTestClick then
		(_G.SequenceTestClick :: RBXScriptConnection):Disconnect()
	end

	_G.SequenceTestClick = Button.Click:Connect(OnClick)
	Button.Enabled = true

	return _G.SequenceTestBar :: PluginToolbar, Button
end

function Toolbar.Retire()
	if _G.SequenceTestClick then
		(_G.SequenceTestClick :: RBXScriptConnection):Disconnect()

		_G.SequenceTestClick = nil
	end

	if _G.SequenceTestButton then
		(_G.SequenceTestButton :: PluginToolbarButton).Enabled = false
	end
end

return Toolbar