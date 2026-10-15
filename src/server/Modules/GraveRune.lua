-- The rune on a grave slot's tombstone (the carved cross and the epitaph lines of ServerStorage.Models.Tombstone):
-- dark stone while the grave is empty, glowing in the unit's rarity colour (with a soft light) while a unit stands on
-- it. Replaces the old "Empty" text. Graves built from the plain fallback parts have no rune and are left alone.
local GraveRune = {}

local RUNE_PARTS = { CrossV = true, CrossH = true, EpitaphLine1 = true, EpitaphLine2 = true }

-- finds the rune parts of a slot's tombstone model and remembers how they look unlit
function GraveRune.attach(slot)
	local model = slot.stone
	if not (model and model:IsA("Model")) then
		return
	end
	local parts = {}
	for _, p in ipairs(model:GetDescendants()) do
		if p:IsA("BasePart") and RUNE_PARTS[p.Name] then
			table.insert(parts, { part = p, color = p.Color, material = p.Material })
		end
	end
	if #parts == 0 then
		return
	end
	local headstone = model:FindFirstChild("Headstone", true) or parts[1].part
	local light = Instance.new("PointLight")
	light.Range = 9
	light.Brightness = 1.4
	light.Shadows = false
	light.Enabled = false
	light.Parent = headstone
	slot.rune = { parts = parts, light = light }
end

-- color = the rarity colour to light it in, or nil to put it out
function GraveRune.set(slot, color)
	local rune = slot.rune
	if not rune then
		return
	end
	for _, r in ipairs(rune.parts) do
		r.part.Color = color or r.color
		r.part.Material = color and Enum.Material.Neon or r.material
	end
	rune.light.Enabled = color ~= nil
	if color then
		rune.light.Color = color
	end
end

return GraveRune
