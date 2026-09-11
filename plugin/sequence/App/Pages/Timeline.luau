--!strict
const UserInputService = game:GetService("UserInputService")
const Vide = require(script.Parent.Parent.Parent.Packages.vide)
const Settings = require(script.Parent.Parent.Parent.Settings)
const Format = require(script.Parent.Parent.Parent.Format)
const Theme = require(script.Parent.Parent.Theme)
const Overlay = require(script.Parent.Parent.Overlay)
const Session = require(script.Parent.Parent.Parent.Editor.Session)
const Clip = require(script.Parent.Parent.Parent.Editor.Clip)
const Rig = require(script.Parent.Parent.Parent.Editor.Rig)
const Easing = require(script.Parent.Parent.Parent.Editor.Easing)
const Icon = require(script.Parent.Parent.Components.Icon)
const IconButton = require(script.Parent.Parent.Components.IconButton)

const Create = Vide.create

const NameWidth = 190
const LanePadding = 10

type Drag = {
	Kind: "Scrub" | "Keys" | "Marker",
	StartX: number,
	Applied: number,
	Marker: Clip.Marker?,
}

return function()
	const Zoom = Vide.source(200)
	const Offset = Vide.source(0)
	const UserZoomed = Vide.source(false)
	const LaneWidth = Vide.source(400)
	local Root: Frame
	local Drag: Drag?

	const function RowHeight(): number
		return Settings.TextSize() + 9
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
		Zoom(math.max(20, (Width - LanePadding * 2 - 8) / Length))
	end

	Vide.effect(function()
		const Length = Session.Current().Length
		const Width = LaneWidth()

		if not UserZoomed() then
			Fit(Length, Width)
		end
	end)

	const function Ticks(): {{Time: number, Label: string}}
		const Rate = Session.FrameRate()
		const Length = Session.Current().Length
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

	const function VisibleJoints(): {Rig.Joint}
		const Loaded = Session.Rig()
		const Collapsed = Session.Collapsed()
		const Shown = {}

		if not Loaded then
			return Shown
		end

		for _, Joint in Loaded.Joints do
			local Hidden = false
			local Ancestor = Joint.Parent

			while Ancestor do
				if Collapsed[Ancestor.Name] then
					Hidden = true
					break
				end

				Ancestor = Ancestor.Parent
			end

			if not Hidden then
				table.insert(Shown, Joint)
			end
		end

		return Shown
	end

	const function KeyMenu(Position: Vector2, JointName: string, Time: number)
		const Key = Session.KeyAt(JointName, Time)

		if not Key then
			return
		end

		const Entries: {Overlay.Entry} = {}

		for _, Style in Easing.Styles do
			table.insert(Entries, {
				Label = Style,
				Checked = Key.EasingStyle == Style,
				Action = function()
					Session.SetSelectedEasing(Style, nil)
				end,
			})
		end

		table.insert(Entries, {Label = "", Divider = true})

		for _, Direction in Easing.Directions do
			table.insert(Entries, {
				Label = `Ease {Direction}`,
				Checked = Key.EasingDirection == Direction,
				Disabled = Key.EasingStyle == "Linear" or Key.EasingStyle == "Constant",
				Action = function()
					Session.SetSelectedEasing(nil, Direction)
				end,
			})
		end

		table.insert(Entries, {Label = "", Divider = true})
		table.insert(Entries, {
			Label = "Copy",
			Action = Session.Copy,
		})
		table.insert(Entries, {
			Label = "Reverse selected",
			Disabled = #Session.SelectedKeys() < 2,
			Action = Session.ReverseSelected,
		})
		table.insert(Entries, {
			Label = "Delete",
			Action = Session.DeleteSelectedKeys,
		})

		Overlay.MenuAt(Position, Entries, 170)
	end

	const function LaneMenu(Position: Vector2, JointName: string?)
		const Time = Session.SnapTime(TimeAt(Position.X))

		Overlay.MenuAt(Position, {
			{
				Label = if JointName then `Add keyframe for {JointName}` else "Add keyframe for every joint",
				Action = function()
					Session.Seek(Time)

					if JointName then
						Session.AddKeys({JointName})
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
					Session.SelectedMarker(Time)
				end,
			},
		}, 220)
	end

	const function Diamond(Props: {
		Time: () -> number,
		Selected: () -> boolean,
		Square: (() -> boolean)?,
		OnDown: (Shift: boolean) -> (),
		OnMenu: (Position: Vector2) -> (),
		Muted: boolean?,
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
					Props.OnDown(UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) or UserInputService:IsKeyDown(Enum.KeyCode.RightShift))
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

					return if Props.Muted then Theme.Colors.DimText() else Theme.Colors.Text()
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
				BackgroundColor3 = Theme.Colors.Border,
				ZIndex = 4,
			},
			...,
		}
	end

	const function StartDrag(Kind: "Scrub" | "Keys" | "Marker", X: number, Marker: Clip.Marker?)
		Drag = {
			Kind = Kind,
			StartX = X,
			Applied = 0,
			Marker = Marker,
		}
	end

	const function Row(Joint: Rig.Joint, Order: () -> number)
		const function Selected(): boolean
			return Session.SelectedJoint() == Joint.Name
		end

		const function Keys(): {Clip.Key}
			const Track = Session.Current().Tracks[Joint.Name]

			return if Track then Track.Keys else {}
		end

		const function HasKeyNow(): boolean
			return Session.KeyAt(Joint.Name, Session.SnapTime(Session.Time())) ~= nil
		end

		return Create "Frame" {
			Name = Joint.Name,
			Size = function()
				return UDim2.new(1, 0, 0, RowHeight())
			end,
			BackgroundColor3 = function()
				return if Selected() then Theme.Colors.Button() else Theme.Colors.Background()
			end,
			LayoutOrder = Order,

			Create "UIListLayout" {
				FillDirection = Enum.FillDirection.Horizontal,
				SortOrder = Enum.SortOrder.LayoutOrder,
			},
			NameCell(1,
				Create "TextButton" {
					Name = "Select",
					Size = UDim2.new(1, -26, 1, 0),
					BackgroundColor3 = Theme.Colors.Button,
					BackgroundTransparency = function()
						return if Selected() then 0 else 1
					end,
					Text = "",
					AutoButtonColor = false,
					ZIndex = 4,
					Activated = function()
						Session.SelectJoint(if Selected() then nil else Joint.Name)
					end,

					Create "TextButton" {
						Name = "Fold",
						Position = function()
							return UDim2.fromOffset(4 + Joint.Depth * 12, 0)
						end,
						Size = UDim2.new(0, 16, 1, 0),
						BackgroundTransparency = 1,
						Text = "",
						ZIndex = 5,
						Visible = #Joint.Children > 0,
						Activated = function()
							const Collapsed = table.clone(Session.Collapsed())

							Collapsed[Joint.Name] = not Collapsed[Joint.Name]
							Session.Collapsed(Collapsed)
						end,

						Icon {
							Name = function()
								return if Session.Collapsed()[Joint.Name] then "chevron-right" else "chevron-down"
							end,
							Size = Settings.SmallText,
							Position = UDim2.fromScale(0.5, 0.5),
							AnchorPoint = Vector2.new(0.5, 0.5),
						},
					},
					Create "TextLabel" {
						Name = "Label",
						Position = function()
							return UDim2.fromOffset(22 + Joint.Depth * 12, 0)
						end,
						Size = function()
							return UDim2.new(1, -(24 + Joint.Depth * 12), 1, 0)
						end,
						BackgroundTransparency = 1,
						TextXAlignment = Enum.TextXAlignment.Left,
						TextTruncate = Enum.TextTruncate.AtEnd,
						TextColor3 = function()
							return if Selected() then Theme.Colors.Text() elseif #Keys() > 0 then Theme.Colors.Text() else Theme.Colors.DimText()
						end,
						TextSize = Settings.TextSize,
						FontFace = Font.fromEnum(if Joint.Depth == 0 then Enum.Font.BuilderSansMedium else Enum.Font.BuilderSans),
						Text = Joint.Name,
						ZIndex = 5,
					},
				},
				IconButton {
					Icon = "diamond",
					Size = Settings.SmallText,
					Position = UDim2.new(1, -4, 0.5, 0),
					AnchorPoint = Vector2.new(1, 0.5),
					Active = HasKeyNow,
					Tooltip = function()
						return if HasKeyNow() then "Remove this keyframe" else "Keyframe this joint here"
					end,
					OnClick = function()
						const Time = Session.SnapTime(Session.Time())

						if HasKeyNow() then
							Session.Edit(Clip.RemoveKey(Session.Current(), Joint.Name, Time))
						else
							Session.AddKeys({Joint.Name})
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
				InputBegan = function(Input: InputObject)
					if Input.UserInputType == Enum.UserInputType.MouseButton1 then
						Session.SelectedKeys({})
						Session.Seek(TimeAt(Input.Position.X))
						StartDrag("Scrub", Input.Position.X)
					elseif Input.UserInputType == Enum.UserInputType.MouseButton2 then
						LaneMenu(Vector2.new(Input.Position.X, Input.Position.Y), Joint.Name)
					end
				end,

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
						Selected = function()
							return Session.IsSelected(Joint.Name, Key.Time)
						end,
						Square = function()
							return Key.EasingStyle == "Constant"
						end,
						OnDown = function(Shift: boolean)
							Session.SelectKey(Joint.Name, Key.Time, Shift)
							Session.Seek(Key.Time)
							StartDrag("Keys", XOf(Key.Time) + LaneLeft())
						end,
						OnMenu = function(Position: Vector2)
							if not Session.IsSelected(Joint.Name, Key.Time) then
								Session.SelectKey(Joint.Name, Key.Time, false)
							end

							KeyMenu(Position, Joint.Name, Key.Time)
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
						const Loaded = Session.Rig()

						return if Loaded then `{#Loaded.Joints} joints` else "Joints"
					end,
				},
				IconButton {
					Icon = "scan",
					Size = Settings.SmallText,
					Position = UDim2.new(1, -4, 0.5, 0),
					AnchorPoint = Vector2.new(1, 0.5),
					Tooltip = "Fit the whole animation",
					OnClick = function()
						UserZoomed(false)
						Fit(Session.Current().Length, LaneWidth())
					end,
				}
			),
			Create "Frame" {
				Name = "Ruler",
				Size = UDim2.new(1, -NameWidth, 1, 0),
				BackgroundTransparency = 1,
				LayoutOrder = 2,
				ClipsDescendants = true,
				InputBegan = function(Input: InputObject)
					if Input.UserInputType ~= Enum.UserInputType.MouseButton1 then
						return
					end

					Session.Stop()
					Session.Seek(TimeAt(Input.Position.X))
					StartDrag("Scrub", Input.Position.X)
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
							Position = UDim2.fromOffset(3, -13),
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
				Create "Frame" {
					Name = "End",
					Position = function()
						return UDim2.fromOffset(XOf(Session.Current().Length), 0)
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
			Size = UDim2.new(1, 0, 0, 20),
			BackgroundColor3 = Theme.Colors.Background,
			LayoutOrder = 2,

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
						Session.SelectedMarker(Time)
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
						StartDrag("Scrub", Input.Position.X)
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
								Session.SelectedMarker(Marker.Time)
								Session.Seek(Marker.Time)
								StartDrag("Marker", XOf(Marker.Time) + LaneLeft(), Marker)
							elseif Input.UserInputType == Enum.UserInputType.MouseButton2 then
								Session.SelectedMarker(Marker.Time)
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
								return if Session.SelectedMarker() == Marker.Time then Theme.Colors.Accent() else Theme.Colors.Text()
							end,
							LayoutOrder = 1,
						},
						Create "TextLabel" {
							AutomaticSize = Enum.AutomaticSize.X,
							Size = UDim2.fromScale(0, 1),
							BackgroundTransparency = 1,
							TextColor3 = function()
								return if Session.SelectedMarker() == Marker.Time then Theme.Colors.Accent() else Theme.Colors.DimText()
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

	const function Summary()
		return Create "Frame" {
			Name = "Summary",
			Size = function()
				return UDim2.new(1, 0, 0, RowHeight())
			end,
			BackgroundColor3 = Theme.Colors.Panel,
			LayoutOrder = 3,

			Create "UIListLayout" {
				FillDirection = Enum.FillDirection.Horizontal,
				SortOrder = Enum.SortOrder.LayoutOrder,
			},
			NameCell(1,
				Create "TextLabel" {
					Position = UDim2.fromOffset(8, 0),
					Size = UDim2.new(1, -12, 1, 0),
					BackgroundTransparency = 1,
					TextXAlignment = Enum.TextXAlignment.Left,
					TextColor3 = Theme.Colors.Text,
					TextSize = Settings.TextSize,
					FontFace = Font.fromEnum(Enum.Font.BuilderSansMedium),
					ZIndex = 4,
					Text = "All joints",
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
						Session.SelectedKeys({})
						Session.Seek(TimeAt(Input.Position.X))
						StartDrag("Scrub", Input.Position.X)
					elseif Input.UserInputType == Enum.UserInputType.MouseButton2 then
						LaneMenu(Vector2.new(Input.Position.X, Input.Position.Y), nil)
					end
				end,

				Vide.values(function()
					return Clip.KeyTimes(Session.Current())
				end, function(Time: number)
					return Diamond {
						Time = function()
							return Time
						end,
						Selected = function()
							for _, Ref in Session.SelectedKeys() do
								if math.abs(Ref.Time - Time) < 0.0005 then
									return true
								end
							end

							return false
						end,
						OnDown = function(Shift: boolean)
							Session.SelectColumn(Time, Shift)
							Session.Seek(Time)
							StartDrag("Keys", XOf(Time) + LaneLeft())
						end,
						OnMenu = function(Position: Vector2)
							Session.SelectColumn(Time, false)

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

	const function OnMove(X: number)
		const Active = Drag

		if not Active then
			return
		end

		if Active.Kind == "Scrub" then
			Session.Seek(TimeAt(X))

			return
		end

		const Wanted = Session.SnapTime(Session.Time() + (X - Active.StartX) / Zoom()) - Session.Time()
		const Delta = Wanted - Active.Applied

		if math.abs(Delta) < 0.0005 then
			return
		end

		if Active.Kind == "Keys" then
			Session.MoveSelectedKeys(Delta, "DragKeys")
			Active.Applied += Delta

			return
		end

		const Marker = Active.Marker

		if not Marker then
			return
		end

		const Moved = {
			Time = math.clamp(Marker.Time + Wanted, 0, Session.Current().Length),
			Name = Marker.Name,
			Value = Marker.Value,
		}

		Session.Edit(Clip.SetMarker(Clip.RemoveMarker(Session.Current(), Marker), Moved), "DragMarker")
		Session.SelectedMarker(Moved.Time)
		Active.Marker = Moved
		Active.Applied = Wanted
	end

	Root = Create "Frame" {
		Name = "Timeline",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Theme.Colors.Background,
		ClipsDescendants = true,
		InputChanged = function(Input: InputObject)
			if Input.UserInputType == Enum.UserInputType.MouseMovement then
				OnMove(Input.Position.X)
			elseif Input.UserInputType == Enum.UserInputType.MouseWheel and Input.Position.X >= LaneLeft() then
				if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) or UserInputService:IsKeyDown(Enum.KeyCode.RightControl) then
					const Under = TimeAt(Input.Position.X)
					const Scaled = math.clamp(Zoom() * (if Input.Position.Z > 0 then 1.25 else 0.8), 10, 5000)

					UserZoomed(true)
					Zoom(Scaled)
					Offset(math.max(0, Under - (Input.Position.X - LaneLeft() - LanePadding) / Scaled))
				elseif UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) or UserInputService:IsKeyDown(Enum.KeyCode.RightShift) then
					UserZoomed(true)
					Offset(math.max(0, Offset() - Input.Position.Z * 40 / Zoom()))
				end
			end
		end,
		InputEnded = function(Input: InputObject)
			if Input.UserInputType == Enum.UserInputType.MouseButton1 then
				Drag = nil
			end
		end,

		Create "Frame" {
			Name = "Stack",
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,

			Create "UIListLayout" {SortOrder = Enum.SortOrder.LayoutOrder},
			Header(),
			Events(),
			Summary(),
			Create "ScrollingFrame" {
				Name = "Rows",
				Size = UDim2.fromScale(1, 1),
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				LayoutOrder = 4,
				AutomaticCanvasSize = Enum.AutomaticSize.Y,
				CanvasSize = UDim2.new(),
				ScrollBarThickness = 6,
				ScrollBarImageColor3 = Theme.Colors.DimText,
				ScrollingDirection = Enum.ScrollingDirection.Y,

				Create "UIFlexItem" {FlexMode = Enum.UIFlexMode.Fill},
				Create "UIListLayout" {SortOrder = Enum.SortOrder.LayoutOrder},

				Vide.values(VisibleJoints, function(Joint: Rig.Joint, Index)
					return Row(Joint, Index)
				end),
			},
		},
		Playhead(),
	}

	return Root
end