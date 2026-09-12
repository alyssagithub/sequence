--!strict
const Players = game:GetService("Players")
const StudioService = game:GetService("StudioService")
const InsertService = game:GetService("InsertService")
const ChangeHistoryService = game:GetService("ChangeHistoryService")
const Selection = game:GetService("Selection")
const Vide = require(script.Parent.Parent.Packages.vide)
const Rig = require(script.Parent.Rig)

export type Body = "Original" | "R6" | "R15" | "OldR15"

export type Preset = {
	Name: string,
	Build: () -> Model?,
}

const Inserter = {
	Account = Vide.source(""),
	Body = Vide.source("Original" :: Body),
	DefaultBody = Vide.source(false),
	Face = Vide.source(0),
	FaceText = Vide.source(""),
	Preview = Vide.source(nil :: Model?),
	Building = Vide.source(false),
	Notice = Vide.source(""),
	Resolved = Vide.source(nil :: {UserId: number, Name: string}?),
}

Inserter.Bodies = {
	"Original",
	"R6",
	"R15",
	"OldR15",
} :: {Body}

Inserter.BodyLabels = {
	Original = "Original",
	R6 = "R6",
	R15 = "R15",
	OldR15 = "Old R15",
}

Inserter.Faces = {
	{Id = 0, Name = "Default smile"},
	{Id = 8560971, Name = "Stare"},
	{Id = 7699174, Name = "Silly Fun"},
	{Id = 8329679, Name = "Stitchface"},
	{Id = 15432080, Name = ":3"},
	{Id = 20418658, Name = "Err..."},
	{Id = 21635565, Name = "Heeeeeey..."},
	{Id = 10907549, Name = "Finn McCool"},
}

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

const FaceTextures: {[number]: string} = {}

const function ApplyFace(Model: Model, FaceId: number)
	if FaceId == 0 then
		return
	end

	const Head = Model:FindFirstChild("Head")

	if not Head or not Head:IsA("BasePart") then
		return
	end

	local Texture = FaceTextures[FaceId]

	if not Texture then
		const Ok, Loaded = pcall(InsertService.LoadAsset, InsertService, FaceId)

		if Ok then
			const Decal = Loaded:FindFirstChildWhichIsA("Decal", true)

			Texture = if Decal then Decal.Texture else nil
			Loaded:Destroy()
		end
	end

	if not Texture then
		return
	end

	FaceTextures[FaceId] = Texture

	for _, Child in Head:GetChildren() do
		if Child:IsA("Decal") or Child:IsA("FaceControls") then
			Child:Destroy()
		end
	end

	const Decal = Instance.new("Decal")

	Decal.Name = "face"
	Decal.Face = Enum.NormalId.Front
	Decal.Texture = Texture
	Decal.Parent = Head
end

const function Clean(Model: Model)
	BuildJoints(Model)

	for _, Descendant in Model:GetDescendants() do
		if Descendant:IsA("LuaSourceContainer") then
			Descendant:Destroy()
		end
	end
end

const function Describe(): (HumanoidDescription?, string?)
	const Resolved = Inserter.Resolved()

	if Inserter.DefaultBody() or not Resolved then
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

function Inserter.BuildAccount(): (Model?, string?)
	const Description, Problem = Describe()

	if not Description then
		return nil, Problem
	end

	const Body = Inserter.Body()
	const Face = Inserter.Face()

	if Body == "R15" or Body == "OldR15" then
		Description.Head = 0
		Description.BodyTypeScale = 0
		Description.ProportionScale = 0

		if Body == "OldR15" then
			Description.HeightScale = 1
			Description.WidthScale = 1
			Description.DepthScale = 1
			Description.HeadScale = 1
		end
	end

	if Face ~= 0 then
		Description.Head = 0
	end

	const RigType = if Body == "R6" then Enum.HumanoidRigType.R6 else Enum.HumanoidRigType.R15
	const Ok, Model = pcall(Players.CreateHumanoidModelFromDescriptionAsync, Players, Description, RigType)

	if not Ok then
		return nil, `Could not build the character: {Model}`
	end

	const Resolved = Inserter.Resolved()

	Model.Name = if Inserter.DefaultBody() or not Resolved then `{Inserter.BodyLabels[Body]} dummy` else Resolved.Name
	Clean(Model)
	ApplyFace(Model, Face)

	return Model, nil
end

const function Blank(RigType: Enum.HumanoidRigType, Name: string, Setup: ((HumanoidDescription) -> ())?): () -> Model?
	return function()
		const Description = Instance.new("HumanoidDescription")

		if Setup then
			Setup(Description)
		end

		const Ok, Model = pcall(Players.CreateHumanoidModelFromDescriptionAsync, Players, Description, RigType)

		if not Ok then
			return nil
		end

		Model.Name = Name
		Clean(Model)
		ApplyFace(Model, Inserter.Face())

		return Model
	end
end

const function Template(RigType: Enum.HumanoidRigType, Name: string): () -> Model?
	const Build = Blank(RigType, Name, function(Description: HumanoidDescription)
		Description.Head = 0
	end)

	return function()
		const Model = Build()

		if not Model then
			return nil
		end

		const Colours = {
			Head = Color3.fromRGB(245, 205, 48),
			UpperTorso = Color3.fromRGB(13, 105, 172),
			LowerTorso = Color3.fromRGB(13, 105, 172),
			Torso = Color3.fromRGB(13, 105, 172),
			LeftUpperArm = Color3.fromRGB(196, 40, 28),
			LeftLowerArm = Color3.fromRGB(196, 40, 28),
			LeftHand = Color3.fromRGB(196, 40, 28),
			["Left Arm"] = Color3.fromRGB(196, 40, 28),
			RightUpperArm = Color3.fromRGB(75, 151, 75),
			RightLowerArm = Color3.fromRGB(75, 151, 75),
			RightHand = Color3.fromRGB(75, 151, 75),
			["Right Arm"] = Color3.fromRGB(75, 151, 75),
			LeftUpperLeg = Color3.fromRGB(163, 162, 165),
			LeftLowerLeg = Color3.fromRGB(163, 162, 165),
			LeftFoot = Color3.fromRGB(163, 162, 165),
			["Left Leg"] = Color3.fromRGB(163, 162, 165),
			RightUpperLeg = Color3.fromRGB(99, 95, 98),
			RightLowerLeg = Color3.fromRGB(99, 95, 98),
			RightFoot = Color3.fromRGB(99, 95, 98),
			["Right Leg"] = Color3.fromRGB(99, 95, 98),
		}

		for _, Part in Model:GetChildren() do
			if Part:IsA("BasePart") and Colours[Part.Name] then
				Part.Color = Colours[Part.Name]
			end
		end

		const Colors = Model:FindFirstChildOfClass("BodyColors")

		if Colors then
			Colors:Destroy()
		end

		return Model
	end
end

Inserter.Presets = {
	{Name = "R6", Build = Blank(Enum.HumanoidRigType.R6, "R6")},
	{Name = "R15", Build = Blank(Enum.HumanoidRigType.R15, "R15", function(Description: HumanoidDescription)
		Description.Head = 0
	end)},
	{Name = "Rthro", Build = Blank(Enum.HumanoidRigType.R15, "Rthro", function(Description: HumanoidDescription)
		Description.BodyTypeScale = 1
	end)},
	{Name = "TemplateR6", Build = Template(Enum.HumanoidRigType.R6, "TemplateR6")},
	{Name = "TemplateR15", Build = Template(Enum.HumanoidRigType.R15, "TemplateR15")},
} :: {Preset}

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

		if Own and Target then
			Handle.CFrame = Target.WorldCFrame * Own.CFrame:Inverse()
		end
	end
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