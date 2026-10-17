-- Checks ServerStorage.Models.Orvoss on disposable clones (Edit mode): scaling and rotating keep every part in place
-- relative to the root, and the prop / face / cloth joints carry their whole assemblies. With POSE = true it leaves a
-- posed copy (cutlass raised, pistol aimed, hat lifted, jaw open, compass closed, tails spread) in
-- Workspace.OrvossPreview.OrvossPoseTest for screenshots; run show_orvoss.lua again to remove it.
local ServerStorage = game:GetService("ServerStorage")
local POSE = true

local src = ServerStorage.Models.Orvoss
local out = {}

local function relMap(m)
	local root = m.PrimaryPart
	local map = {}
	for _, d in ipairs(m:GetDescendants()) do
		if d:IsA("BasePart") then
			map[d] = root.CFrame:ToObjectSpace(d.CFrame)
		end
	end
	return map
end

-- scale to a portrait size and rotate: every part keeps its place relative to the root
do
	local c = src:Clone()
	local ref = relMap(c)
	c.Parent = workspace
	c:PivotTo(CFrame.new(300, 50, 300) * CFrame.Angles(0, math.rad(73), 0))
	c:ScaleTo(0.4)
	local worst = 0
	local root = c.PrimaryPart
	for p, rel in pairs(ref) do
		local now = root.CFrame:ToObjectSpace(p.CFrame)
		local err = (now.Position - rel.Position * 0.4).Magnitude
		worst = math.max(worst, err)
	end
	table.insert(out, ("scale 0.4 + yaw 73: worst offset %.4f"):format(worst))
	c:Destroy()
end

-- the joints move their complete assemblies
local function moved(model, fn, names)
	local ref = relMap(model)
	fn()
	local root = model.PrimaryPart
	local result = {}
	for _, n in ipairs(names) do
		local p = model:FindFirstChild(n, true)
		local ok = p and (root.CFrame:ToObjectSpace(p.CFrame).Position - ref[p].Position).Magnitude > 0.05
		table.insert(result, n .. (ok and " moved" or " STILL"))
	end
	return table.concat(result, ", ")
end

local folder = workspace:FindFirstChild("OrvossPreview") or Instance.new("Folder")
folder.Name = "OrvossPreview"
folder.Parent = workspace
local old = folder:FindFirstChild("OrvossPoseTest")
if old then
	old:Destroy()
end
local c = src:Clone()
c.Name = "OrvossPoseTest"
c.PrimaryPart.Anchored = true
c.Parent = folder
c:PivotTo(CFrame.new(-7, -1.7 + c:GetAttribute("RootHeight"), 26))
local function turn(jointName, cf)
	local m = c:FindFirstChild(jointName, true)
	m.C0 = m.C0 * cf
end
table.insert(out, "RShoulder: " .. moved(c, function()
	turn("RShoulder", CFrame.Angles(math.rad(150), 0, math.rad(-15)))
end, { "BladeEdge", "KnuckleBow", "EpauletteFringe", "Cuff", "Thumb" }))
table.insert(out, "LShoulder: " .. moved(c, function()
	turn("LShoulder", CFrame.Angles(math.rad(80), math.rad(10), 0))
	turn("LWrist", CFrame.Angles(math.rad(-25), 0, 0))
end, { "MuzzleBore", "HammerJaw", "PistolRoot" }))
table.insert(out, "Hat: " .. moved(c, function()
	turn("Hat", CFrame.new(0, 0.9, 0.2) * CFrame.Angles(math.rad(-20), 0, 0))
end, { "BadgeSkull", "HatChain", "Seaweed", "HatbandClasp" }))
table.insert(out, "Jaw: " .. moved(c, function()
	turn("Jaw", CFrame.Angles(math.rad(-22), 0, 0))
end, { "ToothLower", "Ramus" }))
table.insert(out, "CompassLid: " .. moved(c, function()
	turn("CompassLid", CFrame.Angles(math.pi, 0, 0))
end, { "CompassLidRose", "CompassLidCatch" }))
table.insert(out, "Neck: " .. moved(c, function()
	turn("Neck", CFrame.Angles(math.rad(25), 0, 0))
end, { "Eye", "HatWall" }))
for _, m in ipairs(c:GetDescendants()) do
	if m:IsA("Motor6D") and m:GetAttribute("TailIndex") then
		m.C0 = m.C0 * CFrame.Angles(m:GetAttribute("Segment") == 1 and -0.35 or -0.2, 0, 0)
	end
end
-- the cutlass tip against the hat brim, the pistol's hammer against the collar (rough clearances, studs)
local tip = c:FindFirstChild("CutlassRoot", true):FindFirstChild("BladeTip")
local hat = c:FindFirstChild("HatRoot", true)
local hammer = c:FindFirstChild("PistolHammerRoot", true)
local torso = c:FindFirstChild("Torso", true)
table.insert(out, ("raised tip above hat root: %.2f; hammer to neck: %.2f"):format(
	tip.WorldPosition.Y - hat.Position.Y, (hammer.Position - (torso.CFrame * CFrame.new(0, 0.95, 0)).Position).Magnitude))
if not POSE then
	c:Destroy()
end
return table.concat(out, "\n")
