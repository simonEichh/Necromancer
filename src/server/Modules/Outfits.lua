-- Outfit items on the player's character (cosmetics, see shared/Items): every equipped item's Accessory
-- (ReplicatedStorage.ItemModels.<key>) is cloned, scaled to the avatar's body and added to the character, so every
-- player sees it. While a slot is worn the avatar's own accessories of that slot's types are taken off (a hood hides
-- hats and hair, a cape hides back accessories) and put back when the slot is free again.
-- Handles EquipItem(slot, key | nil); ownership and the equipped slots live in PlayerData.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(script.Parent.Remotes)
local PlayerData = require(script.Parent.PlayerData)
local Items = require(ReplicatedStorage.Shared.Items)

local EQUIP_COOLDOWN = 0.25
local MIN_SCALE, MAX_SCALE = 0.6, 1.8

local Outfits = {}
local hiddenBy = {} -- [player] = { [accessory] = true }: the avatar's own accessories taken off for an item
local lastEquip = {} -- [player] = os.clock() of the last EquipItem

-- the avatar accessory types the worn items hide
local function hiddenTypes(profile)
	local set = {}
	for slot, key in pairs(profile.equipped) do
		if key then
			for _, t in ipairs(Items.SLOT_INFO[slot].hides) do
				set[t] = true
			end
		end
	end
	return set
end

local function isHidden(accessory, types)
	return accessory:IsA("Accessory") and not accessory:GetAttribute("OutfitItem") and types[accessory.AccessoryType.Name] == true
end

-- scales an item round its Handle (welds are switched off while the parts move)
local function scaleItem(acc, f)
	if math.abs(f - 1) < 0.02 then
		return
	end
	local handle = acc:FindFirstChild("Handle")
	local origin = handle.CFrame
	local welds = {}
	for _, d in acc:GetDescendants() do
		if d:IsA("WeldConstraint") and d.Enabled then
			d.Enabled = false
			table.insert(welds, d)
		end
	end
	for _, d in acc:GetDescendants() do
		if d:IsA("BasePart") and d ~= handle then
			local rel = origin:ToObjectSpace(d.CFrame)
			d.Size *= f
			d.CFrame = origin * (CFrame.new(rel.Position * f) * rel.Rotation)
		elseif d:IsA("Motor6D") then
			d.C0 = CFrame.new(d.C0.Position * f) * d.C0.Rotation
			d.C1 = CFrame.new(d.C1.Position * f) * d.C1.Rotation
		elseif d:IsA("PointLight") then
			d.Range *= f
		end
	end
	for _, w in welds do
		w.Enabled = true
	end
end

-- moves every part of the item onto the character attachment it snaps to, BEFORE it is added: AddAccessory only
-- moves the Handle, and the WeldConstraints of an accessory outside the workspace do not pull the other parts along
local function placeAt(acc, character)
	local handle = acc:FindFirstChild("Handle")
	local att = handle and handle:FindFirstChildOfClass("Attachment")
	local target = att and character:FindFirstChild(att.Name, true)
	if not (target and target:IsA("Attachment")) then
		return
	end
	local goal = target.WorldCFrame * att.CFrame:Inverse()
	local origin = handle.CFrame
	for _, d in acc:GetDescendants() do
		if d:IsA("BasePart") then
			d.CFrame = goal * origin:ToObjectSpace(d.CFrame)
		end
	end
end

local function scaleFor(character, slot)
	local info = Items.SLOT_INFO[slot]
	local part = character:FindFirstChild(info.scaleBy)
	if not part then
		return 1
	end
	return math.clamp(part.Size.X / info.baseSize, MIN_SCALE, MAX_SCALE)
end

-- Dresses any rig in the given items ({ [slot] = item key }), replacing the items it wore: the Soul Broker's mannequin
-- (OutfitOfTheDay). No avatar accessories to hide there.
function Outfits.dress(model, pieces)
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if not humanoid then return end
	for _, child in model:GetChildren() do
		if child:IsA("Accessory") and child:GetAttribute("OutfitItem") then
			child:Destroy()
		end
	end
	local folder = ReplicatedStorage:FindFirstChild("ItemModels")
	for _, slot in ipairs(Items.SLOTS) do
		local key = pieces[slot]
		local template = key and folder and folder:FindFirstChild(key)
		if template then
			local acc = template:Clone()
			acc:SetAttribute("OutfitItem", key)
			acc:SetAttribute("OutfitSlot", slot)
			scaleItem(acc, scaleFor(model, slot))
			placeAt(acc, model)
			humanoid:AddAccessory(acc)
		end
	end
end

-- Puts the player's equipped items on their character (and takes off the old ones).
function Outfits.apply(player)
	local character = player.Character
	local profile = PlayerData.get(player)
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not (profile and humanoid) then
		return
	end
	local folder = ReplicatedStorage:FindFirstChild("ItemModels")

	for _, child in character:GetChildren() do
		if child:IsA("Accessory") and child:GetAttribute("OutfitItem") then
			child:Destroy()
		end
	end

	-- the avatar's own accessories: put back what is no longer covered, take off what is
	local types = hiddenTypes(profile)
	local hidden = hiddenBy[player] or {}
	hiddenBy[player] = hidden
	for acc in pairs(hidden) do
		if not types[acc.AccessoryType.Name] then
			hidden[acc] = nil
			acc.Parent = character
		end
	end
	for _, child in character:GetChildren() do
		if isHidden(child, types) then
			hidden[child] = true
			child.Parent = nil
		end
	end

	for _, slot in ipairs(Items.SLOTS) do
		local key = profile.equipped[slot]
		local template = key and folder and folder:FindFirstChild(key)
		if template then
			local acc = template:Clone()
			acc:SetAttribute("OutfitItem", key)
			acc:SetAttribute("OutfitSlot", slot)
			scaleItem(acc, scaleFor(character, slot))
			placeAt(acc, character)
			humanoid:AddAccessory(acc)
		elseif key then
			warn("[Outfits] no model for item " .. key .. " (ReplicatedStorage.ItemModels)")
		end
	end
end

local function onCharacter(player, character)
	hiddenBy[player] = {}
	-- the avatar's accessories arrive after the character: take off the covered ones as they come
	character.ChildAdded:Connect(function(child)
		local profile = PlayerData.get(player)
		if profile and isHidden(child, hiddenTypes(profile)) then
			task.defer(function()
				if child.Parent == character then
					hiddenBy[player][child] = true
					child.Parent = nil
				end
			end)
		end
	end)
	-- the profile is loaded from the DataStore on join: wait for it
	local waited = 0
	while not PlayerData.get(player) and waited < 60 and player.Parent do
		waited += task.wait(0.5)
	end
	if player.Character == character then
		Outfits.apply(player)
	end
end

local function onPlayer(player)
	player.CharacterAdded:Connect(function(character)
		onCharacter(player, character)
	end)
	if player.Character then
		task.spawn(onCharacter, player, player.Character)
	end
end

Remotes.EquipItem.OnServerEvent:Connect(function(player, slot, key)
	if type(slot) ~= "string" or (key ~= nil and type(key) ~= "string") then
		return
	end
	local now = os.clock()
	if lastEquip[player] and now - lastEquip[player] < EQUIP_COOLDOWN then
		return
	end
	lastEquip[player] = now
	if PlayerData.equipItem(player, slot, key) then
		Outfits.apply(player)
	end
end)

Players.PlayerAdded:Connect(onPlayer)
for _, player in Players:GetPlayers() do
	onPlayer(player)
end
Players.PlayerRemoving:Connect(function(player)
	hiddenBy[player] = nil
	lastEquip[player] = nil
end)

return Outfits
