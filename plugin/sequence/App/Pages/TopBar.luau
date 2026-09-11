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

const function PickRig(): string?
	for _, Picked in Selection:Get() do
		const Model = if Picked:IsA("Model") then Picked else Picked:FindFirstAncestorOfClass("Model")

		if Model and Session.LoadRig(Model) then
			return nil
		end
	end

	return "Select a model with Motor6D joints first"
end

const function LoadInto(Sequence: KeyframeSequence)
	const Loaded = Session.Rig()

	if not Loaded then
		return
	end

	const Read, Problem = Saver.FromSequence(Sequence, Loaded)

	if not Read then
		Session.Say(Problem or "Could not read that animation")

		return
	end

	Session.Replace(Read)
	Session.Say(if Problem then Problem else `Opened {Read.Name}`)
end

const function OpenMenu(Anchor: GuiObject)
	const Loaded = Session.Rig()

	if not Loaded then
		return
	end

	const Entries: {Overlay.Entry} = {}

	for _, Sequence in Saver.List(Loaded) do
		table.insert(Entries, {
			Label = Sequence.Name,
			Action = function()
				LoadInto(Sequence)
			end,
		})
	end

	if #Entries == 0 then
		table.insert(Entries, {
			Label = "No saved animations on this rig",
			Disabled = true,
		})
	end

	table.insert(Entries, {Label = "", Divider = true})
	table.insert(Entries, {
		Label = "From selected KeyframeSequence",
		Action = function()
			const Picked = Selection:Get()[1]

			if Picked and Picked:IsA("KeyframeSequence") then
				LoadInto(Picked)
			else
				Session.Say("Select a KeyframeSequence in the Explorer first")
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

	Overlay.Menu(Anchor, Entries, 220)
end

return function()
	local OpenAnchor: GuiObject

	const function RigName(): string
		const Loaded = Session.Rig()

		return if Loaded then Loaded.Model.Name else "Pick a rig"
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
				const Problem = PickRig()

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
				Name = "person-standing",
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
				Text = RigName,
				LayoutOrder = 2,
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
			OnChange = function(Text: string)
				if Session.ImportPrompt() then
					Session.ImportPrompt(false)

					const AssetId = tonumber(Text:match("%d+"))

					if not AssetId then
						Session.Say("That is not an asset id")

						return
					end

					const Sequence, Problem = Saver.Import(AssetId)

					if not Sequence then
						Session.Say(Problem or "Import failed")

						return
					end

					LoadInto(Sequence)

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
			Disabled = function()
				return Session.Rig() == nil
			end,
			OnClick = function()
				Session.Replace(Clip.New("Animation"))
			end,
		},
		Create "TextButton" {
			Name = "OpenAnchor",
			Size = function()
				return UDim2.fromOffset(Settings.TextSize() + 12, Settings.TextSize() + 8)
			end,
			BackgroundTransparency = 1,
			Text = "",
			LayoutOrder = 5,

			Vide.action(function(Object: TextButton)
				OpenAnchor = Object
			end),

			IconButton {
				Icon = "folder-open",
				Tooltip = "Open",
				Disabled = function()
					return Session.Rig() == nil
				end,
				OnClick = function()
					OpenMenu(OpenAnchor)
				end,
			},
		},
		IconButton {
			Icon = "save",
			Tooltip = "Save to the rig's AnimSaves",
			LayoutOrder = 6,
			Disabled = function()
				return Session.Rig() == nil
			end,
			OnClick = function()
				const Loaded = Session.Rig() :: Rig.Rig

				Saver.Save(Session.Current(), Loaded)
				Session.Dirty(false)
				Session.Say(`Saved {Session.Current().Name} under {Loaded.Model.Name}.AnimSaves`)
			end,
		},
		IconButton {
			Icon = "upload",
			Tooltip = "Publish to Roblox",
			LayoutOrder = 7,
			Disabled = function()
				return Session.Rig() == nil
			end,
			OnClick = function()
				Saver.Publish(Session.Current(), Session.Rig() :: Rig.Rig, Session.Plugin :: Plugin)
				Session.Dirty(false)
			end,
		},
		Create "Frame" {
			Name = "Spacer",
			Size = UDim2.fromScale(1, 0),
			BackgroundTransparency = 1,
			LayoutOrder = 8,

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
			LayoutOrder = 9,
			Text = function()
				return if Session.Dirty() then "Unsaved changes" else ""
			end,
		},
		IconButton {
			Icon = "undo-2",
			Tooltip = "Undo",
			LayoutOrder = 10,
			Disabled = function()
				return Session.UndoCount() == 0
			end,
			OnClick = Session.Undo,
		},
		IconButton {
			Icon = "redo-2",
			Tooltip = "Redo",
			LayoutOrder = 11,
			Disabled = function()
				return Session.RedoCount() == 0
			end,
			OnClick = Session.Redo,
		},
		IconButton {
			Icon = "x",
			Tooltip = "Release the rig",
			LayoutOrder = 12,
			Visible = function()
				return Session.Rig() ~= nil
			end,
			OnClick = function()
				Session.ReleaseRig()
			end,
		},
	}
end