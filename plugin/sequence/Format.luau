--!strict
const Format = {}

function Format.Timecode(Seconds: number, FrameRate: number): string
	const Frames = math.round(Seconds * FrameRate)
	const Whole = Frames // FrameRate

	return `{Whole}:{string.format("%02d", Frames - Whole * FrameRate)}`
end

function Format.Degrees(Radians: number): string
	return `{math.round(math.deg(Radians) * 10) / 10}`
end

return Format
