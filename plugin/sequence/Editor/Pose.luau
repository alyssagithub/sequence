--!strict
const Clip = require(script.Parent.Clip)
const Easing = require(script.Parent.Easing)

const Pose = {}

function Pose.Blend(From: any, To: any, Alpha: number): any
	const Kind = typeof(From)

	if Kind == "CFrame" then
		return (From :: CFrame):Lerp(To, Alpha)
	end

	if Kind == "number" then
		return From + (To - From) * Alpha
	end

	if Kind == "Vector3" or Kind == "Vector2" or Kind == "UDim2" or Kind == "UDim" then
		return (From :: any):Lerp(To, Alpha)
	end

	if Kind == "Color3" then
		return (From :: Color3):Lerp(To, Alpha)
	end

	return if Alpha < 1 then From else To
end

function Pose.SampleTrack(Track: Clip.Track, Time: number): any
	const Keys = Track.Keys

	if #Keys == 0 then
		return nil
	end

	if Time <= Keys[1].Time then
		return Keys[1].Value
	end

	const Last = Keys[#Keys]

	if Time >= Last.Time then
		return Last.Value
	end

	for Index = 1, #Keys - 1 do
		const From = Keys[Index]
		const To = Keys[Index + 1]

		if Time < From.Time or Time > To.Time then
			continue
		end

		const Span = To.Time - From.Time

		if Span <= 0 then
			return To.Value
		end

		return Pose.Blend(From.Value, To.Value, Easing.Apply((Time - From.Time) / Span, From.EasingStyle, From.EasingDirection))
	end

	return Last.Value
end

function Pose.Sample(Current: Clip.Clip, Time: number): {[string]: CFrame}
	const Sampled = {}

	for Name, Track in Current.Tracks do
		if not Clip.IsProperty(Name) then
			Sampled[Name] = Pose.SampleTrack(Track, Time)
		end
	end

	return Sampled
end

function Pose.SampleProperties(Current: Clip.Clip, Time: number): {{Object: Instance, Property: string, Value: any}}
	const Sampled = {}

	for Name, Track in Current.Tracks do
		if Clip.IsProperty(Name) and Track.Object and Track.Property then
			table.insert(Sampled, {
				Object = Track.Object,
				Property = Track.Property,
				Value = Pose.SampleTrack(Track, Time),
			})
		end
	end

	return Sampled
end

function Pose.Mirror(Value: CFrame): CFrame
	const Flip = CFrame.new(0, 0, 0, -1, 0, 0, 0, 1, 0, 0, 0, 1)

	return Flip * Value * Flip
end

function Pose.MirrorName(Name: string): string
	if Name:match("^Left") then
		return `Right{Name:sub(5)}`
	end

	if Name:match("^Right") then
		return `Left{Name:sub(6)}`
	end

	if Name:match("^L_") or Name:match("^L%.") then
		return `R{Name:sub(2)}`
	end

	if Name:match("^R_") or Name:match("^R%.") then
		return `L{Name:sub(2)}`
	end

	return Name
end

return Pose