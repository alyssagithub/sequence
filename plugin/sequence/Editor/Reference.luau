--!strict
const StudioService = game:GetService("StudioService")
const AssetService = game:GetService("AssetService")
const Vide = require(script.Parent.Parent.Packages.vide)
const Session = require(script.Parent.Session)

export type Item = {
	Kind: "Image" | "Frames" | "Video",
	Name: string,
	Content: Content?,
	Frames: {Content}?,
	VideoId: string?,
	FrameRate: number,
	Offset: number,
	Editables: {EditableImage}?,
}

const Reference = {
	Items = Vide.source({} :: {Item}),
	Chosen = Vide.source(1),
	InWorld = Vide.source(false),
	Opacity = Vide.source(0),
}

const function Add(Item: Item)
	const Items = table.clone(Reference.Items())

	table.insert(Items, Item)
	Reference.Items(Items)
	Reference.Chosen(#Items)
end

function Reference.Current(): Item?
	return Reference.Items()[Reference.Chosen()]
end

function Reference.Remove(Index: number)
	const Items = table.clone(Reference.Items())
	const Removed = table.remove(Items, Index)

	if Removed and Removed.Editables then
		for _, Editable in Removed.Editables do
			Editable:Destroy()
		end
	end

	Reference.Items(Items)
	Reference.Chosen(math.clamp(Reference.Chosen(), 1, math.max(#Items, 1)))
end

function Reference.Update(Index: number, Changes: {[string]: any})
	const Items = table.clone(Reference.Items())
	const Item = Items[Index]

	if not Item then
		return
	end

	const Edited = table.clone(Item)

	for Key, Value in Changes do
		(Edited :: any)[Key] = Value
	end

	Items[Index] = Edited
	Reference.Items(Items)
end

function Reference.AddAssetImage(AssetId: number)
	Add({
		Kind = "Image",
		Name = `Image {AssetId}`,
		Content = Content.fromAssetId(AssetId),
		FrameRate = Session.FrameRate(),
		Offset = 0,
	})
end

function Reference.AddVideo(AssetId: number)
	Add({
		Kind = "Video",
		Name = `Video {AssetId}`,
		VideoId = `rbxassetid://{AssetId}`,
		FrameRate = Session.FrameRate(),
		Offset = 0,
	})
end

const function Editable(File: File): EditableImage?
	const Ok, Made = pcall(AssetService.CreateEditableImageAsync, AssetService, Content.fromUri(File:GetTemporaryId()))

	return if Ok then Made else nil
end

function Reference.ImportImage(): string?
	const Ok, File = pcall(StudioService.PromptImportFile, StudioService, {"png", "jpg", "jpeg", "bmp", "tga"})

	if not Ok or not File then
		return if Ok then nil else `Could not open the file picker: {File}`
	end

	const Made = Editable(File :: File)

	if not Made then
		return `Could not read {(File :: File).Name} as an image`
	end

	Add({
		Kind = "Image",
		Name = (File :: File).Name,
		Content = Content.fromObject(Made),
		FrameRate = Session.FrameRate(),
		Offset = 0,
		Editables = {Made},
	})

	return nil
end

function Reference.ImportFrames(): string?
	const Ok, Files = pcall(StudioService.PromptImportFiles, StudioService, {"png", "jpg", "jpeg", "bmp", "tga"})

	if not Ok or not Files or #Files == 0 then
		return if Ok then nil else `Could not open the file picker: {Files}`
	end

	table.sort(Files, function(A: File, B: File)
		return A.Name < B.Name
	end)

	const Frames = {}
	const Editables = {}

	for _, File in Files do
		const Made = Editable(File)

		if Made then
			table.insert(Frames, Content.fromObject(Made))
			table.insert(Editables, Made)
		end
	end

	if #Frames == 0 then
		return "None of those files could be read as images"
	end

	Add({
		Kind = "Frames",
		Name = `{#Frames} frames from {Files[1].Name}`,
		Frames = Frames,
		FrameRate = Session.FrameRate(),
		Offset = 0,
		Editables = Editables,
	})

	return nil
end

function Reference.FrameAt(Item: Item, Time: number): Content?
	if Item.Kind == "Image" then
		return Item.Content
	end

	if Item.Kind ~= "Frames" or not Item.Frames then
		return nil
	end

	const Index = math.floor((Time - Item.Offset) * Item.FrameRate) + 1

	return Item.Frames[math.clamp(Index, 1, #Item.Frames)]
end

function Reference.Destroy()
	for _, Item in Reference.Items() do
		if Item.Editables then
			for _, Editable in Item.Editables do
				Editable:Destroy()
			end
		end
	end

	Reference.Items({})
end

return Reference