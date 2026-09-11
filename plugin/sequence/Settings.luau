--!strict
const Vide = require(script.Parent.Packages.vide)
const Config = require(script.Parent.Config)

export type Definition = {
	Key: string,
	Label: string,
	Detail: string,
	Group: string,
	Default: any,
	Minimum: number?,
	Maximum: number?,
	Options: {string}?,
}

const Definitions: {Definition} = {
	{
		Key = "TextSize",
		Label = "Text size",
		Detail = "",
		Group = "Appearance",
		Default = Config.TextSize,
		Minimum = 10,
		Maximum = 22,
	},
}

const Sources: {[string]: any} = {}
local CurrentPlugin: Plugin

const Settings = {
	Definitions = Definitions,
}

function Settings.Load(PluginObject: Plugin)
	CurrentPlugin = PluginObject

	for _, Definition in Definitions do
		const Stored = CurrentPlugin:GetSetting(`{Config.Name}_{Definition.Key}`)

		Sources[Definition.Key] = Vide.source(if Stored == nil then Definition.Default else Stored)
	end
end

function Settings.TextSize(): number
	return Sources.TextSize()
end

function Settings.SmallText(): number
	return math.min(Sources.TextSize(), math.max(11, Sources.TextSize() - 2))
end

function Settings.Get(Key: string): any
	return assert(Sources[Key], `No setting named {Key}`)
end

function Settings.Set(Key: string, Value: any)
	Sources[Key](Value)
	CurrentPlugin:SetSetting(`{Config.Name}_{Key}`, Value)
end

function Settings.Reset()
	for _, Definition in Definitions do
		Settings.Set(Definition.Key, Definition.Default)
	end
end

return Settings