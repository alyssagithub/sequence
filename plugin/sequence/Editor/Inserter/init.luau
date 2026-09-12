--!strict
const Players = game:GetService("Players")
const StudioService = game:GetService("StudioService")
const ChangeHistoryService = game:GetService("ChangeHistoryService")
const Selection = game:GetService("Selection")
const Vide = require(script.Parent.Parent.Packages.vide)
const Vow = require(script.Parent.Parent.Packages.vow)
const Rig = require(script.Parent.Rig)

export type Body = "Original" | "R6" | "R15"

export type Preset = {
	Name: string,
	Build: () -> Model?,
}

const Dummies = script.Dummies

const Inserter = {
	Account = Vide.source(""),
	Body = Vide.source("Original" :: Body),
	DefaultBody = Vide.source(false),
	Preview = Vide.source(nil :: Model?),
	Building = Vide.source(false),
	Notice = Vide.source(""),
	Resolved = Vide.source(nil :: {UserId: number, Name: string}?),
}

Inserter.Bodies = {
	"Original",
	"R6",
	"R15",
} :: {Body}

const PartOrder = {
	"HumanoidRootPart",
	"LowerTorso",
	"UpperTorso",
	"Head",
	"LeftUpperArm",
	"LeftLowerArm",
	"LeftHand",
	"RightUpperArm",
	"RightLowerArm",
	"RightHand",
	"LeftUpperLeg",
	"LeftLowerLeg",
	"LeftFoot",
	"RightUpperLeg",
	"RightLowerLeg",
	"RightFoot",
}

const function BuildJoints(Model: Model)
	if #Rig.FindMotors(Model) > 0 then
		return
	end

	const Rank: {[string]: number} = {}

	for Index, Name in PartOrder do
		Rank[Name] = Index
	end

	const Pairs: {[string]: {Attachment}} = {}

	for _, Part in Model:GetChildren() do
		if not Part:IsA("BasePart") then
			continue
		end

		for _, Attachment in Part:GetChildren() do
			if Attachment:IsA("Attachment") and Attachment.Name:match("RigAttachment$") then
				Pairs[Attachment.Name] = Pairs[Attachment.Name] or {}
				table.insert(Pairs[Attachment.Name], Attachment)
			end
		end
	end

	for Name, Found in Pairs do
		if #Found ~= 2 then
			continue
		end

		table.sort(Found, function(A: Attachment, B: Attachment)
			return (Rank[(A.Parent :: Instance).Name] or 99) < (Rank[(B.Parent :: Instance).Name] or 99)
		end)

		const Motor = Instance.new("Motor6D")

		Motor.Name = (Name:gsub("RigAttachment$", ""))
		Motor.Part0 = Found[1].Parent :: BasePart
		Motor.Part1 = Found[2].Parent :: BasePart
		Motor.C0 = Found[1].CFrame
		Motor.C1 = Found[2].CFrame
		Motor.Parent = Found[2].Parent
	end
end

function Inserter.SeatAccessories(Model: Model)
	const Attachments: {[string]: Attachment} = {}

	for _, Part in Model:GetChildren() do
		if not Part:IsA("BasePart") then
			continue
		end

		for _, Attachment in Part:GetChildren() do
			if Attachment:IsA("Attachment") then
				Attachments[Attachment.Name] = Attachment
			end
		end
	end

	for _, Accessory in Model:GetChildren() do
		if not Accessory:IsA("Accoutrement") then
			continue
		end

		const Handle = Accessory:FindFirstChild("Handle")

		if not Handle or not Handle:IsA("BasePart") then
			continue
		end

		const Own = Handle:FindFirstChildOfClass("Attachment")
		const Target = Own and Attachments[Own.Name]

		if not Own or not Target then
			continue
		end

		Handle.CFrame = Target.WorldCFrame * Own.CFrame:Inverse()

		if Handle:FindFirstChild("AccessoryWeld") then
			continue
		end

		const Weld = Instance.new("Weld")

		Weld.Name = "AccessoryWeld"
		Weld.Part0 = Handle
		Weld.Part1 = Target.Parent :: BasePart
		Weld.C0 = Own.CFrame
		Weld.C1 = Target.CFrame
		Weld.Parent = Handle
	end
end

const function Clean(Model: Model)
	BuildJoints(Model)

	for _, Descendant in Model:GetDescendants() do
		if Descendant:IsA("LuaSourceContainer") then
			Descendant:Destroy()
		end
	end

	Inserter.SeatAccessories(Model)
end

const function Describe(): (HumanoidDescription?, string?)
	const Resolved = Inserter.Resolved()

	if not Resolved then
		return Instance.new("HumanoidDescription"), nil
	end

	const Ok, Description = pcall(Players.GetHumanoidDescriptionFromUserIdAsync, Players, Resolved.UserId)

	if not Ok then
		return nil, `Could not read that avatar: {Description}`
	end

	return Description, nil
end

function Inserter.Resolve(Typed: string): string?
	const Trimmed = Typed:match("^%s*(.-)%s*$") or ""

	if Trimmed == "" then
		const UserId = StudioService:GetUserId()

		if UserId == 0 then
			Inserter.Resolved(nil)

			return "Studio is not signed in"
		end

		const Ok, Name = pcall(Players.GetNameFromUserIdAsync, Players, UserId)

		Inserter.Resolved({UserId = UserId, Name = if Ok then Name else `User {UserId}`})

		return nil
	end

	const AsNumber = tonumber(Trimmed)

	if AsNumber then
		const Ok, Name = pcall(Players.GetNameFromUserIdAsync, Players, AsNumber)

		if not Ok then
			Inserter.Resolved(nil)

			return `No user with id {AsNumber}`
		end

		Inserter.Resolved({UserId = AsNumber, Name = Name})

		return nil
	end

	const Ok, UserId = pcall(Players.GetUserIdFromNameAsync, Players, Trimmed)

	if not Ok then
		Inserter.Resolved(nil)

		return `No user called {Trimmed}`
	end

	Inserter.Resolved({UserId = UserId, Name = Trimmed})

	return nil
end

const function Dummy(Name: string): Model?
	const Found = Dummies:FindFirstChild(Name)

	if not Found then
		return nil
	end

	const Model = Found:Clone()

	for _, Descendant in Model:GetDescendants() do
		if Descendant:IsA("BasePart") then
			Descendant.Anchored = false
		end
	end

	return Model
end

function Inserter.BuildAccount(): (Model?, string?)
	const Body = Inserter.Body()
	const Resolved = Inserter.Resolved()

	if Inserter.DefaultBody() then
		const Kind = if Body == "R6" then "R6" else "R15"
		const Made = Dummy(Kind)

		if Made then
			Made.Name = `{Kind} dummy`
		end

		return Made, if Made then nil else "The dummy models are missing from the plugin"
	end

	const Description, Problem = Describe()

	if not Description then
		return nil, Problem
	end

	if Body == "R15" then
		Description.Head = 0
		Description.BodyTypeScale = 0
		Description.ProportionScale = 0
	end

	const RigType = if Body == "R6" then Enum.HumanoidRigType.R6 else Enum.HumanoidRigType.R15
	const Ok, Model = pcall(Players.CreateHumanoidModelFromDescriptionAsync, Players, Description, RigType)

	if not Ok then
		return nil, `Could not build the character: {Model}`
	end

	Model.Name = if Resolved then Resolved.Name else "Character"
	Clean(Model)

	return Model, nil
end

function Inserter.BuildPreview(): Vow.Vow
	return Vow.new(function(Pending: Vow.Vow)
		task.spawn(function()
			const Problem = Inserter.Resolve(Inserter.Account())

			if Problem then
				Vow.reject(Pending, Problem)

				return
			end

			const Model, Failed = Inserter.BuildAccount()

			if not Vow.isAlive(Pending) then
				if Model then
					Model:Destroy()
				end

				return
			end

			if Model then
				Vow.resolve(Pending, Model)
			else
				Vow.reject(Pending, Failed or "Could not build the character")
			end
		end)
	end)
end

Inserter.Presets = {} :: {Preset}

for _, Name in {"R6", "R15", "TemplateR6", "TemplateR15"} do
	table.insert(Inserter.Presets, {
		Name = Name,
		Build = function()
			return Dummy(Name)
		end,
	})
end

function Inserter.Place(Model: Model): Model
	const Camera = workspace.CurrentCamera
	const Ahead = Camera.CFrame.Position + Camera.CFrame.LookVector * 12
	const Ground = workspace:Raycast(Ahead + Vector3.new(0, 50, 0), Vector3.new(0, -200, 0))
	const Height = Model:GetExtentsSize().Y
	const Floor = if Ground then Ground.Position.Y else Ahead.Y - Height / 2
	const Facing = CFrame.lookAt(Vector3.new(Ahead.X, Floor + Height / 2, Ahead.Z), Vector3.new(Camera.CFrame.Position.X, Floor + Height / 2, Camera.CFrame.Position.Z))

	Model:PivotTo(Facing)
	Model.Parent = workspace

	const Humanoid = Model:FindFirstChildOfClass("Humanoid")

	if Humanoid then
		Humanoid.DisplayName = Model.Name
	end

	Selection:Set({Model})
	ChangeHistoryService:SetWaypoint(`Insert {Model.Name}`)

	return Model
end

function Inserter.Destroy()
	const Preview = Inserter.Preview()

	if Preview then
		Preview:Destroy()
		Inserter.Preview(nil)
	end
end

return Inserter