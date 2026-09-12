--!strict
const Players = game:GetService("Players")
const RunService = game:GetService("RunService")
const HttpService = game:GetService("HttpService")
const ReplicatedStorage = game:GetService("ReplicatedStorage")

const Runtime = ReplicatedStorage:WaitForChild("SequencePlaytest")
const Reel = require(Runtime.Packages.reel)
const Easing = require(Runtime.Easing)
const Player = Players.LocalPlayer

type Playing = {
	Model: Model,
	Rig: any,
	Asset: any,
	State: any,
	Prepared: any,
	Length: number,
	Looping: boolean,
	Properties: {{Object: Instance, Property: string, Keys: {any}}},
}

const function Decode(Stored: any): any
	const Kind = Stored[1]
	const Data = Stored[2]

	if Kind == "CFrame" then
		return CFrame.new(unpack(Data))
	end

	if Kind == "Vector3" then
		return Vector3.new(Data[1], Data[2], Data[3])
	end

	if Kind == "Vector2" then
		return Vector2.new(Data[1], Data[2])
	end

	if Kind == "Color3" then
		return Color3.new(Data[1], Data[2], Data[3])
	end

	if Kind == "UDim2" then
		return UDim2.new(Data[1], Data[2], Data[3], Data[4])
	end

	if Kind == "EnumItem" then
		return (Enum :: any)[Data[1]][Data[2]]
	end

	return Data
end

const function Blend(From: any, To: any, Alpha: number): any
	const Kind = typeof(From)

	if Kind == "number" then
		return From + (To - From) * Alpha
	end

	if Kind == "CFrame" or Kind == "Vector3" or Kind == "Vector2" or Kind == "UDim2" or Kind == "Color3" then
		return (From :: any):Lerp(To, Alpha)
	end

	return if Alpha < 1 then From else To
end

const function SampleKeys(Keys: {any}, Time: number): any
	if #Keys == 0 then
		return nil
	end

	if Time <= Keys[1].Time then
		return Keys[1].Value
	end

	for Index = 1, #Keys - 1 do
		const From = Keys[Index]
		const To = Keys[Index + 1]

		if Time >= From.Time and Time <= To.Time then
			const Span = To.Time - From.Time

			return Blend(From.Value, To.Value, if Span <= 0 then 1 else Easing.Apply((Time - From.Time) / Span, From.EasingStyle, From.EasingDirection))
		end
	end

	return Keys[#Keys].Value
end

const function Start(Clip: KeyframeSequence, Model: Model): Playing?
	const Rig = Reel.rig.load_rig(Model)
	const Asset = Reel.animation.load_keyframe_sequence(Clip)
	const Binding = Reel.animation.bind_animation(Asset, Rig)
	const State = {
		binding = Binding,
		time_position = 0,
		weight = 1,
	}
	const Properties = {}

	for _, Link in Clip:GetChildren() do
		if Link:IsA("ObjectValue") and Link.Value and Link:GetAttribute("Property") then
			const Keys = HttpService:JSONDecode(Link:GetAttribute("Keys") :: string)

			for _, Key in Keys do
				Key.Value = Decode(Key.Value)
			end

			table.insert(Properties, {
				Object = Link.Value :: Instance,
				Property = Link:GetAttribute("Property") :: string,
				Keys = Keys,
			})
		end
	end

	return {
		Model = Model,
		Rig = Rig,
		Asset = Asset,
		State = State,
		Prepared = Reel.solver.prepare_tracks({{asset = Asset, state = State}}),
		Length = math.max(Asset.length, 0.01),
		Looping = Clip.Loop,
		Properties = Properties,
	}
end

const Playing: {Playing} = {}
const Speed = Runtime:GetAttribute("Speed") or 1
local Clock = 0
local Paused = false

const function Load()
	const Character = Player.Character or Player.CharacterAdded:Wait()

	task.wait(0.2)

	for _, Clip in Runtime.Clips:GetChildren() do
		if not Clip:IsA("KeyframeSequence") then
			continue
		end

		local Model: Model?

		if Clip:GetAttribute("IsCharacter") then
			Model = Character

			const Animate = Character:FindFirstChild("Animate")

			if Animate and Animate:IsA("LocalScript") then
				Animate.Disabled = true
			end
		else
			const Link = Clip:FindFirstChild("Target")

			Model = if Link and Link:IsA("ObjectValue") and Link.Value and Link.Value:IsA("Model") then Link.Value else nil
		end

		if not Model then
			warn(`Sequence playtest could not find a rig for {Clip.Name}`)

			continue
		end

		if not Clip:GetAttribute("IsCharacter") then
			const Root = Clip:GetAttribute("RootName")

			for _, Part in Model:GetDescendants() do
				if Part:IsA("BasePart") and Part.Name ~= Root then
					Part.Anchored = false
				end
			end
		end

		const Humanoid = Model:FindFirstChildOfClass("Humanoid")
		const Animator = Humanoid and Humanoid:FindFirstChildOfClass("Animator")

		if Animator then
			for _, Track in Animator:GetPlayingAnimationTracks() do
				Track:Stop(0)
			end

			Animator:Destroy()
		end

		const Ok, Result = pcall(Start, Clip, Model)

		if Ok and Result then
			table.insert(Playing, Result)
		else
			warn(`Sequence playtest could not start {Clip.Name}: {Result}`)
		end
	end
end

Load()

const Gui = Instance.new("ScreenGui")

Gui.Name = "SequencePlaytest"
Gui.ResetOnSpawn = false
Gui.Parent = Player:WaitForChild("PlayerGui")

const Label = Instance.new("TextButton")

Label.Size = UDim2.fromOffset(220, 28)
Label.Position = UDim2.new(0, 12, 1, -40)
Label.BackgroundColor3 = Color3.fromRGB(20, 20, 24)
Label.TextColor3 = Color3.fromRGB(230, 230, 230)
Label.TextSize = 14
Label.FontFace = Font.fromEnum(Enum.Font.BuilderSans)
Label.Text = "Sequence: click to restart"
Label.Parent = Gui

Label.Activated:Connect(function()
	Clock = 0
	Paused = false
end)

RunService.RenderStepped:Connect(function(Delta: number)
	if Paused then
		return
	end

	Clock += Delta * Speed

	for _, Entry in Playing do
		if not Entry.Model.Parent then
			continue
		end

		local Time = Clock

		if Entry.Looping then
			Time = Clock % Entry.Length
		elseif Time > Entry.Length then
			Time = Entry.Length
		end

		Entry.State.time_position = Time
		Reel.solver.solve_prepared(Entry.Rig, Entry.Prepared)

		for Index, Motor in Entry.Rig.motors do
			if Motor then
				(Motor :: any).Transform = Entry.Rig.transforms[Index]
			end
		end

		for Index, Bone in Entry.Rig.bones do
			if Bone then
				(Bone :: Bone).Transform = Entry.Rig.transforms[Index]
			end
		end

		for _, Track in Entry.Properties do
			const Value = SampleKeys(Track.Keys, Time)

			if Value ~= nil and Track.Object.Parent then
				pcall(function()
					(Track.Object :: any)[Track.Property] = Value
				end)
			end
		end
	end

	Label.Text = `Sequence: {string.format("%.2f", Clock % math.max(Playing[1] and Playing[1].Length or 1, 0.01))}s, click to restart`
end)