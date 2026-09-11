--!strict
const Easing = {}

export type Style = "Linear" | "Constant" | "Cubic" | "Elastic" | "Bounce"
export type Direction = "In" | "Out" | "InOut"

Easing.Styles = {
	"Linear",
	"Constant",
	"Cubic",
	"Elastic",
	"Bounce",
} :: {Style}

Easing.Directions = {
	"In",
	"Out",
	"InOut",
} :: {Direction}

const function CubicIn(Alpha: number): number
	return Alpha * Alpha * Alpha
end

const function ElasticIn(Alpha: number): number
	if Alpha == 0 or Alpha == 1 then
		return Alpha
	end

	return -(2 ^ (10 * (Alpha - 1))) * math.sin((Alpha - 1.075) * (2 * math.pi) / 0.3)
end

const function BounceOut(Alpha: number): number
	if Alpha < 1 / 2.75 then
		return 7.5625 * Alpha * Alpha
	end

	if Alpha < 2 / 2.75 then
		const Shifted = Alpha - 1.5 / 2.75

		return 7.5625 * Shifted * Shifted + 0.75
	end

	if Alpha < 2.5 / 2.75 then
		const Shifted = Alpha - 2.25 / 2.75

		return 7.5625 * Shifted * Shifted + 0.9375
	end

	const Shifted = Alpha - 2.625 / 2.75

	return 7.5625 * Shifted * Shifted + 0.984375
end

const Ins: {[string]: (number) -> number} = {
	Cubic = CubicIn,
	Elastic = ElasticIn,
	Bounce = function(Alpha: number): number
		return 1 - BounceOut(1 - Alpha)
	end,
}

function Easing.Apply(Alpha: number, Style: Style, Direction: Direction): number
	if Style == "Linear" then
		return Alpha
	end

	if Style == "Constant" then
		return if Alpha > 0 then 1 else 0
	end

	const In = Ins[Style]

	if Direction == "In" then
		return In(Alpha)
	end

	if Direction == "Out" then
		return 1 - In(1 - Alpha)
	end

	if Style == "Bounce" then
		return if Alpha < 0.5 then In(Alpha * 2) / 2 else 0.5 + In(Alpha * 2 - 1) / 2
	end

	if Style == "Elastic" then
		if Alpha == 0 or Alpha == 1 then
			return Alpha
		end

		const Doubled = Alpha * 2

		if Doubled < 1 then
			return -0.5 * 2 ^ (10 * (Doubled - 1)) * math.sin((Doubled - 1.1125) * (2 * math.pi) / 0.45)
		end

		return 2 ^ (-10 * (Doubled - 1)) * math.sin((Doubled - 1.1125) * (2 * math.pi) / 0.45) * 0.5 + 1
	end

	if Alpha < 0.5 then
		return In(Alpha * 2) / 2
	end

	return 1 - In((1 - Alpha) * 2) / 2
end

return Easing