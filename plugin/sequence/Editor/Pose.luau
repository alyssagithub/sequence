--!strict
const Clip = require(script.Parent.Clip)
const Easing = require(script.Parent.Easing)

const Pose = {}

function Pose.SampleTrack(Track: Clip.Track, Time: number): CFrame
	const Keys = Track.Keys

	if #Keys == 0 then
		return CFrame.identity
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

		return From.Value:Lerp(To.Value, Easing.Apply((Time - From.Time) / Span, From.EasingStyle, From.EasingDirection))
	end

	return Last.Value
end

function Pose.Sample(Current: Clip.Clip, Time: number): {[string]: CFrame}
	const Sampled = {}

	for Name, Track in Current.Tracks do
		Sampled[Name] = Pose.SampleTrack(Track, Time)
	end

	return Sampled
end

return Pose