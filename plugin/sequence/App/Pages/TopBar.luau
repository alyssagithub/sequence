--!strict
const Selection = game:GetService("Selection")
const Vide = require(script.Parent.Parent.Parent.Packages.vide)
const Sift = require(script.Parent.Parent.Parent.Packages.sift)
const Settings = require(script.Parent.Parent.Parent.Settings)
const Theme = require(script.Parent.Parent.Theme)
const Overlay = require(script.Parent.Parent.Overlay)
const Session = require(script.Parent.Parent.Parent.Editor.Session)
const Saver = require(script.Parent.Parent.Parent.Editor.Saver)
const Clip = require(script.Parent.Parent.Parent.Editor.Clip)
const Rig = require(script.Parent.Parent.Parent.Editor.Rig)
const IconButton = require(script.Parent.Parent.Components.IconButton)
const TextField = require(script.Parent.Parent.Components.TextField)
const Icon = require(script.Parent.Parent.Components.Icon)

const Create = Vide.create

const function PickRigs(): string?
	local Added = 0

	for _, Picked in Selection:Get() do
		const Model = if Picked:IsA("Model") then Picked else Picked:FindFirstAncestorOfClass("Model")

		if Model and Session.LoadRig(Model) then
			Added += 1
		end
	end

	return if Added > 0 then nil else "Select a model with Motor6D or AnimationConstraint joints first"
end

const function LoadInto(Source: Instance)
	const Loaded = Session.Rig()

	if not Loaded then
		return
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

const function OpenMenu(Anchor: GuiObject)
	const Loaded = Session.Rig()

	if not Loaded then
		return
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

	Overlay.Menu(Anchor, Entries, 320)
end

const function SaveMenu(Anchor: GuiObject)
	const Loaded = Session.Rig()

	if not Loaded then
		return
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

	Overlay.Menu(Anchor, Entries, 340)
end

return function()
	local OpenAnchor: GuiObject
	local SaveAnchor: GuiObject

	const function Disabled(): boolean
		return Session.Rig() == nil
	end

	const function Anchored(Name: string, Order: number, Button: Instance, Set: (GuiObject) -> ())
		return Create "TextButton" {
			Name = Name,
			Size = function()
				return UDim2.fromOffset(Settings.TextSize() + 12, Settings.TextSize() + 8)
			end,
			BackgroundTransparency = 1,
			Text = "",
			LayoutOrder = Order,

			Vide.action(function(Object: TextButton)
				Set(Object)
			end),

			Button,
		}
	end

	return Create "Frame" {
		Name = "TopBar",
		Size = UDim2.new(1, 0, 0, 36),
		BackgroundColor3 = Theme.Colors.Panel,

		Create "UIPadding" {
			PaddingLeft = UDim.new(0, 8),
			PaddingRight = UDim.new(0, 8),
		},
		Create "UIListLayout" {
			FillDirection = Enum.FillDirection.Horizontal,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			Padding = UDim.new(0, 6),
			SortOrder = Enum.SortOrder.LayoutOrder,
		},
		Create "TextButton" {
			Name = "RigButton",
			AutomaticSize = Enum.AutomaticSize.X,
			Size = function()
				return UDim2.fromOffset(0, Settings.TextSize() + 10)
			end,
			BackgroundColor3 = Theme.Colors.Button,
			Text = "",
			AutoButtonColor = true,
			LayoutOrder = 1,
			Activated = function()
				const Problem = PickRigs()

				if Problem then
					Session.Say(Problem)
				end
			end,

			Create "UICorner" {CornerRadius = UDim.new(0, 4)},
			Create "UIPadding" {
				PaddingLeft = UDim.new(0, 8),
				PaddingRight = UDim.new(0, 8),
			},
			Create "UIListLayout" {
				FillDirection = Enum.FillDirection.Horizontal,
				VerticalAlignment = Enum.VerticalAlignment.Center,
				Padding = UDim.new(0, 6),
			},
			Icon {
				Name = function()
					return if Session.Rig() then "plus" else "person-standing"
				end,
				Colour = Theme.Colors.ButtonText,
				LayoutOrder = 1,
			},
			Create "TextLabel" {
				AutomaticSize = Enum.AutomaticSize.X,
				Size = UDim2.fromScale(0, 1),
				BackgroundTransparency = 1,
				TextColor3 = Theme.Colors.ButtonText,
				TextSize = Settings.TextSize,
				FontFace = Font.fromEnum(Enum.Font.BuilderSansMedium),
				LayoutOrder = 2,
				Text = function()
					const Loaded = Session.Rig()

					return if Loaded then Loaded.Model.Name else "Pick a rig"
				end,
			},
		},
		TextField {
			Value = function()
				return if Session.ImportPrompt() then "" else Session.Current().Name
			end,
			Placeholder = "Animation name",
			Width = 170,
			Bold = true,
			LayoutOrder = 2,
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
		Create "Frame" {
			Name = "Gap",
			Size = UDim2.fromOffset(6, 1),
			BackgroundTransparency = 1,
			LayoutOrder = 3,
		},
		IconButton {
			Icon = "file-plus",
			Tooltip = "New animation",
			LayoutOrder = 4,
			Disabled = Disabled,
			OnClick = function()
				Session.Confirm("New", function()
					Session.Replace(Clip.New("Animation"))
				end)
			end,
		},
		Anchored("OpenAnchor", 5, IconButton {
			Icon = "folder-open",
			Tooltip = "Open a saved animation",
			Disabled = Disabled,
			OnClick = function()
				OpenMenu(OpenAnchor)
			end,
		}, function(Object: GuiObject)
			OpenAnchor = Object
		end),
		IconButton {
			Icon = "save",
			Tooltip = function()
				return `Save to {Saver.LocationLabels[Settings.Get("SaveLocation")()]} as {if Settings.Get("SaveAsCurve")() then "curves" else "keyframes"}`
			end,
			LayoutOrder = 6,
			Disabled = Disabled,
			OnClick = function()
				const Loaded = Session.Rig() :: Rig.Rig
				const Where = Settings.Get("SaveLocation")()

				Saver.Save(Session.Current(), Loaded, Where, Settings.Get("SaveAsCurve")(), Session.FrameRate())
				Session.Dirty(false)
				Session.Say(`Saved {Session.Current().Name} to {Saver.LocationLabels[Where]}`)
			end,
		},
		Anchored("SaveAnchor", 7, IconButton {
			Icon = "chevron-down",
			Tooltip = "Where and how to save",
			Disabled = Disabled,
			OnClick = function()
				SaveMenu(SaveAnchor)
			end,
		}, function(Object: GuiObject)
			SaveAnchor = Object
		end),
		IconButton {
			Icon = "upload",
			Tooltip = "Publish to Roblox",
			LayoutOrder = 8,
			Disabled = Disabled,
			OnClick = function()
				Saver.Publish(Session.Current(), Session.Rig() :: Rig.Rig, Session.Plugin :: Plugin, Settings.Get("SaveLocation")(), Settings.Get("SaveAsCurve")(), Session.FrameRate())
			end,
		},
		Create "Frame" {
			Name = "Spacer",
			Size = UDim2.fromScale(1, 0),
			BackgroundTransparency = 1,
			LayoutOrder = 9,

			Create "UIFlexItem" {FlexMode = Enum.UIFlexMode.Fill},
		},
		Create "TextLabel" {
			Name = "Dirty",
			AutomaticSize = Enum.AutomaticSize.X,
			Size = UDim2.fromScale(0, 1),
			BackgroundTransparency = 1,
			TextColor3 = Theme.Colors.DimText,
			TextSize = Settings.SmallText,
			FontFace = Font.fromEnum(Enum.Font.BuilderSans),
			LayoutOrder = 10,
			Text = function()
				return if Session.Dirty() then "Unsaved changes" else ""
			end,
		},
		IconButton {
			Icon = "image",
			Tooltip = "Reference images and video",
			LayoutOrder = 11,
			Active = function()
				return Session.Panel() == "Reference"
			end,
			OnClick = function()
				Session.Panel(if Session.Panel() == "Reference" then nil else "Reference")
			end,
		},
		IconButton {
			Icon = "smile",
			Tooltip = "Emote checks and thumbnail",
			LayoutOrder = 12,
			Disabled = Disabled,
			Active = function()
				return Session.Panel() == "Emote"
			end,
			OnClick = function()
				Session.Panel(if Session.Panel() == "Emote" then nil else "Emote")
			end,
		},
		IconButton {
			Icon = "undo-2",
			Tooltip = "Undo",
			LayoutOrder = 13,
			Disabled = function()
				return Session.UndoCount() == 0
			end,
			OnClick = Session.Undo,
		},
		IconButton {
			Icon = "redo-2",
			Tooltip = "Redo",
			LayoutOrder = 14,
			Disabled = function()
				return Session.RedoCount() == 0
			end,
			OnClick = Session.Redo,
		},
		IconButton {
			Icon = "x",
			Tooltip = "Release every rig",
			LayoutOrder = 15,
			Visible = function()
				return Session.Rig() ~= nil
			end,
			OnClick = function()
				Session.Confirm("Release", Session.ReleaseAll)
			end,
		},
	}
end