--!strict
-- Recolours a theme's own model to the colour its unit or prop is given, so one
-- mesh can serve a whole ladder of tiers instead of being imported once per
-- colour. A part opts in with a number attribute `Tint`: 0 takes the colour
-- as-is, and anything above darkens it by that much, for the parts of a model
-- meant to sit a shade under the rest. Parts without the attribute -- a face,
-- a label -- keep the colour they were modelled in.

local Tint = {}

function Tint.apply(model: Model, color: Color3)
	for _, descendant in model:GetDescendants() do
		local amount = descendant:GetAttribute("Tint")
		if descendant:IsA("BasePart") and typeof(amount) == "number" then
			descendant.Color = color:Lerp(Color3.new(0, 0, 0), amount)
		end
	end
end

return Tint
