return function()
	const Clip = require(script.Parent.Parent.Editor.Clip)
	const Pose = require(script.Parent.Parent.Editor.Pose)

	const function Key(Time: number, Value: any, Style: string?, Direction: string?): Clip.Key
		return {
			Time = Time,
			Value = Value,
			EasingStyle = (Style or "Linear") :: any,
			EasingDirection = (Direction or "In") :: any,
		}
	end

	describe("Blend", function()
		it("lerps numbers, vectors, colours and CFrames", function()
			expect(Pose.Blend(0, 10, 0.25)).to.be.near(2.5, 0.0001)
			expect((Pose.Blend(Vector3.zero, Vector3.new(2, 4, 6), 0.5) - Vector3.new(1, 2, 3)).Magnitude).to.be.near(0, 0.0001)
			expect(Pose.Blend(Color3.new(0, 0, 0), Color3.new(1, 1, 1), 0.5).R).to.be.near(0.5, 0.01)

			const Half = Pose.Blend(CFrame.identity, CFrame.Angles(0, 0, math.rad(90)), 0.5)

			expect(math.deg(select(3, Half:ToEulerAnglesXYZ()))).to.be.near(45, 0.01)
		end)

		it("holds booleans and strings until the next key", function()
			expect(Pose.Blend(false, true, 0.99)).to.equal(false)
			expect(Pose.Blend(false, true, 1)).to.equal(true)
			expect(Pose.Blend("a", "b", 0.2)).to.equal("a")
		end)
	end)

	describe("SampleTrack", function()
		const Track = {
			Keys = {
				Key(0, 0),
				Key(1, 10, "Constant"),
				Key(2, 20),
			},
		}

		it("interpolates inside a linear span and holds outside the keys", function()
			expect(Pose.SampleTrack(Track :: any, 0.5)).to.be.near(5, 0.0001)
			expect(Pose.SampleTrack(Track :: any, -1)).to.equal(0)
			expect(Pose.SampleTrack(Track :: any, 5)).to.equal(20)
		end)

		it("uses the easing of the earlier key for the span it starts", function()
			expect(Pose.SampleTrack(Track :: any, 1)).to.equal(10)
			expect(Pose.SampleTrack(Track :: any, 1.01)).to.equal(20)
		end)
	end)

	describe("Sample", function()
		it("returns a CFrame per joint track and skips property tracks", function()
			const Part = Instance.new("Part")
			local Current = Clip.SetKey(Clip.New("Test"), "Head", Key(0, CFrame.new(1, 0, 0)))

			Current = Clip.SetKey(Current, Clip.PropertyTrackName(Part, "Transparency"), Key(0, 1), Part, "Transparency")

			const Sampled = Pose.Sample(Current, 0)

			expect(Sampled.Head.Position.X).to.equal(1)

			local Count = 0

			for _ in Sampled do
				Count += 1
			end

			expect(Count).to.equal(1)
			expect(#Pose.SampleProperties(Current, 0)).to.equal(1)
			Part:Destroy()
		end)
	end)

	describe("Mirror", function()
		it("swaps the side of a name in every naming scheme", function()
			expect(Pose.MirrorName("LeftUpperArm")).to.equal("RightUpperArm")
			expect(Pose.MirrorName("Right Leg")).to.equal("Left Leg")
			expect(Pose.MirrorName("L_Hand")).to.equal("R_Hand")
			expect(Pose.MirrorName("Head")).to.equal("Head")
		end)

		it("flips a rotation and is its own inverse", function()
			const Turned = CFrame.Angles(0, math.rad(30), math.rad(20))
			const Mirrored = Pose.Mirror(Turned)

			expect(math.deg(select(2, Mirrored:ToEulerAnglesXYZ()))).to.be.near(-30, 0.01)
			expect(Pose.Mirror(Mirrored):FuzzyEq(Turned, 0.0001)).to.equal(true)
		end)
	end)
end