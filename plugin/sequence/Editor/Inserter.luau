--!strict
const Players = game:GetService("Players")
const StudioService = game:GetService("StudioService")
const ChangeHistoryService = game:GetService("ChangeHistoryService")
const Selection = game:GetService("Selection")
const Rig = require(script.Parent.Rig)

const Inserter = {}

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

const function Place(Model: Model, Name: string): Model
	Model.Name = Name
	BuildJoints(Model)

	for _, Descendant in Model:GetDescendants() do
		if Descendant:IsA("LuaSourceContainer") then
			Descendant:Destroy()
		end
	end

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
		Humanoid.DisplayName = Name
	end

	Selection:Set({Model})
	ChangeHistoryService:SetWaypoint(`Insert {Name}`)

	return Model
end

const function Blank(RigType: Enum.HumanoidRigType, Name: string): (Model?, string?)
	const Ok, Model = pcall(Players.CreateHumanoidModelFromDescriptionAsync, Players, Instance.new("HumanoidDescription"), RigType)

	if not Ok then
		return nil, `Could not build the rig: {Model}`
	end

	return Place(Model, Name), nil
end

function Inserter.R6(): (Model?, string?)
	return Blank(Enum.HumanoidRigType.R6, "R6 dummy")
end

function Inserter.R15(): (Model?, string?)
	return Blank(Enum.HumanoidRigType.R15, "R15 dummy")
end

function Inserter.Rthro(): (Model?, string?)
	const Description = Instance.new("HumanoidDescription")

	Description.BodyTypeScale = 1
	Description.ProportionScale = 0

	const Ok, Model = pcall(Players.CreateHumanoidModelFromDescriptionAsync, Players, Description, Enum.HumanoidRigType.R15)

	if not Ok then
		return nil, `Could not build the rig: {Model}`
	end

	return Place(Model, "Rthro dummy"), nil
end

function Inserter.User(UserId: number, Name: string?): (Model?, string?)
	const Ok, Model = pcall(Players.CreateHumanoidModelFromUserIdAsync, Players, UserId)

	if not Ok then
		return nil, `Could not load that avatar: {Model}`
	end

	local Label = Name

	if not Label then
		const Found, Fetched = pcall(Players.GetNameFromUserIdAsync, Players, UserId)

		Label = if Found then Fetched else `User {UserId}`
	end

	return Place(Model, Label :: string), nil
end

function Inserter.Me(): (Model?, string?)
	const UserId = StudioService:GetUserId()

	if UserId == 0 then
		return nil, "Studio is not signed in, so there is no avatar to insert"
	end

	return Inserter.User(UserId, nil)
end

function Inserter.ByName(Typed: string): (Model?, string?)
	const Trimmed = Typed:match("^%s*(.-)%s*$") or ""

	if Trimmed == "" then
		return nil, "Type a username or user id first"
	end

	const AsNumber = tonumber(Trimmed)

	if AsNumber then
		return Inserter.User(AsNumber, nil)
	end

	const Ok, UserId = pcall(Players.GetUserIdFromNameAsync, Players, Trimmed)

	if not Ok then
		return nil, `No user called {Trimmed}`
	end

	return Inserter.User(UserId, Trimmed)
end

return Inserter