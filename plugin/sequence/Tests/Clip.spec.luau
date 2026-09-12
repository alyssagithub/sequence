return function()
	const Clip = require(script.Parent.Parent.Editor.Clip)

	const function Key(Time: number, Value: any, Style: string?): Clip.Key
		return {
			Time = Time,
			Value = Value,
			EasingStyle = (Style or "Linear") :: any,
			EasingDirection = "In",
		}
	end

	describe("keys", function()
		it("stay sorted by time however they are added", function()
			local Current = Clip.New("Test")

			Current = Clip.SetKey(Current, "Head", Key(1, 1))
			Current = Clip.SetKey(Current, "Head", Key(0, 0))
			Current = Clip.SetKey(Current, "Head", Key(0.5, 0.5))

			expect(Current.Tracks.Head.Keys[1].Time).to.equal(0)
			expect(Current.Tracks.Head.Keys[2].Time).to.equal(0.5)
			expect(Current.Tracks.Head.Keys[3].Time).to.equal(1)
		end)

		it("replace a key at the same time instead of duplicating it", function()
			local Current = Clip.New("Test")

			Current = Clip.SetKey(Current, "Head", Key(0.5, 1))
			Current = Clip.SetKey(Current, "Head", Key(0.5, 2))

			expect(#Current.Tracks.Head.Keys).to.equal(1)
			expect(Current.Tracks.Head.Keys[1].Value).to.equal(2)
		end)

		it("never mutate the clip they were given", function()
			const Original = Clip.New("Test")
			const Edited = Clip.SetKey(Original, "Head", Key(0, 1))

			expect(Original.Tracks.Head).never.to.be.ok()
			expect(Edited.Tracks.Head).to.be.ok()
		end)

		it("drop an empty track when its last key goes", function()
			local Current = Clip.SetKey(Clip.New("Test"), "Head", Key(0, 1))

			Current = Clip.RemoveKey(Current, "Head", 0)

			expect(Current.Tracks.Head).never.to.be.ok()
		end)

		it("move without changing the value or easing", function()
			local Current = Clip.SetKey(Clip.New("Test"), "Head", Key(0, 7, "Bounce"))

			Current = Clip.MoveKey(Current, "Head", 0, 0.25)

			const Moved = Clip.FindKey(Current, "Head", 0.25)

			expect(Moved).to.be.ok()
			expect((Moved :: Clip.Key).Value).to.equal(7)
			expect((Moved :: Clip.Key).EasingStyle).to.equal("Bounce")
			expect(Clip.FindKey(Current, "Head", 0)).never.to.be.ok()
		end)
	end)

	describe("scale", function()
		it("stretches every key time and the length by the factor", function()
			local Current = Clip.SetLength(Clip.New("Test"), 2)

			Current = Clip.SetKey(Current, "Head", Key(0.5, 1))
			Current = Clip.SetKey(Current, "Head", Key(1, 2))
			Current = Clip.Scale(Current, 2)

			expect(Current.Length).to.equal(4)
			expect(Clip.FindKey(Current, "Head", 1)).to.be.ok()
			expect(Clip.FindKey(Current, "Head", 2)).to.be.ok()
		end)
	end)

	describe("markers", function()
		it("are unique by time and name", function()
			local Current = Clip.New("Test")

			Current = Clip.SetMarker(Current, {Time = 0.5, Name = "Hit", Value = ""})
			Current = Clip.SetMarker(Current, {Time = 0.5, Name = "Hit", Value = "again"})

			expect(#Current.Markers).to.equal(1)
			expect(Current.Markers[1].Value).to.equal("again")
			expect(Clip.FindMarker(Current, 0.5, "Hit")).to.be.ok()
		end)
	end)

	describe("property tracks", function()
		it("are named after the object and kept apart from joints", function()
			const Part = Instance.new("Part")
			const Name = Clip.PropertyTrackName(Part, "Transparency")

			expect(Clip.IsProperty(Name)).to.equal(true)
			expect(Clip.IsProperty("Head")).to.equal(false)

			const Current = Clip.SetKey(Clip.New("Test"), Name, Key(0, 0.5), Part, "Transparency")

			expect(Clip.JointTracks(Current)[Name]).never.to.be.ok()
			expect(Current.Tracks[Name].Property).to.equal("Transparency")
			Part:Destroy()
		end)
	end)
end