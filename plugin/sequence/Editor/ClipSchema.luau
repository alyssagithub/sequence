--!strict
const Typed = require(script.Parent.Parent.Packages.typed)
const Easing = require(script.Parent.Easing)
const Clip = require(script.Parent.Clip)

const function OneOf(Choices: {string})
	return Typed.refine(Typed.string())(function(Value, Result)
		if table.find(Choices, Value) then
			return Result.ok()
		end

		return Result.err(`expected one of {table.concat(Choices, ", ")}, got {Value}`)
	end)
end

const KeySchema = Typed.table({
	Time = Typed.number({min = 0}),
	Value = Typed.is("CFrame"),
	EasingStyle = OneOf(Easing.Styles),
	EasingDirection = OneOf(Easing.Directions),
})

const ClipSchema = Typed.table({
	Name = Typed.string({length = {min = 1}}),
	Length = Typed.number({min = 0}),
	Looping = Typed.boolean(),
	Priority = OneOf(Clip.Priorities),
	Tracks = Typed.iterable(Typed.string(), Typed.table({Keys = Typed.array(KeySchema)})),
	Markers = Typed.array(Typed.table({
		Time = Typed.number({min = 0}),
		Name = Typed.string({length = {min = 1}}),
		Value = Typed.string(),
	})),
})

return {
	parse = ClipSchema.parse,
	Describe = Typed.formatIssues,
}