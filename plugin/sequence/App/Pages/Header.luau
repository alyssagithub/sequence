--!strict
const Selection = game:GetService("Selection")
const Vide = require(script.Parent.Parent.Parent.Packages.vide)
const Sift = require(script.Parent.Parent.Parent.Packages.sift)
const Settings = require(script.Parent.Parent.Parent.Settings)
const Format = require(script.Parent.Parent.Parent.Format)
const Theme = require(script.Parent.Parent.Theme)
const Overlay = require(script.Parent.Parent.Overlay)
const Session = require(script.Parent.Parent.Parent.Editor.Session)
const Saver = require(script.Parent.Parent.Parent.Editor.Saver)
const Clip = require(script.Parent.Parent.Parent.Editor.Clip)
const Rig = require(script.Parent.Parent.Parent.Editor.Rig)
const PoseTool = require(script.Parent.Parent.Parent.Editor.PoseTool)
const Playtest = require(script.Parent.Parent.Parent.Editor.Playtest)
const Bake = require(script.Parent.Parent.Parent.Editor.Bake)
const IconButton = require(script.Parent.Parent.Components.IconButton)
const TextField = require(script.Parent.Parent.Components.TextField)

const Create = Vide.create

const Properties = {
	"Transparency",
	"Color",
	"Size",
	"CFrame",
	"Position",
	"Orientation",
	"Reflectance",
	"Brightness",
	"Range",
	"Enabled",
	"Value",
	"Volume",
	"PlaybackSpeed",
	"TextTransparency",
	"ImageTransparency",
	"BackgroundTransparency",
	"Rotation",
	"FieldOfView",
}

const function PickRigs(): string?
	local Added = 0

	for _, Picked in Selection:Get() do
		const Model = if Picked:IsA("Model") then Picked else Picked:FindFirstAncestorOfClass("Model")

		if Model and Session.LoadRig(Model) then
			Added += 1
		end
	end

	Session.Offer(nil)

	return if Added > 0 then nil else "Select a model with Motor6D or AnimationConstraint joints first"
end

const function LoadInto(Source: Instance)
	const Loaded = Session.Rig()

	if not Loaded then
		return nil
	end

	const Read, Problem = Saver.FromInstance(Source, Loaded)

	if not Read then
		Session.Say(Problem or "Could not read that animation")

		return
	end

	Session.Confirm("Open", function()
		Session.Replace(Read)
		Session.Say(if Problem then Problem else `Opened {Read.Name}`)
	end)
end

const function OpenEntries(): {Overlay.Entry}?
	const Loaded = Session.Rig()

	if not Loaded then
		return nil
	end

	const Entries: {Overlay.Entry} = {}

	for _, Found in Saver.List(Loaded) do
		table.insert(Entries, {
			Label = `{Found.Animation.Name}  ·  {if Found.Animation:IsA("CurveAnimation") then "curves" else "keyframes"}, {Saver.LocationLabels[Found.Where]}`,
			Action = function()
				LoadInto(Found.Animation)
			end,
		})
	end

	if #Entries == 0 then
		table.insert(Entries, {
			Label = "No saved animations for this rig",
			Disabled = true,
		})
	end

	table.insert(Entries, {Label = "", Divider = true})
	table.insert(Entries, {
		Label = "From selected animation in the Explorer",
		Action = function()
			const Picked = Selection:Get()[1]

			if Picked and (Picked:IsA("KeyframeSequence") or Picked:IsA("CurveAnimation")) then
				LoadInto(Picked)
			else
				Session.Say("Select a KeyframeSequence or CurveAnimation in the Explorer first")
			end
		end,
	})
	table.insert(Entries, {
		Label = "From asset id",
		Action = function()
			Session.Say("Type the asset id into the name box and press Enter")
			Session.ImportPrompt(true)
		end,
	})

	return Entries
end

const function SaveEntries(): {Overlay.Entry}?
	const Loaded = Session.Rig()

	if not Loaded then
		return nil
	end

	const Entries: {Overlay.Entry} = {}

	for _, Where in Saver.Locations do
		table.insert(Entries, {
			Label = `Save to {Saver.LocationLabels[Where]}`,
			Checked = Settings.Get("SaveLocation")() == Where,
			Action = function()
				Settings.Set("SaveLocation", Where)
				Saver.Save(Session.Current(), Loaded, Where, Settings.Get("SaveAsCurve")(), Session.FrameRate())
				Session.Dirty(false)
				Session.Say(`Saved {Session.Current().Name} to {Saver.LocationLabels[Where]}`)
			end,
		})
	end

	table.insert(Entries, {Label = "", Divider = true})
	table.insert(Entries, {
		Label = "Save as KeyframeSequence",
		Checked = not Settings.Get("SaveAsCurve")(),
		Action = function()
			Settings.Set("SaveAsCurve", false)
		end,
	})
	table.insert(Entries, {
		Label = "Save as CurveAnimation",
		Checked = Settings.Get("SaveAsCurve")() == true,
		Action = function()
			Settings.Set("SaveAsCurve", true)
		end,
	})
	table.insert(Entries, {Label = "", Divider = true})
	table.insert(Entries, {
		Label = "Convert the selected animation between keyframes and curves",
		Action = function()
			const Picked = Selection:Get()[1]

			if not Picked or not (Picked:IsA("KeyframeSequence") or Picked:IsA("CurveAnimation")) then
				Session.Say("Select a KeyframeSequence or CurveAnimation in the Explorer first")

				return
			end

			const Made, Problem = Saver.Convert(Picked, Loaded, Session.FrameRate())

			if Made then
				Selection:Set({Made})
				Session.Say(`Converted {Made.Name} to {if Made:IsA("CurveAnimation") then "curves" else "keyframes"}{if Problem then `, {Problem}` else ""}`)
			else
				Session.Say(Problem or "Could not convert")
			end
		end,
	})

	return Entries
end


const function PropertyEntries(): {Overlay.Entry}?
	const Picked = Selection:Get()[1]

	if not Picked then
		Session.Say("Select the object to animate in the Explorer first")

		return nil
	end

	const Entries: {Overlay.Entry} = {}

	for _, Property in Properties do
		const Ok = pcall(function()
			return (Picked :: any)[Property]
		end)

		if Ok then
			table.insert(Entries, {
				Label = `{Picked.Name}.{Property}`,
				Action = function()
					if Session.AddPropertyTrack(Picked, Property) then
						Session.Say(`Keyframe {Picked.Name}.{Property} by changing it in the Properties window, then pressing its diamond`)
					end
				end,
			})
		end
	end

	if #Entries == 0 then
		table.insert(Entries, {
			Label = `{Picked.Name} has nothing here to animate`,
			Disabled = true,
		})
	end

	return Entries
end

const function ClipEntries(): {Overlay.Entry}?
	const Entries: {Overlay.Entry} = {}

	for _, Length in {0.5, 1, 2, 3, 5, 10} do
		table.insert(Entries, {
			Label = `Length {Length}s`,
			Checked = Session.Current().Length == Length,
			Action = function()
				Session.Edit(Clip.SetLength(Session.Current(), Length))
				Session.Time(math.min(Session.Time(), Session.Current().Length))
			end,
		})
	end

	table.insert(Entries, {Label = "", Divider = true})

	for _, Rate in {24, 30, 60} do
		table.insert(Entries, {
			Label = `{Rate} fps`,
			Checked = Session.FrameRate() == Rate,
			Action = function()
				Session.FrameRate(Rate)
				Settings.Set("FrameRate", Rate)
			end,
		})
	end

	table.insert(Entries, {Label = "", Divider = true})

	for _, Speed in {0.25, 0.5, 1, 2} do
		table.insert(Entries, {
			Label = `{Speed}x speed`,
			Checked = Session.Speed() == Speed,
			Action = function()
				Session.Speed(Speed)
			end,
		})
	end

	table.insert(Entries, {Label = "", Divider = true})

	for _, Priority in Clip.Priorities do
		table.insert(Entries, {
			Label = `Priority {Priority}`,
			Checked = Session.Current().Priority == Priority,
			Action = function()
				Session.Edit(Sift.Dictionary.merge(Session.Current(), {Priority = Priority}))
			end,
		})
	end

	return Entries
end

const function BakeEntries(): {Overlay.Entry}?
	const Loaded = Session.Rig()

	if not Loaded then
		return nil
	end

	return {
		{
			Label = "Bake this pose as a frozen copy",
			Action = function()
				Bake.Place(Loaded, Session.Current(), {Session.Time()})
				Session.Say("A posed copy of the rig was placed beside it and selected")
			end,
		},
		{
			Label = "Bake every keyframe as a copy",
			Action = function()
				const Times = Clip.KeyTimes(Session.Current())

				Bake.Place(Loaded, Session.Current(), Times)
				Session.Say(`{#Times} posed copies were placed beside the rig`)
			end,
		},
	}
end


const function SnapEntries(): {Overlay.Entry}?
	const Entries: {Overlay.Entry} = {}

	for _, Mode in {"Off", "Frames", "Keys"} do
		table.insert(Entries, {
			Label = if Mode == "Keys" then "Snap to keyframes and frames" elseif Mode == "Frames" then "Snap to frames" else "No snapping",
			Checked = Session.Snap() == Mode,
			Action = function()
				Session.Snap(Mode)
			end,
		})
	end

	table.insert(Entries, {Label = "", Divider = true})

	for _, Rate in {24, 30, 60} do
		table.insert(Entries, {
			Label = `{Rate} frames per second`,
			Checked = Session.FrameRate() == Rate,
			Action = function()
				Session.FrameRate(Rate)
				Settings.Set("FrameRate", Rate)
			end,
		})
	end

	return Entries
end

const function Sub(Label: string, Entries: () -> {Overlay.Entry}?, Anchor: () -> GuiObject): Overlay.Entry
	return {
		Label = `{Label}  ›`,
		Action = function()
			const Made = Entries()

			if Made then
				task.defer(Overlay.Menu, Anchor(), Made, 300)
			end
		end,
	}
end

return function()
	local MenuAnchor: GuiObject

	const function NoRig(): boolean
		return Session.Rig() == nil
	end

	const function Anchor(): GuiObject
		return MenuAnchor
	end

	const function MainMenu()
		const Loaded = Session.Rig()

		Overlay.Menu(MenuAnchor, {
			{
				Label = "New animation",
				Disabled = NoRig(),
				Action = function()
					Session.Confirm("New", function()
						Session.Replace(Clip.New("Animation"))
					end)
				end,
			},
			Sub("Open", OpenEntries, Anchor),
			{
				Label = `Save to {Saver.LocationLabels[Settings.Get("SaveLocation")()]}`,
				Disabled = NoRig(),
				Action = function()
					const Where = Settings.Get("SaveLocation")()

					Saver.Save(Session.Current(), Loaded :: Rig.Rig, Where, Settings.Get("SaveAsCurve")(), Session.FrameRate())
					Session.Dirty(false)
					Session.Say(`Saved {Session.Current().Name} to {Saver.LocationLabels[Where]}`)
				end,
			},
			Sub("Save options", SaveEntries, Anchor),
			{
				Label = "Publish to Roblox",
				Disabled = NoRig(),
				Action = function()
					Saver.Publish(Session.Current(), Loaded :: Rig.Rig, Session.Plugin :: Plugin, Settings.Get("SaveLocation")(), Settings.Get("SaveAsCurve")(), Session.FrameRate())
				end,
			},
			{Label = "", Divider = true},
			Sub("Clip settings", ClipEntries, Anchor),
			{
				Label = "Loop",
				Checked = Session.Current().Looping,
				Disabled = NoRig(),
				Action = function()
					Session.Edit(Sift.Dictionary.merge(Session.Current(), {Looping = not Session.Current().Looping}))
				end,
			},
			Sub("Snap", SnapEntries, Anchor),
			{Label = "", Divider = true},
			{
				Label = "Mirror pose",
				Disabled = NoRig(),
				Action = function()
					Session.MirrorPose(nil)
				end,
			},
			{
				Label = "Pose tool, drag parts in the viewport",
				Checked = PoseTool.Active(),
				Disabled = NoRig(),
				Action = PoseTool.Toggle,
			},
			Sub("Animate a property of the selection", PropertyEntries, Anchor),
			Sub("Bake a posed copy", BakeEntries, Anchor),
			{
				Label = "Playtest on my character",
				Checked = Playtest.Ready(),
				Disabled = NoRig(),
				Action = Playtest.Toggle,
			},
			{Label = "", Divider = true},
			{
				Label = "Curve editor",
				Checked = Session.View() == "Curves",
				Action = function()
					Session.View(if Session.View() == "Curves" then "Sheet" else "Curves")
				end,
			},
			{
				Label = "Reference panel",
				Checked = Session.Panel() == "Reference",
				Action = function()
					Session.Panel(if Session.Panel() == "Reference" then nil else "Reference")
				end,
			},
			{
				Label = "Emote panel",
				Checked = Session.Panel() == "Emote",
				Disabled = NoRig(),
				Action = function()
					Session.Panel(if Session.Panel() == "Emote" then nil else "Emote")
				end,
			},
			{Label = "", Divider = true},
			{
				Label = "Add an event at the playhead",
				Disabled = NoRig(),
				Action = function()
					const Time = Session.SnapTime(Session.Time())

					Session.Edit(Clip.SetMarker(Session.Current(), {
						Time = Time,
						Name = "Event",
						Value = "",
					}))
					Session.SelectedMarker(Clip.FindMarker(Session.Current(), Time, "Event"))
				end,
			},
			{
				Label = "Undo",
				Disabled = Session.UndoCount() == 0,
				Action = Session.Undo,
			},
			{
				Label = "Redo",
				Disabled = Session.RedoCount() == 0,
				Action = Session.Redo,
			},
			{
				Label = "Release every rig",
				Disabled = NoRig(),
				Action = function()
					Session.Confirm("Release", Session.ReleaseAll)
				end,
			},
		}, 260)
	end

	const Rail = Create "Frame" {
		Name = "Rail",
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.new(0, 0, 1, 0),
		BackgroundColor3 = Theme.Colors.Panel,
		LayoutOrder = 0,
		ZIndex = 5,

		Create "UIPadding" {
			PaddingLeft = UDim.new(0, 3),
			PaddingRight = UDim.new(0, 3),
			PaddingTop = UDim.new(0, 3),
		},
		Create "UIGridLayout" {
			CellSize = UDim2.fromOffset(24, 24),
			CellPadding = UDim2.fromOffset(2, 1),
			FillDirection = Enum.FillDirection.Vertical,
			SortOrder = Enum.SortOrder.LayoutOrder,
		},
		IconButton {
			Icon = "person-standing",
			Tooltip = "Insert a character",
			LayoutOrder = 1,
			OnClick = function()
				Session.Panel("Insert")
			end,
		},
		IconButton {
			Icon = "plus",
			Tooltip = "Add the selected rigs to the timeline",
			LayoutOrder = 2,
			OnClick = function()
				const Problem = PickRigs()

				if Problem then
					Session.Say(Problem)
				end
			end,
		},
		Create "TextButton" {
			Name = "MenuAnchor",
			BackgroundTransparency = 1,
			Text = "",
			LayoutOrder = 3,

			Vide.action(function(Object: TextButton)
				MenuAnchor = Object
			end),

			IconButton {
				Icon = "ellipsis",
				Tooltip = function()
					return if Session.Dirty() then "Everything else (unsaved changes)" else "Everything else"
				end,
				OnClick = MainMenu,
			},
		},
		IconButton {
			Icon = "skip-back",
			Tooltip = "Go to start (Home)",
			LayoutOrder = 6,
			Disabled = NoRig,
			OnClick = function()
				Session.Stop()
				Session.Time(0)
			end,
		},
		IconButton {
			Icon = "step-back",
			Tooltip = "Previous frame (Left)",
			LayoutOrder = 7,
			Disabled = NoRig,
			OnClick = function()
				Session.StepFrames(-1)
			end,
		},
		IconButton {
			Icon = function()
				return if Session.Playing() then "pause" else "play"
			end,
			Tooltip = "Play or pause (Space)",
			LayoutOrder = 8,
			Disabled = NoRig,
			Active = Session.Playing,
			OnClick = Session.TogglePlay,
		},
		IconButton {
			Icon = "step-forward",
			Tooltip = "Next frame (Right)",
			LayoutOrder = 9,
			Disabled = NoRig,
			OnClick = function()
				Session.StepFrames(1)
			end,
		},
		IconButton {
			Icon = "skip-forward",
			Tooltip = "Go to end (End)",
			LayoutOrder = 10,
			Disabled = NoRig,
			OnClick = function()
				Session.Stop()
				Session.Time(Session.SceneLength())
			end,
		},
		IconButton {
			Icon = function()
				return if Session.Tool() == "Rotate" then "rotate-3d" else "move-3d"
			end,
			Tooltip = function()
				return if Session.Tool() == "Rotate" then "Rotating joints, click to move instead (R / T)" else "Moving joints, click to rotate instead (R / T)"
			end,
			LayoutOrder = 14,
			Disabled = NoRig,
			OnClick = function()
				Session.Tool(if Session.Tool() == "Rotate" then "Move" else "Rotate")
			end,
		},
		IconButton {
			Icon = "key-round",
			Tooltip = function()
				return if Session.AutoKey() then "Auto key on, every pose change keys (K keys by hand)" else "Auto key off, pose freely then press K"
			end,
			LayoutOrder = 15,
			Disabled = NoRig,
			Active = Session.AutoKey,
			OnClick = function()
				if Session.AutoKey() then
					Session.AutoKey(false)
				else
					Session.CommitScratch()
					Session.AutoKey(true)
				end
			end,
		},
		IconButton {
			Icon = "ghost",
			Tooltip = "Onion skin",
			LayoutOrder = 16,
			Disabled = NoRig,
			Active = Session.OnionSkin,
			OnClick = function()
				Session.OnionSkin(not Session.OnionSkin())
			end,
		},
		IconButton {
			Icon = "diamond",
			Tooltip = "Keyframe the selected joint, or every joint (K)",
			LayoutOrder = 17,
			Disabled = NoRig,
			OnClick = function()
				Session.CommitScratch()
				Session.KeyAll()
			end,
		},
	}

	const NameRow = Create "Frame" {
		Name = "NameRow",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,

		Create "UIPadding" {
			PaddingLeft = UDim.new(0, 4),
			PaddingRight = UDim.new(0, 4),
		},
		Create "UIListLayout" {
			FillDirection = Enum.FillDirection.Horizontal,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			Padding = UDim.new(0, 4),
			SortOrder = Enum.SortOrder.LayoutOrder,
		},
		TextField {
			Value = function()
				return if Session.ImportPrompt() then "" else Session.Current().Name
			end,
			Placeholder = function()
				return if Session.ImportPrompt() then "Asset id" else "Animation name"
			end,
			Width = 120,
			Bold = true,
			LayoutOrder = 1,
			OnBlur = function()
				Session.ImportPrompt(false)
			end,
			OnChange = function(Text: string)
				if Session.ImportPrompt() then
					Session.ImportPrompt(false)

					const AssetId = tonumber(Text:match("%d+"))

					if not AssetId then
						Session.Say("That is not an asset id")

						return
					end

					const Source, Problem = Saver.Import(AssetId)

					if not Source then
						Session.Say(Problem or "Import failed")

						return
					end

					LoadInto(Source)

					return
				end

				if Text == "" then
					return
				end

				Session.Edit(Sift.Dictionary.merge(Session.Current(), {Name = Text}))
			end,
		},
		Create "TextLabel" {
			Name = "Clock",
			AutomaticSize = Enum.AutomaticSize.X,
			Size = UDim2.fromScale(0, 1),
			BackgroundTransparency = 1,
			TextColor3 = Theme.Colors.DimText,
			FontFace = Font.fromEnum(Enum.Font.RobotoMono),
			LayoutOrder = 2,
			TextSize = Settings.SmallText,
			Text = function()
				return `{Format.Timecode(Session.Time(), Session.FrameRate())} / {Format.Timecode(Session.Current().Length, Session.FrameRate())}`
			end,

			Create "UIPadding" {
				PaddingLeft = UDim.new(0, 4),
				PaddingRight = UDim.new(0, 4),
			},
		},
	}

	return {
		Rail = Rail,
		NameRow = NameRow,
	}
end