--!strict
const UserInputService = game:GetService("UserInputService")
const Vide = require(script.Parent.Parent.Parent.Packages.vide)
const Settings = require(script.Parent.Parent.Parent.Settings)
const Format = require(script.Parent.Parent.Parent.Format)
const Theme = require(script.Parent.Parent.Theme)
const Overlay = require(script.Parent.Parent.Overlay)
const Session = require(script.Parent.Parent.Parent.Editor.Session)
const Sift = require(script.Parent.Parent.Parent.Packages.sift)
const Clip = require(script.Parent.Parent.Parent.Editor.Clip)
const Rig = require(script.Parent.Parent.Parent.Editor.Rig)
const Easing = require(script.Parent.Parent.Parent.Editor.Easing)
const Icon = require(script.Parent.Parent.Components.Icon)
const IconButton = require(script.Parent.Parent.Components.IconButton)
const CurveView = require(script.Parent.CurveView)

const Create = Vide.create

const NameWidth = 210
const LanePadding = 10

type Drag = {
	Kind: "Scrub" | "Keys" | "Marker" | "Box",
	StartX: number,
	StartY: number,
	StartTime: number,
	Applied: number,
	Marker: Clip.Marker?,
	Moved: boolean,
}

type RowEntry = {
	Kind: "Rig" | "Joint" | "Property",
	Entry: Session.Entry,
	Joint: Rig.Joint?,
	TrackName: string?,
	Label: string,
	Depth: number,
}

return function(HeaderPieces: () -> {NameRow: Instance})
	const Zoom = Vide.source(200)
	const Offset = Vide.source(0)
	const UserZoomed = Vide.source(false)
	const LaneWidth = Vide.source(400)
	const Box = Vide.source(nil :: {From: Vector2, To: Vector2}?)
	const RowFrames: {[Frame]: {Model: Model, Name: string}} = {}
	local Root: Frame
	local Drag: Drag?

	const function RowHeight(): number
		return Settings.TextSize() + 5
	end

	const function LaneLeft(): number
		return Root.AbsolutePosition.X + NameWidth
	end

	const function XOf(Time: number): number
		return LanePadding + (Time - Offset()) * Zoom()
	end

	const function TimeAt(AbsoluteX: number): number
		return Offset() + (AbsoluteX - LaneLeft() - LanePadding) / Zoom()
	end

	const function Fit(Length: number, Width: number)
		Offset(0)
		Zoom(math.clamp((Width - LanePadding * 2 - 8) / math.max(Length, 1 / 30), 20, 5000))
	end

	Vide.effect(function()
		const Length = Session.SceneLength()
		const Width = LaneWidth()

		if not UserZoomed() then
			Fit(Length, Width)
		end
	end)

	const Problems = Session.Problems

	const function Ticks(): {{Time: number, Label: string}}
		const Rate = Session.FrameRate()
		const Length = Session.SceneLength()
		local Step = 1 / Rate

		for _, Frames in {
			1,
			2,
			5,
			10,
			15,
			30,
			60,
			120,
			300,
			600,
		} do
			Step = Frames / Rate

			if Step * Zoom() >= 48 then
				break
			end
		end

		if Step * Zoom() < 48 then
			Step = math.ceil(48 / Zoom())
		end

		const Found = {}
		const First = math.max(0, math.floor(Offset() / Step) * Step)
		const Last = math.min(Length, Offset() + (LaneWidth() - LanePadding) / Zoom())

		for Index = 0, math.ceil((Last - First) / Step) do
			const Time = First + Index * Step

			if Time > Last + 0.0001 then
				break
			end

			table.insert(Found, {
				Time = Time,
				Label = Format.Timecode(Time, Rate),
			})
		end

		return Found
	end

	const function CollapseKey(Entry: Session.Entry, Name: string): string
		return `{Entry.Model:GetDebugId()}:{Name}`
	end

	const function Rows(): {RowEntry}
		const Collapsed = Session.Collapsed()
		const Active = Session.Rig()
		const Shown: {RowEntry} = {}

		for _, Entry in Session.Rigs() do
			table.insert(Shown, {
				Kind = "Rig",
				Entry = Entry,
				Label = Entry.Model.Name,
				Depth = 0,
			})

			if Collapsed[CollapseKey(Entry, "")] then
				continue
			end

			for _, Joint in Entry.Loaded.Joints do
				local Hidden = false
				local Ancestor = Joint.Parent

				while Ancestor do
					if Collapsed[CollapseKey(Entry, Ancestor.Name)] then
						Hidden = true
						break
					end

					Ancestor = Ancestor.Parent
				end

				if not Hidden then
					table.insert(Shown, {
						Kind = "Joint",
						Entry = Entry,
						Joint = Joint,
						TrackName = Joint.Name,
						Label = Joint.Name,
						Depth = Joint.Depth + 1,
					})
				end
			end

			const Current = if Active and Entry.Model == Active.Model then Session.Current() else Entry.Clip

			for Name, Track in Current.Tracks do
				if Clip.IsProperty(Name) and Track.Object then
					table.insert(Shown, {
						Kind = "Property",
						Entry = Entry,
						TrackName = Name,
						Label = `{Track.Object.Name}.{Track.Property}`,
						Depth = 1,
					})
				end
			end
		end

		return Shown
	end

	const function KeyMenu(Position: Vector2, TrackName: string, Time: number)
		const Key = Session.KeyAt(TrackName, Time)

		if not Key then
			return
		end

		const Count = #Session.SelectedKeys()
		const Beside = Position + Vector2.new(24, 0)

		const function StyleEntries(): {Overlay.Entry}
			const Made: {Overlay.Entry} = {}

			for Index, Style in Easing.Styles do
				if Index == 6 then
					table.insert(Made, {Label = "", Divider = true})
				end

				table.insert(Made, {
					Label = Style,
					Checked = Key.EasingStyle == Style,
					Action = function()
						Session.SetSelectedEasing(Style, nil)
					end,
				})
			end

			return Made
		end

		const function DirectionEntries(): {Overlay.Entry}
			const Made: {Overlay.Entry} = {}

			for _, Direction in Easing.Directions do
				table.insert(Made, {
					Label = Direction,
					Checked = Key.EasingDirection == Direction,
					Action = function()
						Session.SetSelectedEasing(nil, Direction)
					end,
				})
			end

			return Made
		end

		const Fixed = Key.EasingStyle == "Linear" or Key.EasingStyle == "Constant" or Key.EasingStyle == "Smooth"

		Overlay.MenuAt(Position, {
			{
				Label = `Easing style: {Key.EasingStyle}  ›`,
				Action = function()
					task.defer(Overlay.MenuAt, Beside, StyleEntries(), 150)
				end,
			},
			{
				Label = if Fixed then "Easing direction" else `Easing direction: {Key.EasingDirection}  ›`,
				Disabled = Fixed,
				Action = function()
					task.defer(Overlay.MenuAt, Beside, DirectionEntries(), 120)
				end,
			},
			{Label = "", Divider = true},
			{
				Label = "Cut",
				Action = function()
					Session.Copy()
					Session.DeleteSelectedKeys()
				end,
			},
			{Label = "Copy", Action = Session.Copy},
			{
				Label = "Paste at playhead",
				Disabled = #Session.Clipboard() == 0,
				Action = Session.Paste,
			},
			{Label = "Duplicate", Action = Session.Duplicate},
			{
				Label = if Count > 1 then `Delete {Count} keyframes` else "Delete keyframe",
				Action = Session.DeleteSelectedKeys,
			},
			{Label = "", Divider = true},
			{
				Label = "Reset to rest pose",
				Disabled = Clip.IsProperty(TrackName),
				Action = function()
					for _, Ref in Session.SelectedKeys() do
						if not Clip.IsProperty(Ref.Joint) then
							Session.Edit(Clip.SetKey(Session.Current(), Ref.Joint, Sift.Dictionary.merge(Session.KeyAt(Ref.Joint, Ref.Time) :: Clip.Key, {Value = CFrame.identity})))
						end
					end
				end,
			},
			{
				Label = "Move to playhead",
				Action = function()
					const Lowest = Session.SelectionSpan()

					Session.MoveSelectedKeys(Session.SnapTime(Session.Time()) - Lowest)
				end,
			},
			{
				Label = "Reverse",
				Disabled = Count < 2,
				Action = Session.ReverseSelected,
			},
			{
				Label = "Mirror pose here",
				Disabled = Clip.IsProperty(TrackName),
				Action = function()
					Session.Seek(Time)
					Session.MirrorPose(nil)
				end,
			},
			{Label = "", Divider = true},
			{
				Label = "Add event here",
				Action = function()
					Session.Edit(Clip.SetMarker(Session.Current(), {
						Time = Time,
						Name = "Event",
						Value = "",
					}))
					Session.SelectedMarker(Clip.FindMarker(Session.Current(), Time, "Event"))
				end,
			},
		}, 200)
	end

	const function LaneMenu(Position: Vector2, TrackName: string?)
		const Time = Session.SnapTime(TimeAt(Position.X))
		const Entries: {Overlay.Entry} = {
			{
				Label = if TrackName then `Add keyframe here` else "Add keyframe for every joint",
				Action = function()
					Session.Seek(Time)

					if TrackName and Clip.IsProperty(TrackName) then
						Session.KeyProperty(TrackName)
					elseif TrackName then
						Session.AddKeys({TrackName})
					else
						Session.KeyAll()
					end
				end,
			},
			{
				Label = "Paste here",
				Disabled = #Session.Clipboard() == 0,
				Action = function()
					Session.Seek(Time)
					Session.Paste()
				end,
			},
			{
				Label = "Add event here",
				Action = function()
					Session.Seek(Time)
					Session.Edit(Clip.SetMarker(Session.Current(), {
						Time = Time,
						Name = "Event",
						Value = "",
					}))
					Session.SelectedMarker(Clip.FindMarker(Session.Current(), Time, "Event"))
				end,
			},
		}

		if TrackName and Clip.IsProperty(TrackName) then
			table.insert(Entries, {Label = "", Divider = true})
			table.insert(Entries, {
				Label = "Remove this property track",
				Action = function()
					Session.Edit(Clip.RemoveTrack(Session.Current(), TrackName))
				end,
			})
		end

		Overlay.MenuAt(Position, Entries, 220)
	end

	const function Diamond(Props: {
		Time: () -> number,
		Selected: () -> boolean,
		Square: (() -> boolean)?,
		OnDown: (Shift: boolean, X: number) -> (),
		OnMenu: (Position: Vector2) -> (),
		Muted: (() -> boolean)?,
	})
		const Hovered = Vide.source(false)

		return Create "TextButton" {
			Name = "Key",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = function()
				return UDim2.new(0, XOf(Props.Time()), 0.5, 0)
			end,
			Size = UDim2.fromOffset(16, 16),
			BackgroundTransparency = 1,
			Text = "",
			AutoButtonColor = false,
			ZIndex = 5,
			Visible = function()
				const X = XOf(Props.Time())

				return X >= 0 and X <= LaneWidth()
			end,
			MouseEnter = function()
				Hovered(true)
			end,
			MouseLeave = function()
				Hovered(false)
			end,
			InputBegan = function(Input: InputObject)
				if Input.UserInputType == Enum.UserInputType.MouseButton1 then
					Props.OnDown(UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) or UserInputService:IsKeyDown(Enum.KeyCode.RightShift), Input.Position.X)
				elseif Input.UserInputType == Enum.UserInputType.MouseButton2 then
					Props.OnMenu(Vector2.new(Input.Position.X, Input.Position.Y))
				end
			end,

			Create "Frame" {
				Name = "Shape",
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, 0.5),
				Size = function()
					return if Hovered() then UDim2.fromOffset(10, 10) else UDim2.fromOffset(8, 8)
				end,
				Rotation = function()
					return if Props.Square and Props.Square() then 0 else 45
				end,
				BackgroundColor3 = function()
					if Props.Selected() then
						return Theme.Colors.Accent()
					end

					return if Props.Muted and Props.Muted() then Theme.Colors.DimText() else Theme.Colors.Text()
				end,
				ZIndex = 6,

				Create "UIStroke" {
					Color = Theme.Colors.Background,
					Thickness = 1,
				},
			},
		}
	end

	const function NameCell(Order: number, ...: Instance)
		return Create "Frame" {
			Name = "NameCell",
			Size = UDim2.new(0, NameWidth, 1, 0),
			BackgroundColor3 = Theme.Colors.Panel,
			LayoutOrder = Order,
			ZIndex = 3,

			Create "Frame" {
				Name = "Edge",
				Position = UDim2.new(1, -1, 0, 0),
				Size = UDim2.new(0, 1, 1, 0),
				BackgroundColor3 = Theme.Colors.DimText,
				BackgroundTransparency = 0.6,
				ZIndex = 4,
			},
			...,
		}
	end

	const function StartDrag(Kind: "Scrub" | "Keys" | "Marker" | "Box", X: number, Y: number, StartTime: number, Marker: Clip.Marker?)
		Drag = {
			Kind = Kind,
			StartX = X,
			StartY = Y,
			StartTime = StartTime,
			Applied = 0,
			Marker = Marker,
			Moved = false,
		}
	end

	const function TracksBetween(TopY: number, BottomY: number): {string}
		const Found = {}
		const Active = Session.Rig()

		for Frame, Row in RowFrames do
			if not Frame.Parent or not Active or Row.Model ~= Active.Model then
				continue
			end

			const Top = Frame.AbsolutePosition.Y
			const Bottom = Top + Frame.AbsoluteSize.Y

			if Bottom >= TopY and Top <= BottomY then
				table.insert(Found, Row.Name)
			end
		end

		return Found
	end

	const function EndDrag()
		const Active = Drag

		if not Active then
			return
		end

		if Active.Kind == "Box" then
			const Current = Box()

			if Current then
				const Low = Vector2.new(math.min(Current.From.X, Current.To.X), math.min(Current.From.Y, Current.To.Y))
				const High = Vector2.new(math.max(Current.From.X, Current.To.X), math.max(Current.From.Y, Current.To.Y))

				Session.SelectBox(TracksBetween(Low.Y, High.Y), TimeAt(Low.X), TimeAt(High.X), UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) or UserInputService:IsKeyDown(Enum.KeyCode.RightShift))
			elseif not Active.Moved then
				Session.SelectedKeys({})
				Session.Seek(Active.StartTime)
			end

			Box(nil)
		end

		Drag = nil
		Session.EndMerge()
	end

	const function LaneInput(TrackName: string?)
		return function(Input: InputObject)
			if Input.UserInputType == Enum.UserInputType.MouseButton1 then
				StartDrag("Box", Input.Position.X, Input.Position.Y, TimeAt(Input.Position.X))
			elseif Input.UserInputType == Enum.UserInputType.MouseButton2 then
				LaneMenu(Vector2.new(Input.Position.X, Input.Position.Y), TrackName)
			end
		end
	end

	const function Row(Entry: RowEntry, Order: () -> number)
		const Rig = Entry.Entry

		const function IsActive(): boolean
			const Active = Session.Rig()

			return Active ~= nil and Active.Model == Rig.Model
		end

		const function Current(): Clip.Clip
			return if IsActive() then Session.Current() else Rig.Clip
		end

		if Entry.Kind == "Rig" then
			return Create "Frame" {
				Name = "RigRow",
				Size = function()
					return UDim2.new(1, 0, 0, RowHeight())
				end,
				BackgroundColor3 = Theme.Colors.Panel,
				LayoutOrder = Order,

				Create "UIListLayout" {
					FillDirection = Enum.FillDirection.Horizontal,
					SortOrder = Enum.SortOrder.LayoutOrder,
				},
				NameCell(1,
					Create "TextButton" {
						Name = "Activate",
						Size = UDim2.new(1, -26, 1, 0),
						BackgroundTransparency = 1,
						Text = "",
						ZIndex = 4,
						Activated = function()
							Session.Activate(Rig.Model)
						end,

						Create "TextButton" {
							Name = "Fold",
							Position = UDim2.fromOffset(4, 0),
							Size = UDim2.new(0, 16, 1, 0),
							BackgroundTransparency = 1,
							Text = "",
							ZIndex = 5,
							Activated = function()
								const Collapsed = table.clone(Session.Collapsed())
								const Key = CollapseKey(Rig, "")

								Collapsed[Key] = not Collapsed[Key]
								Session.Collapsed(Collapsed)
							end,

							Icon {
								Name = function()
									return if Session.Collapsed()[CollapseKey(Rig, "")] then "chevron-right" else "chevron-down"
								end,
								Size = Settings.SmallText,
								Position = UDim2.fromScale(0.5, 0.5),
								AnchorPoint = Vector2.new(0.5, 0.5),
							},
						},
						Icon {
							Name = "person-standing",
							Position = UDim2.fromOffset(22, 0),
							AnchorPoint = Vector2.new(0, 0),
							Colour = function()
								return if IsActive() then Theme.Colors.Accent() else Theme.Colors.DimText()
							end,
						},
						Create "TextLabel" {
							Name = "Label",
							Position = UDim2.fromOffset(42, 0),
							Size = UDim2.new(1, -46, 1, 0),
							BackgroundTransparency = 1,
							TextXAlignment = Enum.TextXAlignment.Left,
							TextTruncate = Enum.TextTruncate.AtEnd,
							TextColor3 = function()
								return if IsActive() then Theme.Colors.Text() else Theme.Colors.DimText()
							end,
							TextSize = Settings.TextSize,
							FontFace = Font.fromEnum(Enum.Font.BuilderSansBold),
							Text = function()
								return `{Rig.Model.Name}  ·  {Current().Name}`
							end,
							ZIndex = 5,
						},
					},
					IconButton {
						Icon = "x",
						Size = Settings.SmallText,
						Position = UDim2.new(1, -4, 0.5, 0),
						AnchorPoint = Vector2.new(1, 0.5),
						Tooltip = "Release this rig",
						OnClick = function()
							Session.Activate(Rig.Model)
							Session.Confirm("Release", function()
								Session.RemoveRig(Rig.Model)
							end)
						end,
					}
				),
				Create "Frame" {
					Name = "Lane",
					Size = UDim2.new(1, -NameWidth, 1, 0),
					BackgroundTransparency = 1,
					LayoutOrder = 2,
					ClipsDescendants = true,
					InputBegan = LaneInput(nil),

					Vide.indexes(function()
						return Clip.KeyTimes(Current())
					end, function(Time)
						return Diamond {
							Time = Time,
							Muted = function()
								return not IsActive()
							end,
							Selected = function()
								if not IsActive() then
									return false
								end

								for _, Ref in Session.SelectedKeys() do
									if math.abs(Ref.Time - Time()) < 0.0005 then
										return true
									end
								end

								return false
							end,
							OnDown = function(Shift: boolean, X: number)
								Session.Activate(Rig.Model)
								Session.SelectColumn(Time(), Shift)
								Session.Seek(Time())
								StartDrag("Keys", X, 0, Time())
							end,
							OnMenu = function(Position: Vector2)
								Session.Activate(Rig.Model)
								Session.SelectColumn(Time(), false)

								const First = Session.SelectedKeys()[1]

								if First then
									KeyMenu(Position, First.Joint, First.Time)
								end
							end,
						}
					end),
				},
			}
		end

		const TrackName = Entry.TrackName :: string
		const Joint = Entry.Joint

		const function Selected(): boolean
			return IsActive() and Session.SelectedJoint() == TrackName
		end

		const function Keys(): {Clip.Key}
			const Track = Current().Tracks[TrackName]

			return if Track then Track.Keys else {}
		end

		const function HasKeyNow(): boolean
			return IsActive() and not Session.Playing() and Session.KeyAt(TrackName, Session.SnapTime(Session.Time())) ~= nil
		end

		const function Pinned(): boolean
			return IsActive() and Session.Pins()[TrackName] ~= nil
		end

		return Create "Frame" {
			Name = Entry.Label,
			Size = function()
				return UDim2.new(1, 0, 0, RowHeight())
			end,
			BackgroundColor3 = function()
				return if Selected() then Theme.Colors.Button() else Theme.Colors.Background()
			end,
			LayoutOrder = Order,

			Vide.action(function(Object: Frame)
				RowFrames[Object] = {Model = Rig.Model, Name = TrackName}

				Vide.cleanup(function()
					RowFrames[Object] = nil
				end)
			end),

			Create "UIListLayout" {
				FillDirection = Enum.FillDirection.Horizontal,
				SortOrder = Enum.SortOrder.LayoutOrder,
			},
			NameCell(1,
				Create "TextButton" {
					Name = "Select",
					Size = UDim2.new(1, -50, 1, 0),
					BackgroundColor3 = Theme.Colors.Button,
					BackgroundTransparency = function()
						return if Selected() then 0 else 1
					end,
					Text = "",
					AutoButtonColor = false,
					ZIndex = 4,
					Activated = function()
						Session.Activate(Rig.Model)

						if Joint then
							Session.SelectJoint(if Selected() then nil else TrackName)
						end
					end,

					Create "TextButton" {
						Name = "Fold",
						Position = function()
							return UDim2.fromOffset(4 + Entry.Depth * 12, 0)
						end,
						Size = UDim2.new(0, 16, 1, 0),
						BackgroundTransparency = 1,
						Text = "",
						ZIndex = 5,
						Visible = Joint ~= nil and #Joint.Children > 0,
						Activated = function()
							const Collapsed = table.clone(Session.Collapsed())
							const Key = CollapseKey(Rig, TrackName)

							Collapsed[Key] = not Collapsed[Key]
							Session.Collapsed(Collapsed)
						end,

						Icon {
							Name = function()
								return if Session.Collapsed()[CollapseKey(Rig, TrackName)] then "chevron-right" else "chevron-down"
							end,
							Size = Settings.SmallText,
							Position = UDim2.fromScale(0.5, 0.5),
							AnchorPoint = Vector2.new(0.5, 0.5),
						},
					},
					if Entry.Kind == "Property" then Icon {
						Name = "sliders-horizontal",
						Size = Settings.SmallText,
						Position = function()
							return UDim2.new(0, 6 + Entry.Depth * 12, 0.5, 0)
						end,
						AnchorPoint = Vector2.new(0, 0.5),
					} else nil,
					Create "TextLabel" {
						Name = "Label",
						Position = function()
							return UDim2.fromOffset(22 + Entry.Depth * 12, 0)
						end,
						Size = function()
							return UDim2.new(1, -(24 + Entry.Depth * 12), 1, 0)
						end,
						BackgroundTransparency = 1,
						TextXAlignment = Enum.TextXAlignment.Left,
						TextTruncate = Enum.TextTruncate.AtEnd,
						TextColor3 = function()
							return if Selected() or #Keys() > 0 then Theme.Colors.Text() else Theme.Colors.DimText()
						end,
						TextSize = Settings.TextSize,
						FontFace = Font.fromEnum(if Entry.Depth <= 1 then Enum.Font.BuilderSansMedium else Enum.Font.BuilderSans),
						Text = Entry.Label,
						ZIndex = 5,
					},
				},
				if Joint then IconButton {
					Icon = "pin",
					Size = Settings.SmallText,
					Position = UDim2.new(1, -28, 0.5, 0),
					AnchorPoint = Vector2.new(1, 0.5),
					Active = Pinned,
					Tooltip = function()
						return if Pinned() then "Unpin, let this part follow its parent again" else "Pin this part in place, parents move around it"
					end,
					OnClick = function()
						Session.Activate(Rig.Model)
						Session.TogglePin(TrackName)
					end,
				} else nil,
				IconButton {
					Icon = "diamond",
					Size = Settings.SmallText,
					Position = UDim2.new(1, -4, 0.5, 0),
					AnchorPoint = Vector2.new(1, 0.5),
					Active = HasKeyNow,
					Tooltip = function()
						return if HasKeyNow() then "Remove this keyframe" else "Keyframe this here"
					end,
					OnClick = function()
						Session.Activate(Rig.Model)

						const Time = Session.SnapTime(Session.Time())

						if HasKeyNow() then
							Session.Edit(Clip.RemoveKey(Session.Current(), TrackName, Time))
						elseif Entry.Kind == "Property" then
							Session.KeyProperty(TrackName)
						else
							Session.AddKeys({TrackName})
						end
					end,
				}
			),
			Create "Frame" {
				Name = "Lane",
				Size = UDim2.new(1, -NameWidth, 1, 0),
				BackgroundTransparency = 1,
				LayoutOrder = 2,
				ClipsDescendants = true,
				InputBegan = LaneInput(TrackName),

				Create "Frame" {
					Name = "Underline",
					Position = UDim2.new(0, 0, 1, -1),
					Size = UDim2.new(1, 0, 0, 1),
					BackgroundColor3 = Theme.Colors.Border,
					BackgroundTransparency = 0.6,
				},
				Vide.values(Keys, function(Key: Clip.Key)
					return Diamond {
						Time = function()
							return Key.Time
						end,
						Muted = function()
							return not IsActive()
						end,
						Selected = function()
							return IsActive() and Session.IsSelected(TrackName, Key.Time)
						end,
						Square = function()
							return Key.EasingStyle == "Constant"
						end,
						OnDown = function(Shift: boolean, X: number)
							Session.Activate(Rig.Model)
							Session.SelectKey(TrackName, Key.Time, Shift)
							Session.Seek(Key.Time)
							StartDrag("Keys", X, 0, Key.Time)
						end,
						OnMenu = function(Position: Vector2)
							Session.Activate(Rig.Model)

							if not Session.IsSelected(TrackName, Key.Time) then
								Session.SelectKey(TrackName, Key.Time, false)
							end

							KeyMenu(Position, TrackName, Key.Time)
						end,
					}
				end),
			},
		}
	end

	const function Playhead()
		return Create "Frame" {
			Name = "Playhead",
			Position = function()
				return UDim2.fromOffset(NameWidth + XOf(Session.Time()), 0)
			end,
			Size = UDim2.new(0, 1, 1, 0),
			BackgroundColor3 = Theme.Colors.Error,
			ZIndex = 20,
			Visible = function()
				const X = XOf(Session.Time())

				return Session.Rig() ~= nil and X >= 0 and X <= LaneWidth()
			end,

			Create "Frame" {
				Name = "Handle",
				AnchorPoint = Vector2.new(0.5, 0),
				Position = UDim2.fromOffset(0, 0),
				Size = UDim2.fromOffset(9, 9),
				Rotation = 45,
				BackgroundColor3 = Theme.Colors.Error,
				ZIndex = 21,
			},
		}
	end

	const function Header()
		return Create "Frame" {
			Name = "Header",
			Size = UDim2.new(1, 0, 0, 24),
			BackgroundColor3 = Theme.Colors.Panel,
			LayoutOrder = 1,

			Create "UIListLayout" {
				FillDirection = Enum.FillDirection.Horizontal,
				SortOrder = Enum.SortOrder.LayoutOrder,
			},
			NameCell(1, HeaderPieces().NameRow),
			Create "Frame" {
				Name = "Ruler",
				Size = UDim2.new(1, -NameWidth, 1, 0),
				BackgroundTransparency = 1,
				LayoutOrder = 2,
				ClipsDescendants = true,

				Create "Frame" {
					Name = "Bottom",
					Position = UDim2.new(0, 0, 1, -1),
					Size = UDim2.new(1, 0, 0, 1),
					BackgroundColor3 = Theme.Colors.DimText,
					BackgroundTransparency = 0.6,
					ZIndex = 6,
				},
				InputBegan = function(Input: InputObject)
					if Input.UserInputType ~= Enum.UserInputType.MouseButton1 then
						return
					end

					Session.Stop()
					Session.Seek(TimeAt(Input.Position.X))
					StartDrag("Scrub", Input.Position.X, Input.Position.Y, Session.Time())
				end,

				Vide.action(function(Object: Frame)
					const function Measure()
						LaneWidth(Object.AbsoluteSize.X)
					end

					Measure()
					Vide.cleanup(Object:GetPropertyChangedSignal("AbsoluteSize"):Connect(Measure))
				end),

				Vide.indexes(Ticks, function(Tick)
					return Create "Frame" {
						Name = "Tick",
						Position = function()
							return UDim2.new(0, XOf(Tick().Time), 1, -8)
						end,
						Size = UDim2.fromOffset(1, 8),
						BackgroundColor3 = Theme.Colors.DimText,

						Create "TextLabel" {
							Position = UDim2.fromOffset(3, -12),
							AutomaticSize = Enum.AutomaticSize.XY,
							BackgroundTransparency = 1,
							TextColor3 = Theme.Colors.DimText,
							TextSize = Settings.SmallText,
							FontFace = Font.fromEnum(Enum.Font.BuilderSans),
							Text = function()
								return Tick().Label
							end,
						},
					}
				end),
				Vide.indexes(Problems, function(Problem)
					return Create "Frame" {
						Name = "Problem",
						AnchorPoint = Vector2.new(0.5, 0),
						Position = function()
							return UDim2.fromOffset(XOf(Problem().Time or 0), 0)
						end,
						Size = UDim2.new(0, 3, 1, 0),
						BackgroundColor3 = Theme.Colors.Error,
						Visible = function()
							return Problem().Time ~= nil
						end,
						ZIndex = 3,
					}
				end),
				Create "Frame" {
					Name = "End",
					Position = function()
						return UDim2.fromOffset(XOf(Session.SceneLength()), 0)
					end,
					Size = UDim2.new(0, 1, 1, 0),
					BackgroundColor3 = Theme.Colors.Accent,
				},
			},
		}
	end

	const function Events()
		return Create "Frame" {
			Name = "Events",
			Size = UDim2.new(1, 0, 0, 16),
			BackgroundColor3 = Theme.Colors.Background,
			LayoutOrder = 2,
			Visible = function()
				return #Session.Current().Markers > 0 or Session.SelectedMarker() ~= nil
			end,

			Create "UIListLayout" {
				FillDirection = Enum.FillDirection.Horizontal,
				SortOrder = Enum.SortOrder.LayoutOrder,
			},
			NameCell(1,
				Create "TextLabel" {
					Position = UDim2.fromOffset(8, 0),
					Size = UDim2.new(1, -40, 1, 0),
					BackgroundTransparency = 1,
					TextXAlignment = Enum.TextXAlignment.Left,
					TextColor3 = Theme.Colors.DimText,
					TextSize = Settings.SmallText,
					FontFace = Font.fromEnum(Enum.Font.BuilderSansMedium),
					ZIndex = 4,
					Text = function()
						const Count = #Session.Current().Markers

						return if Count == 0 then "Events" else `{Count} event{if Count == 1 then "" else "s"}`
					end,
				},
				IconButton {
					Icon = "plus",
					Size = Settings.SmallText,
					Position = UDim2.new(1, -4, 0.5, 0),
					AnchorPoint = Vector2.new(1, 0.5),
					Tooltip = "Add an event at the playhead",
					Disabled = function()
						return Session.Rig() == nil
					end,
					OnClick = function()
						const Time = Session.SnapTime(Session.Time())

						Session.Edit(Clip.SetMarker(Session.Current(), {
							Time = Time,
							Name = "Event",
							Value = "",
						}))
						Session.SelectedMarker(Clip.FindMarker(Session.Current(), Time, "Event"))
					end,
				}
			),
			Create "Frame" {
				Name = "Lane",
				Size = UDim2.new(1, -NameWidth, 1, 0),
				BackgroundTransparency = 1,
				LayoutOrder = 2,
				ClipsDescendants = true,
				InputBegan = function(Input: InputObject)
					if Input.UserInputType == Enum.UserInputType.MouseButton1 then
						Session.SelectedMarker(nil)
						Session.Seek(TimeAt(Input.Position.X))
						StartDrag("Scrub", Input.Position.X, Input.Position.Y, Session.Time())
					elseif Input.UserInputType == Enum.UserInputType.MouseButton2 then
						LaneMenu(Vector2.new(Input.Position.X, Input.Position.Y), nil)
					end
				end,

				Vide.values(function()
					return Session.Current().Markers
				end, function(Marker: Clip.Marker)
					return Create "TextButton" {
						Name = "Marker",
						AnchorPoint = Vector2.new(0, 0.5),
						Position = function()
							return UDim2.new(0, XOf(Marker.Time) - 2, 0.5, 0)
						end,
						AutomaticSize = Enum.AutomaticSize.X,
						Size = UDim2.fromOffset(0, 18),
						BackgroundTransparency = 1,
						Text = "",
						ZIndex = 5,
						InputBegan = function(Input: InputObject)
							if Input.UserInputType == Enum.UserInputType.MouseButton1 then
								Session.SelectedMarker(Marker)
								Session.Seek(Marker.Time)
								StartDrag("Marker", Input.Position.X, Input.Position.Y, Marker.Time, Marker)
							elseif Input.UserInputType == Enum.UserInputType.MouseButton2 then
								Session.SelectedMarker(Marker)
								Overlay.MenuAt(Vector2.new(Input.Position.X, Input.Position.Y), {{
									Label = "Delete event",
									Action = function()
										Session.Edit(Clip.RemoveMarker(Session.Current(), Marker))
										Session.SelectedMarker(nil)
									end,
								}})
							end
						end,

						Create "UIListLayout" {
							FillDirection = Enum.FillDirection.Horizontal,
							VerticalAlignment = Enum.VerticalAlignment.Center,
							Padding = UDim.new(0, 2),
						},
						Icon {
							Name = "flag",
							Size = Settings.SmallText,
							Colour = function()
								return if Session.SelectedMarker() == Marker then Theme.Colors.Accent() else Theme.Colors.Text()
							end,
							LayoutOrder = 1,
						},
						Create "TextLabel" {
							AutomaticSize = Enum.AutomaticSize.X,
							Size = UDim2.fromScale(0, 1),
							BackgroundTransparency = 1,
							TextColor3 = function()
								return if Session.SelectedMarker() == Marker then Theme.Colors.Accent() else Theme.Colors.DimText()
							end,
							TextSize = Settings.SmallText,
							FontFace = Font.fromEnum(Enum.Font.BuilderSans),
							Text = Marker.Name,
							LayoutOrder = 2,
						},
					}
				end),
			},
		}
	end

	const function OnMove(X: number, Y: number)
		const Active = Drag

		if not Active then
			return
		end

		if Active.Kind == "Scrub" then
			Session.Seek(TimeAt(X))

			return
		end

		if Active.Kind == "Box" then
			if math.abs(X - Active.StartX) > 4 or math.abs(Y - Active.StartY) > 4 then
				Active.Moved = true
				Box({
					From = Vector2.new(Active.StartX, Active.StartY),
					To = Vector2.new(X, Y),
				})
			end

			return
		end

		const Wanted = Session.ToFrame(Active.StartTime + (X - Active.StartX) / Zoom()) - Active.StartTime
		const Delta = Wanted - Active.Applied

		if math.abs(Delta) < 0.0005 then
			return
		end

		if Active.Kind == "Keys" then
			Active.Applied += Session.MoveSelectedKeys(Delta, "DragKeys")

			return
		end

		const Marker = Active.Marker

		if not Marker then
			return
		end

		const Moved = {
			Time = math.clamp(Active.StartTime + Wanted, 0, Session.Current().Length),
			Name = Marker.Name,
			Value = Marker.Value,
		}

		Session.Edit(Clip.SetMarker(Clip.RemoveMarker(Session.Current(), Marker), Moved), "DragMarker")

		const Placed = Clip.FindMarker(Session.Current(), Moved.Time, Moved.Name)

		Session.SelectedMarker(Placed)
		Active.Marker = Placed
		Active.Applied = Wanted
	end

	const function Modified(): boolean
		return UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) or UserInputService:IsKeyDown(Enum.KeyCode.RightShift) or UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) or UserInputService:IsKeyDown(Enum.KeyCode.RightControl)
	end

	const function OnWheel(Input: InputObject)
		if Input.Position.X < LaneLeft() then
			return
		end

		if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) or UserInputService:IsKeyDown(Enum.KeyCode.RightControl) then
			const Under = TimeAt(Input.Position.X)
			const Scaled = math.clamp(Zoom() * (if Input.Position.Z > 0 then 1.25 else 0.8), 10, 5000)

			UserZoomed(true)
			Zoom(Scaled)
			Offset(math.max(0, Under - (Input.Position.X - LaneLeft() - LanePadding) / Scaled))
		elseif Modified() then
			UserZoomed(true)
			Offset(math.clamp(Offset() - Input.Position.Z * 40 / Zoom(), 0, math.max(0, Session.SceneLength() - (LaneWidth() - LanePadding * 2) / Zoom())))
		end
	end

	const ModifierHeld = Vide.source(false)

	Root = Create "Frame" {
		Name = "Timeline",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Theme.Colors.Background,
		ClipsDescendants = true,
		InputChanged = function(Input: InputObject)
			if Input.UserInputType == Enum.UserInputType.MouseMovement then
				OnMove(Input.Position.X, Input.Position.Y)
			elseif Input.UserInputType == Enum.UserInputType.MouseWheel then
				OnWheel(Input)
			end
		end,
		InputEnded = function(Input: InputObject)
			if Input.UserInputType == Enum.UserInputType.MouseButton1 then
				EndDrag()
			end
		end,

		Vide.action(function()
			Vide.cleanup(UserInputService.InputBegan:Connect(function(Input: InputObject)
				if Input.UserInputType == Enum.UserInputType.Keyboard then
					ModifierHeld(Modified())
				end
			end))
			Vide.cleanup(UserInputService.InputEnded:Connect(function(Input: InputObject)
				if Input.UserInputType == Enum.UserInputType.Keyboard then
					ModifierHeld(Modified())
				end

				if Input.UserInputType == Enum.UserInputType.MouseButton1 then
					EndDrag()
				end
			end))
		end),

		Create "Frame" {
			Name = "Stack",
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,

			Create "UIListLayout" {SortOrder = Enum.SortOrder.LayoutOrder},
			Header(),
			Events(),
			Create "ScrollingFrame" {
				Name = "Rows",
				Size = UDim2.fromScale(1, 1),
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				LayoutOrder = 3,
				AutomaticCanvasSize = Enum.AutomaticSize.Y,
				CanvasSize = UDim2.new(),
				ScrollBarThickness = 6,
				ScrollBarImageColor3 = Theme.Colors.DimText,
				ScrollingDirection = Enum.ScrollingDirection.Y,
				ScrollingEnabled = function()
					return not ModifierHeld()
				end,
				Visible = function()
					return Session.View() == "Sheet"
				end,
				InputChanged = function(Input: InputObject)
					if Input.UserInputType == Enum.UserInputType.MouseWheel then
						OnWheel(Input)
					end
				end,

				Create "UIFlexItem" {FlexMode = Enum.UIFlexMode.Fill},
				Create "UIListLayout" {SortOrder = Enum.SortOrder.LayoutOrder},

				Vide.values(Rows, function(Entry: RowEntry, Index)
					return Row(Entry, Index)
				end),
			},
			Vide.show(function()
				return Session.View() == "Curves"
			end, function()
				return CurveView {
					XOf = XOf,
					TimeAt = TimeAt,
					NameWidth = NameWidth,
					LaneWidth = LaneWidth,
					Visible = function()
						return true
					end,
				}
			end),
		},
		Create "Frame" {
			Name = "Box",
			BackgroundColor3 = Theme.Colors.Accent,
			BackgroundTransparency = 0.8,
			ZIndex = 30,
			Visible = function()
				return Box() ~= nil
			end,
			Position = function()
				const Current = Box()

				if not Current then
					return UDim2.new()
				end

				return UDim2.fromOffset(math.min(Current.From.X, Current.To.X) - Root.AbsolutePosition.X, math.min(Current.From.Y, Current.To.Y) - Root.AbsolutePosition.Y)
			end,
			Size = function()
				const Current = Box()

				if not Current then
					return UDim2.new()
				end

				return UDim2.fromOffset(math.abs(Current.To.X - Current.From.X), math.abs(Current.To.Y - Current.From.Y))
			end,

			Create "UIStroke" {Color = Theme.Colors.Accent},
		},
		Playhead(),
	}

	return Root
end