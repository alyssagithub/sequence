--!strict
const Vide = require(script.Parent.Parent.Parent.Packages.vide)
const Session = require(script.Parent.Parent.Parent.Editor.Session)
const InsertWindow = require(script.Parent.InsertWindow)

const Create = Vide.create

return function()
	return Create "Frame" {
		Name = "ViewportPage",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,

		Create "TextButton" {
			Name = "Modal",
			Size = UDim2.fromScale(1, 1),
			BackgroundColor3 = Color3.new(),
			BackgroundTransparency = 0.6,
			Text = "",
			AutoButtonColor = false,
			ZIndex = 79,
			Visible = function()
				return Session.Panel() == "Insert"
			end,
			Activated = function()
				Session.Panel(nil)
			end,

			Vide.show(function()
				return Session.Panel() == "Insert"
			end, function()
				return InsertWindow {
					Close = function()
						Session.Panel(nil)
					end,
				}
			end),
		},
	}
end