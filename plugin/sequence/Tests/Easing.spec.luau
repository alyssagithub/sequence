return function()
	const Easing = require(script.Parent.Parent.Editor.Easing)

	describe("every style and direction", function()
		it("starts at 0 and ends at 1", function()
			for _, Style in Easing.Styles do
				for _, Direction in Easing.Directions do
					expect(Easing.Apply(0, Style, Direction)).to.be.near(0, 0.0001)
					expect(Easing.Apply(1, Style, Direction)).to.be.near(1, 0.0001)
				end
			end
		end)

		it("mirrors In and Out around the midpoint for the symmetric styles", function()
			for _, Style in {"Sine", "Quad", "Quart", "Quint", "Expo", "Circ"} do
				for _, Alpha in {0.1, 0.3, 0.7} do
					const Forward = Easing.Apply(Alpha, Style :: any, "In")
					const Mirrored = 1 - Easing.Apply(1 - Alpha, Style :: any, "Out")

					expect(Forward).to.be.near(Mirrored, 0.0001)
				end
			end
		end)
	end)

	describe("engine matched styles", function()
		it("Linear is the identity", function()
			expect(Easing.Apply(0.37, "Linear", "In")).to.be.near(0.37, 0.0001)
		end)

		it("Constant jumps to the next value as soon as the span starts, as the engine does", function()
			expect(Easing.Apply(0, "Constant", "In")).to.equal(0)
			expect(Easing.Apply(0.001, "Constant", "In")).to.equal(1)
		end)

		it("Back dips below zero on the way in", function()
			expect(Easing.Apply(0.2, "Back", "In") < 0).to.equal(true)
		end)

		it("Elastic Out overshoots past one", function()
			local Highest = 0

			for Step = 1, 99 do
				Highest = math.max(Highest, Easing.Apply(Step / 100, "Elastic", "Out"))
			end

			expect(Highest > 1).to.equal(true)
		end)
	end)

	describe("Slope", function()
		it("is flat at both ends of Smooth", function()
			expect(Easing.Slope("Smooth", "InOut", true)).to.be.near(0, 0.01)
			expect(Easing.Slope("Smooth", "InOut", false)).to.be.near(0, 0.01)
		end)

		it("is one everywhere for Linear", function()
			expect(Easing.Slope("Linear", "In", true)).to.be.near(1, 0.001)
			expect(Easing.Slope("Linear", "In", false)).to.be.near(1, 0.001)
		end)
	end)
end