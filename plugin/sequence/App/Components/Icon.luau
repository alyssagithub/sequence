--!strict
const Vide = require(script.Parent.Parent.Parent.Packages.vide)
const Lucide = require(script.Parent.Parent.Parent.Packages["lucide-icons"])
const Settings = require(script.Parent.Parent.Parent.Settings)
const Theme = require(script.Parent.Parent.Theme)

const Create = Vide.create

type Props = {
	Name: string | () -> string,
	Colour: (() -> Color3)?,
	Size: (number | () -> number)?,
	LayoutOrder: number?,
	Visible: (() -> boolean)?,
	Rotation: (() -> number)?,
	Position: UDim2?,
	AnchorPoint: Vector2?,
}

return function(Props: Props)
	const function Asset()
		return Lucide.GetAsset(Vide.read(Props.Name), 48)
	end

	const function Pixels(): number
		return math.round((if Props.Size then Vide.read(Props.Size) else Settings.TextSize()) * 1.15)
	end

	return Create "ImageLabel" {
		Name = "Icon",
		Size = function()
			return UDim2.fromOffset(Pixels(), Pixels())
		end,
		BackgroundTransparency = 1,
		Image = function()
			return Asset().Url
		end,
		ImageRectSize = function()
			return Asset().ImageRectSize
		end,
		ImageRectOffset = function()
			return Asset().ImageRectOffset
		end,
		ImageColor3 = Props.Colour or Theme.Colors.DimText,
		ScaleType = Enum.ScaleType.Fit,
		LayoutOrder = Props.LayoutOrder,
		Rotation = Props.Rotation,
		Visible = Props.Visible,
		Position = Props.Position,
		AnchorPoint = Props.AnchorPoint,
	}
end