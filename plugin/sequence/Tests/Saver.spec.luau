return function()
	const Clip = require(script.Parent.Parent.Editor.Clip)
	const Rig = require(script.Parent.Parent.Editor.Rig)
	const Saver = require(script.Parent.Parent.Editor.Saver)
	const Pose = require(script.Parent.Parent.Editor.Pose)

	const function Key(Time: number, Value: any, Style: string?, Direction: string?): Clip.Key
		return {
			Time = Time,
			Value = Value,
			EasingStyle = (Style or "Linear") :: any,
			EasingDirection = (Direction or "In") :: any,
		}
	end

	local Model: Model
	local Loaded: Rig.Rig

	beforeAll(function()
		Model = script.Parent.Parent.Editor.Inserter.Dummies.R15:Clone()
		Model.Parent = workspace
		Loaded = Rig.Load(Model) :: Rig.Rig
	end)

	afterAll(function()
		Model:Destroy()
	end)

	const function Sample(): Clip.Clip
		local Current = Clip.SetLength(Clip.New("Sample"), 1.5)

		Current = Clip.SetKey(Current, "LeftUpperArm", Key(0, CFrame.identity))
		Current = Clip.SetKey(Current, "LeftUpperArm", Key(0.5, CFrame.Angles(0, 0, math.rad(80)), "Cubic", "InOut"))
		Current = Clip.SetKey(Current, "LeftUpperArm", Key(1, CFrame.Angles(0, 0, math.rad(20))))
		Current = Clip.SetKey(Current, "LowerTorso", Key(0, CFrame.new(0, 0.5, 0)))
		Current = Clip.SetMarker(Current, {Time = 0.5, Name = "Peak", Value = "x"})

		return Current
	end

	describe("KeyframeSequence round trip", function()
		it("keeps keys, values, easing, markers and length", function()
			const Sequence = Saver.ToSequence(Sample(), Loaded, 30)
			const Back, Note = Saver.FromSequence(Sequence, Loaded)

			expect(Note).never.to.be.ok()
			expect(Back).to.be.ok()

			const Read = Back :: Clip.Clip
			const Mid = Clip.FindKey(Read, "LeftUpperArm", 0.5) :: Clip.Key

			expect(Mid).to.be.ok()
			expect(math.deg(select(3, Mid.Value:ToEulerAnglesXYZ()))).to.be.near(80, 0.01)
			expect(Mid.EasingStyle).to.equal("Cubic")
			expect(Mid.EasingDirection).to.equal("InOut")
			expect(#Read.Markers).to.equal(1)
			expect(Read.Length).to.be.near(1.5, 0.001)
			Sequence:Destroy()
		end)

		it("bakes a Blender style into per frame keys that play back the same", function()
			local Current = Sample()

			Current = Clip.SetKey(Current, "LeftUpperArm", Key(0, CFrame.identity, "Back", "Out"))

			const Sequence = Saver.ToSequence(Current, Loaded, 30)
			const Read = Saver.FromSequence(Sequence, Loaded) :: Clip.Clip
			const Original = Pose.SampleTrack(Current.Tracks.LeftUpperArm, 0.2)
			const Played = Pose.SampleTrack(Read.Tracks.LeftUpperArm, 0.2)

			expect(#Read.Tracks.LeftUpperArm.Keys > 10).to.equal(true)
			expect(math.deg(select(3, Played:ToEulerAnglesXYZ()))).to.be.near(math.deg(select(3, Original:ToEulerAnglesXYZ())), 1.5)
			Sequence:Destroy()
		end)
	end)

	describe("CurveAnimation round trip", function()
		it("nests body part folders and reads the same values back", function()
			const Curve = Saver.ToCurve(Sample(), Loaded, 30)
			const Root = Curve:FindFirstChild("HumanoidRootPart")

			expect(Root).to.be.ok()
			expect((Root :: Instance):FindFirstChild("LowerTorso")).to.be.ok()

			const Back, Note = Saver.FromCurve(Curve, Loaded)

			expect(Note).never.to.be.ok()

			const Read = Back :: Clip.Clip
			const Mid = Clip.FindKey(Read, "LeftUpperArm", 0.5) :: Clip.Key

			expect(math.deg(select(3, Mid.Value:ToEulerAnglesXYZ()))).to.be.near(80, 0.05)
			expect(Clip.FindKey(Read, "LowerTorso", 0)).to.be.ok()
			expect(#Read.Markers).to.equal(1)
			Curve:Destroy()
		end)
	end)

	describe("Baked", function()
		it("leaves native styles alone", function()
			const Current = Sample()

			expect(#Saver.Baked(Current, 30).Tracks.LeftUpperArm.Keys).to.equal(3)
		end)
	end)
end