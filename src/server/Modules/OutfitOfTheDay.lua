-- The Outfit of the Day (shared OutfitSets; Design.md "The Soul Broker"): one outfit set a day for everyone.
-- BuyOutfit(what, day): what = "Set" (every missing piece at OutfitSets.SET_DISCOUNT) or a slot ("Head" / "Back" /
-- "Hand", that one piece); `day` is the day the client saw, so an outfit that changed under the click is refused.
-- Gems go through PlayerData.spendGems, pieces through PlayerData.grantItem (saved like every outfit item).
-- The mannequin: a plain R15 figure on the Soul Broker stall's pedestal (part "MannequinSpot", its LookVector = where it
-- faces) wearing today's set (Outfits.dress), redressed when the day turns. It is a model with the attribute Ware =
-- "Outfit" and a "Hit" part with a ClickDetector: the client (BrokerWares) outlines it and opens the shop's Outfit tab.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(script.Parent.Remotes)
local PlayerData = require(script.Parent.PlayerData)
local Outfits = require(script.Parent.Outfits)
local Items = require(ReplicatedStorage.Shared.Items)
local OutfitSets = require(ReplicatedStorage.Shared.OutfitSets)

local lastRequest = {} -- [UserId] = os.clock()
Players.PlayerRemoving:Connect(function(player)
	lastRequest[player.UserId] = nil
end)

-- ============================================================
-- Buying
-- ============================================================
Remotes.BuyOutfit.OnServerEvent:Connect(function(player, what, day)
	local profile = PlayerData.get(player)
	if not profile or type(what) ~= "string" or type(day) ~= "number" then return end
	local now = os.clock()
	if lastRequest[player.UserId] and now - lastRequest[player.UserId] < 0.3 then return end
	lastRequest[player.UserId] = now

	local serverNow = workspace:GetServerTimeNow()
	local _, set = OutfitSets.today(serverNow)
	if not set or day ~= OutfitSets.day(serverNow) then
		Remotes.Notice:FireClient(player, "Today's outfit has changed. Look again.")
		return
	end
	local keys, price = {}, nil
	if what == "Set" then
		price = OutfitSets.setPrice(set, profile.items)
		for _, slot in ipairs(Items.SLOTS) do
			if not profile.items[set.pieces[slot]] then table.insert(keys, set.pieces[slot]) end
		end
	elseif Items.SLOT_INFO[what] then
		local key = set.pieces[what]
		if not profile.items[key] then
			keys = { key }
			price = OutfitSets.piecePrice(key)
		end
	end
	if not price or #keys == 0 then
		Remotes.Notice:FireClient(player, "You already own that.")
		return
	end
	if not PlayerData.spendGems(player, price) then
		Remotes.Notice:FireClient(player, "Not enough Gems (" .. price .. " needed).")
		return
	end
	for _, key in ipairs(keys) do
		PlayerData.grantItem(player, key)
	end
	Remotes.Notice:FireClient(player, (#keys > 1 and set.name or Items.Defs[keys[1]].name) .. " is yours. Wear it in Outfits.")
end)

-- ============================================================
-- The mannequin
-- ============================================================
local MANNEQUIN_COLOR = Color3.fromRGB(70, 66, 84) -- dark stone, so the outfit stands out
local mannequin, dressedKey

local function spot()
	local decor = workspace:FindFirstChild("HubDecor")
	local stall = decor and decor:FindFirstChild("Stall_SoulBroker")
	return stall, stall and stall:FindFirstChild("MannequinSpot", true)
end

local function build(stall, at)
	local ok, rig = pcall(function()
		return Players:CreateHumanoidModelFromDescription(Instance.new("HumanoidDescription"), Enum.HumanoidRigType.R15)
	end)
	if not ok or not rig then
		warn("[OutfitOfTheDay] could not build the mannequin: " .. tostring(rig))
		return nil
	end
	rig.Name = "OutfitMannequin"
	rig:SetAttribute("Ware", "Outfit")
	local humanoid = rig:FindFirstChildOfClass("Humanoid")
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	for _, d in ipairs(rig:GetDescendants()) do
		if d:IsA("BasePart") then
			d.Color = MANNEQUIN_COLOR
			d.Material = Enum.Material.Slate
			d.CanCollide = false
			d.CastShadow = false
		elseif d:IsA("Decal") or d:IsA("Shirt") or d:IsA("Pants") or d:IsA("ShirtGraphic") or d:IsA("BodyColors") then
			d:Destroy()
		end
	end
	local root = rig:FindFirstChild("HumanoidRootPart")
	root.Anchored = true
	-- stand its feet on the spot, facing where the spot faces
	rig:PivotTo(at.CFrame)
	local box, size = rig:GetBoundingBox()
	rig:PivotTo(rig:GetPivot() + Vector3.new(0, at.Position.Y - (box.Position.Y - size.Y / 2), 0))
	-- the click box
	local hit = Instance.new("Part")
	hit.Name = "Hit"
	hit.Anchored = true
	hit.CanCollide = false
	hit.Transparency = 1
	hit.Size = Vector3.new(3, size.Y + 0.6, 2.5)
	hit.CFrame = at.CFrame * CFrame.new(0, (size.Y + 0.6) / 2, 0)
	hit.Parent = rig
	local cd = Instance.new("ClickDetector")
	cd.MaxActivationDistance = 40
	cd.Parent = hit
	rig.Parent = stall
	return rig
end

local function refresh()
	local stall, at = spot()
	if not (stall and at) then return end
	if not (mannequin and mannequin.Parent == stall) then
		mannequin = build(stall, at)
		dressedKey = nil
	end
	if not mannequin then return end
	local key, set = OutfitSets.today(workspace:GetServerTimeNow())
	if key ~= dressedKey then
		dressedKey = key
		Outfits.dress(mannequin, set and set.pieces or {})
	end
end

task.spawn(function()
	while true do
		refresh()
		task.wait(20)
	end
end)

return {}
