--!strict
const Format = {}

function Format.Duration(Milliseconds: number): string
	if Milliseconds < 1000 then
		return `{Milliseconds}ms`
	end

	if Milliseconds < 60000 then
		return `{string.format("%.1f", Milliseconds / 1000)}s`
	end

	const Minutes = Milliseconds // 60000
	const Seconds = math.floor((Milliseconds % 60000) / 1000)

	if Minutes < 60 then
		return `{Minutes}m {Seconds}s`
	end

	return `{Minutes // 60}h {Minutes % 60}m`
end

function Format.Clock(Seconds: number): string
	if Seconds < 60 then
		return `{Seconds}s`
	end

	return `{Seconds // 60}m {Seconds % 60}s`
end

return Format