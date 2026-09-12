--!strict
const Easing = {}

export type Style = "Linear" | "Constant" | "Cubic" | "Elastic" | "Bounce" | "Sine" | "Quad" | "Quart" | "Quint" | "Expo" | "Circ" | "Back" | "Smooth"
export type Direction = "In" | "Out" | "InOut"

Easing.Styles = {
	"Linear",
	"Constant",
	"Cubic",
	"Elastic",
	"Bounce",
	"Sine",
	"Quad",
	"Quart",
	"Quint",
	"Expo",
	"Circ",
	"Back",
	"Smooth",
} :: {Style}

Easing.Native = {
	Linear = true,
	Constant = true,
	Cubic = true,
	Elastic = true,
	Bounce = true,
}

Easing.Directions = {
	"In",
	"Out",
	"InOut",
} :: {Direction}

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
	Cubic = function(Alpha: number): number
		return Alpha * Alpha * Alpha
	end,
	Elastic = ElasticIn,
	Bounce = function(Alpha: number): number
		return 1 - BounceOut(1 - Alpha)
	end,
	Sine = function(Alpha: number): number
		return 1 - math.cos(Alpha * math.pi / 2)
	end,
	Quad = function(Alpha: number): number
		return Alpha * Alpha
	end,
	Quart = function(Alpha: number): number
		return Alpha ^ 4
	end,
	Quint = function(Alpha: number): number
		return Alpha ^ 5
	end,
	Expo = function(Alpha: number): number
		return if Alpha == 0 then 0 else 2 ^ (10 * (Alpha - 1))
	end,
	Circ = function(Alpha: number): number
		return 1 - math.sqrt(1 - Alpha * Alpha)
	end,
	Back = function(Alpha: number): number
		return Alpha * Alpha * (2.70158 * Alpha - 1.70158)
	end,
	Smooth = function(Alpha: number): number
		return Alpha * Alpha * (3 - 2 * Alpha)
	end,
}

function Easing.Apply(Alpha: number, Style: Style, Direction: Direction): number
	if Style == "Linear" then
		return Alpha
	end

	if Style == "Constant" then
		return if Alpha > 0 then 1 else 0
	end

	if Style == "Smooth" then
		return Ins.Smooth(Alpha)
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

function Easing.Slope(Style: Style, Direction: Direction, AtStart: boolean): number
	const Step = 0.001

	if AtStart then
		return Easing.Apply(Step, Style, Direction) / Step
	end

	return (1 - Easing.Apply(1 - Step, Style, Direction)) / Step
end

return Easing