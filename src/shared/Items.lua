-- Outfit items (cosmetics for the player's own character): look only for now, effects come with the spells.
-- Models: ReplicatedStorage.ItemModels.<key> (an Accessory each, built by tools/studio/build_item_<key>.lua).
-- The server (Modules/Outfits) puts the equipped items on the character; ownership + equipped slots are saved
-- (PlayerData `items` / `equipped`).
local Items = {}

-- The three slots, in display order. `hides` = the avatar's own accessory types taken off while an item is worn there;
-- `scaleBy` = the body part whose size scales the item (default R15 size in `baseSize`, along X); `viewTurn` = how the
-- item is turned upright in the panel's 3D views (a hand item is built in the grip frame, which lies on its side).
Items.SLOTS = { "Hand", "Head", "Back" }
Items.SLOT_INFO = {
	Hand = { name = "Hand", hides = {}, scaleBy = "UpperTorso", baseSize = 1.943, viewTurn = CFrame.Angles(math.rad(-90), 0, 0) },
	Head = { name = "Head", hides = { "Hat", "Hair" }, scaleBy = "Head", baseSize = 1.159 },
	Back = { name = "Back", hides = { "Back" }, scaleBy = "UpperTorso", baseSize = 1.943 },
}

Items.Defs = {
	LanternStaff = {
		slot = "Hand",
		name = "Lantern Staff",
		description = "A gravedigger's crook of black wood, hung with a lantern that burns with a captive soul.",
		order = 1,
	},
	GravediggerHood = {
		slot = "Head",
		name = "Gravedigger's Hood",
		description = "Worn, patched and stitched a hundred times. It smells of turned earth.",
		order = 2,
	},
	TatteredCape = {
		slot = "Back",
		name = "Tattered Cape",
		description = "Torn by the gates of the cemetery. A soul sigil is sewn into its back.",
		order = 3,
	},
}

-- Every new player owns these (and wears them until they take them off).
Items.START = { "LanternStaff", "GravediggerHood", "TatteredCape" }

return Items
