--!strict
const PluginGuiService = game:GetService("PluginGuiService")
const RunService = game:GetService("RunService")
const Lighting = game:GetService("Lighting")

export type Progress = {
	Mount: Instance?,
}

const function Import(Target: Instance): any
	const Ok, Module = pcall(require, Target)

	if not Ok then
		error(Module, 0)
	end

	return Module
end

const Testing = {}

const function State(): Progress
	if not _G.SequenceTestState then
		_G.SequenceTestState = {}
	end

	return _G.SequenceTestState :: any
end

const function Beside(): Instance?
	const Mounted = State().Mount

	if Mounted == nil or not (Mounted :: Instance):IsDescendantOf(game) then
		return nil
	end

	return Mounted
end

function Testing.Refresh(): any
	const Fresh = script:Clone()
	const Loaded = Import(Fresh)

	Fresh:Destroy()

	return Loaded
end

function Testing.Leftovers(): string
	const Found = {}
	const Source = script.Parent :: Instance
	const Mounted = Beside()

	const function Ours(Object: Instance): boolean
		return Object:IsDescendantOf(Source) or Object == Source or (Mounted ~= nil and (Object == Mounted or Object:IsDescendantOf(Mounted :: Instance)))
	end

	const function Walk(Object: Instance)
		for _, Child in Object:GetChildren() do
			if Child == PluginGuiService then
				continue
			end

			if Child.Name:match("^sequence") and not Ours(Child) then
				table.insert(Found, Child:GetFullName())
			end

			if not Ours(Child) then
				Walk(Child)
			end
		end
	end

	Walk(game)

	const Siblings: {Instance} = if Source.Parent then Source.Parent:GetChildren() else {}

	for _, Child in Siblings do
		if Child.Name:match("Testing$") and Child ~= Mounted then
			table.insert(Found, `extra mount at {Child:GetFullName()}`)
		end
	end

	const Widget = PluginGuiService:FindFirstChild("SequenceTestWidget")
	const Shown: {Instance} = if Widget then Widget:GetChildren() else {}

	if #Shown > 1 then
		table.insert(Found, `{#Shown} pages stacked in the test widget`)
	end

	return if #Found == 0 then "Nothing left behind" else table.concat(Found, "\n")
end

function Testing.Find(Name: string): Instance?
	const Widget = PluginGuiService:FindFirstChild("SequenceTestWidget")

	return if Widget then Widget:FindFirstChild(Name, true) else nil
end

function Testing.Unmount(): string
	const Folder = Beside()

	if _G.SequenceTestApp then
		pcall((_G.SequenceTestApp :: {Destroy: () -> ()}).Destroy)

		_G.SequenceTestApp = nil
	end

	const Widget = PluginGuiService:FindFirstChild("SequenceTestWidget")
	const Open: {Instance} = if Widget then Widget:GetChildren() else {}

	for _, Child in Open do
		Child:Destroy()
	end

	if Widget then
		(Widget :: DockWidgetPluginGui).Enabled = false
	end

	pcall(function()
		require((script :: any).ToolbarStub).Retire()
	end)

	if not Folder then
		return "Nothing was mounted"
	end

	const Where = Folder:GetFullName()

	Folder:Destroy()
	State().Mount = nil

	return `Unmounted {Where}`
end

function Testing.Mount(CurrentPlugin: Plugin): string
	Testing.Unmount()

	const Source = script.Parent :: Instance
	const Home = Source.Parent

	if not Home then
		return "Sequence needs a parent folder so the test copy can sit beside it"
	end

	const Copy = Source:Clone() :: any

	Copy.Name = `{Source.Name}Testing`
	Copy.Plugin:Destroy()
	Copy.Testing:Destroy()

	for _, Call in {
		"Window",
		"Button",
		"Bar",
	} do
		Copy.App.App.Source = Copy.App.App.Source:gsub(`{Call}:Destroy%(%)`, "")
	end

	const Stubs: {[string]: Instance} = {
		Widget = (script :: any).WidgetStub,
		Toolbar = (script :: any).ToolbarStub,
	}

	for Name, Replacement in Stubs do
		const Stub = Replacement:Clone()

		Copy.App[Name]:Destroy()
		Stub.Name = Name
		Stub.Parent = Copy.App
	end

	Copy.Parent = Home
	State().Mount = Copy

	Import(Copy.Settings).Load(CurrentPlugin)

	_G.SequenceTestApp = Import(Copy.App.App).New(CurrentPlugin)

	return `Mounted {Copy:GetFullName()}`
end

function Testing.Hide(): string
	const Staged = workspace:FindFirstChild("SequenceShotStage")

	if Staged then
		Staged:Destroy()
	end

	const Dimmed = _G.SequenceShotLighting :: any

	if Dimmed then
		for Name, Value in Dimmed.Properties do
			(Lighting :: any)[Name] = Value
		end

		for _, Held in Dimmed.Effects do
			if Held.Parent then
				Held.Object.Parent = Held.Parent
			else
				Held.Object.Enabled = Held.Enabled
			end
		end

		_G.SequenceShotLighting = nil
	end

	const Saved = _G.SequenceShotCamera :: {CFrame: CFrame, FieldOfView: number}?

	if not Saved then
		return "Nothing was staged"
	end

	workspace.CurrentCamera.CFrame = (Saved :: any).CFrame
	workspace.CurrentCamera.FieldOfView = (Saved :: any).FieldOfView
	_G.SequenceShotCamera = nil

	return "Cleared the stage and put the camera back"
end

function Testing.Show(Name: string?, Narrowed: number?): string
	Testing.Hide()

	const Widget = PluginGuiService:FindFirstChild("SequenceTestWidget")

	if not Widget then
		return "Nothing is mounted"
	end

	local Target: GuiObject?

	if Name then
		const Found = Widget:FindFirstChild(Name, true)

		Target = if Found and Found:IsA("GuiObject") then Found else nil
	else
		Target = Widget:FindFirstChildWhichIsA("GuiObject")
	end

	if not Target then
		return `Found nothing called "{Name}" to show`
	end

	const Shown = Target :: GuiObject

	if Shown.AbsoluteSize.X < 1 or Shown.AbsoluteSize.Y < 1 then
		return `{Shown.Name} is not being drawn, so there is nothing to capture`
	end

	const Camera = workspace.CurrentCamera

	_G.SequenceShotCamera = {CFrame = Camera.CFrame, FieldOfView = Camera.FieldOfView}

	const Effects = {}

	for _, Object in Lighting:GetDescendants() do
		if Object:IsA("Atmosphere") then
			table.insert(Effects, {Object = Object, Parent = Object.Parent})
		elseif Object:IsA("PostEffect") then
			table.insert(Effects, {Object = Object, Enabled = Object.Enabled})
		end
	end

	_G.SequenceShotLighting = {
		Properties = {
			Ambient = Lighting.Ambient,
			OutdoorAmbient = Lighting.OutdoorAmbient,
			Brightness = Lighting.Brightness,
			FogEnd = Lighting.FogEnd,
			ExposureCompensation = Lighting.ExposureCompensation,
			GlobalShadows = Lighting.GlobalShadows,
		},
		Effects = Effects,
	}

	for _, Held in Effects do
		if Held.Parent then
			Held.Object.Parent = nil
		else
			Held.Object.Enabled = false
		end
	end

	Lighting.Ambient = Color3.new()
	Lighting.OutdoorAmbient = Color3.new()
	Lighting.Brightness = 0
	Lighting.FogEnd = 1e6
	Lighting.ExposureCompensation = 0
	Lighting.GlobalShadows = false

	const Pixels = 100
	const Width = Narrowed or Shown.AbsoluteSize.X
	const Height = Shown.AbsoluteSize.Y

	const Screen = Instance.new("Part")

	Screen.Name = "SequenceShotStage"
	Screen.Anchored = true
	Screen.CanCollide = false
	Screen.CanQuery = false
	Screen.CanTouch = false
	Screen.CastShadow = false
	Screen.Size = Vector3.new(Width / Pixels, Height / Pixels, 0.05)
	Screen.CFrame = CFrame.new(0, 5000, 0)
	Screen.Color = Color3.fromRGB(20, 20, 20)
	Screen.Parent = workspace

	const Backdrop = Instance.new("Part")

	Backdrop.Name = "Backdrop"
	Backdrop.Anchored = true
	Backdrop.CanCollide = false
	Backdrop.CanQuery = false
	Backdrop.CanTouch = false
	Backdrop.CastShadow = false
	Backdrop.Material = Enum.Material.SmoothPlastic
	Backdrop.Size = Vector3.new(Screen.Size.X * 6, Screen.Size.Y * 6, 0.05)
	Backdrop.CFrame = Screen.CFrame * CFrame.new(0, 0, -1)
	Backdrop.Color = Color3.fromRGB(128, 128, 128)
	Backdrop.Parent = Screen

	const Surface = Instance.new("SurfaceGui")

	Surface.Face = Enum.NormalId.Back
	Surface.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	Surface.PixelsPerStud = Pixels
	Surface.LightInfluence = 0
	Surface.Parent = Screen

	const Copy = Shown:Clone()

	Copy.Position = UDim2.fromOffset(0, 0)
	Copy.Size = UDim2.fromOffset(Width, Height)
	Copy.AnchorPoint = Vector2.zero
	Copy.Visible = true
	Copy.Parent = Surface

	const Scrolled = Shown:GetDescendants()

	const function MatchScroll()
		for Index, Object in Copy:GetDescendants() do
			if Object:IsA("ScrollingFrame") and Scrolled[Index]:IsA("ScrollingFrame") then
				Object.CanvasPosition = (Scrolled[Index] :: ScrollingFrame).CanvasPosition
			end
		end
	end

	MatchScroll()

	const Reach = math.tan(math.rad(Camera.FieldOfView / 2))
	const Across = Camera.ViewportSize.X / Camera.ViewportSize.Y
	const Fit = math.max((Screen.Size.Y / 2 + 16 / Pixels) / Reach, (Screen.Size.X / 2 + 16 / Pixels) / (Reach * Across))
	const Distance = math.max(Camera.ViewportSize.Y / (2 * Pixels * Reach), Fit)

	Camera.CFrame = CFrame.lookAt(Screen.Position + Vector3.new(0, 0, Distance), Screen.Position)

	task.delay(300, function()
		if workspace:FindFirstChild("SequenceShotStage") == Screen then
			Testing.Hide()
		end
	end)

	for _ = 1, 4 do
		RunService.Heartbeat:Wait()
	end

	MatchScroll()

	return `Showing {Shown.Name} at {math.floor(Width)}x{math.floor(Height)}, drawn at {string.format("%.3f", Camera.ViewportSize.Y / (2 * Distance * Reach) / Pixels)} screen pixels per interface pixel, call Testing.Hide() when the screenshot is taken`
end

function Testing.Paint(Name: string?): string
	const Folder = Beside()

	if not Folder then
		return "Nothing is mounted"
	end

	const Theme = Import((Folder :: any).App.Theme)

	if not Name then
		Theme.Paint(nil)

		return `Painting with Studio's own theme again, which is {settings().Studio.Theme.Name}`
	end

	const Offered = {}

	for _, Choice in settings().Studio:GetAvailableThemes() do
		if Choice.Name == Name then
			Theme.Paint(Choice)

			return `Painting the mount as {Choice.Name} while Studio stays on {settings().Studio.Theme.Name}`
		end

		table.insert(Offered, Choice.Name)
	end

	return `No theme called "{Name}", try one of {table.concat(Offered, ", ")}`
end

function Testing.Colours(Name: string?): {string}
	const Widget = PluginGuiService:FindFirstChild("SequenceTestWidget")

	if not Widget then
		return {"Nothing is mounted"}
	end

	const Root = if Name then Widget:FindFirstChild(Name, true) else Widget

	if not Root then
		return {`Found nothing called "{Name}"`}
	end

	const Counts: {[string]: number} = {}
	const Where: {[string]: string} = {}

	const function Note(Object: Instance, Property: string, Colour: Color3)
		const Key = `{math.round(Colour.R * 255)},{math.round(Colour.G * 255)},{math.round(Colour.B * 255)} {Property}`

		Counts[Key] = (Counts[Key] or 0) + 1
		Where[Key] = Where[Key] or `{Object.Name}`
	end

	for _, Object in Root:GetDescendants() do
		if not Object:IsA("GuiObject") then
			continue
		end

		if Object.BackgroundTransparency < 1 then
			Note(Object, "background", Object.BackgroundColor3)
		end

		if Object:IsA("TextLabel") or Object:IsA("TextButton") or Object:IsA("TextBox") then
			Note(Object, "text", (Object :: any).TextColor3)
		end

		if Object:IsA("ImageLabel") or Object:IsA("ImageButton") then
			Note(Object, "image", (Object :: any).ImageColor3)
		end

		const Stroke = Object:FindFirstChildOfClass("UIStroke")

		if Stroke then
			Note(Object, "stroke", Stroke.Color)
		end
	end

	const Lines = {}

	for Key, Count in Counts do
		table.insert(Lines, `{Key} x{Count} (first on {Where[Key]})`)
	end

	table.sort(Lines)

	return Lines
end

function Testing.With(Values: {[string]: any}, Run: () -> ())
	const Folder = Beside()

	if not Folder then
		error("Mount before changing settings, so the test copy is the one being changed")
	end

	const Settings = Import((Folder :: any).Settings)
	const Before = {}

	for Key, Value in Values do
		Before[Key] = Settings.Get(Key)()
		Settings.Set(Key, Value)
	end

	const Outcome = table.pack(pcall(Run))

	for Key, Value in Before do
		Settings.Set(Key, Value)
	end

	if not Outcome[1] then
		error(Outcome[2])
	end
end

return Testing