--!strict
const Vide = require(script.Parent.Parent.Packages.vide)
const Session = require(script.Parent.Session)
const Rig = require(script.Parent.Rig)
const Pose = require(script.Parent.Pose)
const Clip = require(script.Parent.Clip)

const OnionSkin = {}

local Folder: Folder?
local Ghosts: {{Rig: Rig.Rig, Tint: Color3}} = {}

const function Clear()
	table.clear(Ghosts)

	if Folder then
		Folder:Destroy()
		Folder = nil
	end
end

const function MakeGhost(Source: Model, Tint: Color3, Parent: Instance): Rig.Rig?
	const Copy = Source:Clone()

	for _, Descendant in Copy:GetDescendants() do
		if Descendant:IsA("BasePart") then
			Descendant.Transparency = 0.7
			Descendant.Color = Tint
			Descendant.Material = Enum.Material.SmoothPlastic
			Descendant.CanCollide = false
			Descendant.CanQuery = false
			Descendant.CanTouch = false
			Descendant.CastShadow = false
			Descendant.Anchored = true
		elseif not Descendant:IsA("Motor6D") and not Descendant:IsA("Model") then
			Descendant:Destroy()
		end
	end

	Copy.Parent = Parent

	const Loaded = Rig.Load(Copy)

	if not Loaded then
		Copy:Destroy()

		return nil
	end

	return Loaded
end

const function Neighbours(Current: Clip.Clip, Time: number): (number?, number?)
	local Before: number?
	local After: number?

	for _, KeyTime in Clip.KeyTimes(Current) do
		if KeyTime < Time - 0.0005 then
			Before = KeyTime
		elseif KeyTime > Time + 0.0005 and not After then
			After = KeyTime
		end
	end

	return Before, After
end

function OnionSkin.Start()
	Vide.effect(function()
		const Loaded = Session.Rig()

		if not Loaded or not Session.OnionSkin() then
			Clear()

			return
		end

		if not Folder then
			const Made = script.Ghosts:Clone()

			Made.Name = "Sequence onion skin"
			Made.Parent = workspace
			Folder = Made

			for _, Tint in {
				Color3.fromRGB(80, 140, 255),
				Color3.fromRGB(255, 120, 80),
			} do
				const Ghost = MakeGhost(Loaded.Model, Tint, Made)

				if Ghost then
					table.insert(Ghosts, {Rig = Ghost, Tint = Tint})
				end
			end
		end

		const Current = Session.Current()
		const Time = Session.Time()
		const Before, After = Neighbours(Current, Time)

		for Index, Ghost in Ghosts do
			const At = if Index == 1 then Before else After
			const Root = Ghost.Rig.Root

			Root.CFrame = Loaded.Root.CFrame

			for _, Part in Ghost.Rig.Model:GetDescendants() do
				if Part:IsA("BasePart") then
					Part.Transparency = if At then 0.7 else 1
				end
			end

			if At then
				Rig.Apply(Ghost.Rig, Pose.Sample(Current, At))
			end
		end
	end)
end

function OnionSkin.Destroy()
	Clear()
end

return OnionSkin