# Necromancer

Roblox idle/gacha game ("Necro Buddies"). Players dig graves to roll undead units, place them on grave slots on their plot, and the units walk down a lane and break a wall for gold. Ascending (rebirth) resets the wall and unlocks the next grave tier and one more grave slot. Design inspiration and the wish list live in `Notes.txt` (a "Spin a Baddie"-style game).

## Workflow

- Code is synced with **Rojo** (`default.project.json`, `rojo serve`). The repo in `src/` is the source of truth for all scripts. Never edit scripts directly in Studio, and don't use the Studio MCP to write script source that Rojo owns.
- The world (Plots, Shops, HubFloor, models in ServerStorage) lives only in the Studio place file. Use the Roblox Studio MCP to inspect or change it.
- Rojo mapping: `src/server` -> `ServerScriptService.Server`, `src/client` -> `StarterPlayerScripts.Client`, `src/shared` -> `ReplicatedStorage.Shared`. `init.server.lua` / `init.client.lua` make the folder itself the script, so sibling files become its children (`script.Modules.X`).
- Test with the Studio MCP: start play mode, read console output, then stop. Check `get_console_output` for errors after every change.
- Commit one feature per commit, with a clear message. Only commit when asked.

## World (Studio, not in repo)

- `Workspace.Plots.Plot1..Plot8`: each has `Base`, `WallOrigin`, `PlayerSpawn`, `GraveSpot1..10`. Plots are claimed per player. Lane direction is derived from WallOrigin vs PlayerSpawn X.
  - Layout (all 8 plots identical, relative to plot centre `(CX=-280, CZ_i = 229.5 - (i-1)*52.9)`): `Base` 48 (X, lane direction) x 2 x 40 (Z), floor top at Y=-1.7; `WallOrigin` on the Base's west edge (X=CX-24) where the lane starts; `PlayerSpawn` flush pad at CX-8; `GraveSpot1..10` are invisible markers in 2 columns (X=CX+10 slots 1-5, CX+18 slots 6-10) x 5 rows (Z=CZ-14,-7,0,7,14), spaced for the 6x5.7 tombstone model. The hub strip's west edge touches the plots' east edge. Keep this grid if you add or edit plots.
  - Units and tombstones use collision groups (`Collision` module) so units walk through the tombstones.
- `Workspace.Shops`: `GraveShopkeeper`, `SellShopkeeper`, `UpgradeShopkeeper`, each with a ProximityPrompt.
- `Workspace.HubFloor`, `ServerStorage.Models` (optional `Tombstone` model, optional per-unit models named after the unit key; scripts inside them are stripped on spawn).

## Architecture

**Server** (`src/server/init.server.lua` is a thin bootstrap: player lifecycle + Heartbeat loop). Logic lives in `src/server/Modules/`:
- `Remotes` (creates every remote), `PlotRegistry` (shared `playerPlots`/`getPlot`)
- **`PlayerData`** (authoritative gold/gems/inventory/graves/upgrades/ascension per player, with `changed` -> coalesced `DataSync` snapshot to the client), **`Persistence`** (DataStore load/save/autosave/BindToClose), `Inventory` (SellUnit/SwapInventory/RequestData handlers)
- `Plots` (claiming, grave slots, ascend), `Walls` (HP bar, preview queue, break/reset), `Army` (spawn/recall/placement handlers + unit AI)
- `Rolling` (rarity/unit rolls, pity), `Digging` (DigGrave handler), `Wheel`, `Quests`, `Upgrades` (purchases), `GraveShop` (stock rotation + purchases), `ShopNpcs` (NPC prompts)
- Dependency order (no cycles): Remotes -> PlayerData -> PlotRegistry/Quests/Upgrades/Rolling/Wheel/GraveShop -> Walls -> Army -> Plots/Persistence. Modules attach their own remote handlers when required.

**Shared data** (`src/shared`, `ReplicatedStorage.Shared`): `Units` (stats, rarity pools, emojis, `getBaseOneIn`), `Graves`, `Rarities`, `Economy` (costs, sell value, multipliers, caps). Both server and client read these; add or change a unit/grave there only. The only client-only grave data is the image/emoji/color in `GameData.GRAVE_UI`.

**Client** (`src/client/init.client.lua` is a bootstrap that requires the modules in UI draw order). All UI is built in code (no StarterGui instances), parented to the one ScreenGui from `Modules/Gui`. `src/client/Modules/`:
- Foundations: `State` (client mirror of the server's data: `State.gold`, `State.inventory`, ... written ONLY by `Sync`), `Sync` (applies `DataSync` snapshots, refreshes the UI, `hold()`/`release()` to delay updates until a roll/wheel reveal, `onApplied(fn)` for panels), `GameData` (unit/grave display tables derived from `src/shared`), `Format`, `Gui`
- Older panels with `Module.init(screenGui, ctx)`: `GravesDock`, `InventoryPanel`, `ShopPanel`, `QuestsPanel`, `HUD`
- Newer modules that build their UI when required: `Toolbar` (hotbar, tooltip, carried block, `refresh`), `Placement` (Place Best, SelectGrave -> PlaceAtGrave), `GraveRolling` (roll animation, `openGrave`), `Effects` (wall-break/damage effects, `showBigText`), `AscendPanel`, `SellPanel`, `UpgradePanel`, `WheelPanel`
- UI created later draws on top of earlier UI, so keep the require order in `init.client.lua`.

## Models and rigs

- Models live in `ServerStorage.Models` (place file, not the repo): `Tombstone` (grave slot model) and one model per unit key (`Skelly`, ...). `spawnUnit` clones the model named after the unit; units without a model fall back to a coloured block.
- We are replacing Creator Store models with our own low-poly ones, built by scripts in `tools/studio/` (run in Edit mode via the Studio MCP `execute_luau`; they keep the old model as `<Name>_Old` until approved). Done: `Tombstone`, `Skelly`.
- **Procedural rigs** (attribute `Rig = "Procedural"`): parts + Motor6D joints named Root/Waist/Neck/Jaw/LShoulder/RShoulder/LElbow/RElbow/LHip/RHip/LKnee/RKnee, front = -Z, right = +X, feet on y = 0, root part `HumanoidRootPart` at `RootHeight`, attributes `RootHeight` and `Height`. No Humanoid and no uploaded Animation assets. The server only sets attributes (`State` walk/idle, `AttackCount`, `Speed`, `AttackCD`) and tags the model `ProceduralUnit`; each client animates the joints in `Modules/UnitAnimator`. The rig is scaled to `def.size.X / 2 * 0.9`.
- Tombstone model: origin = centre of a thin base plate on the floor, front faces +X, footprint 6 x 5.7 (must fit the 7-stud row pitch / 8-stud column pitch of the grave grid).
- The unit's invisible collision block uses a BodyGyro with full torque so it can never tip over.

## Server authority and saving

- **The client never changes gold, gems, inventory, graves, upgrades or ascension.** It sends requests (BuyGraveRequest, DigGrave, PlaceAtGrave(invSlot, graveSlot), PlaceBest, SellUnit(invSlot), SwapInventory, BuyUpgrade, PlayerAscend, WheelSpin, ClaimQuest); the server validates cost/ownership/limits and applies them via `PlayerData`. Any new feature that gives or takes currency/units must go through `PlayerData` on the server.
- Results come back as a full `DataSync` snapshot. Inventory is sent as a list of `{slot, unitType, oneIn}` (sparse arrays don't survive remotes).
- Saved per player (`Persistence`, DataStore `PlayerData_v1`, key `player_<UserId>`): gold, gems, ascension, inventory, owned graves, upgrades, pity, units placed on graves, wheel spins, quest progress. Autosaves every 60s, on leave and on shutdown. If a load fails the player gets defaults and is **never saved** that session (`profile.loadFailed`) so stored data can't be overwritten.
- DataStore does nothing in Studio unless "Enable Studio Access to API Services" is on (Game Settings > Security); without it every load fails and nothing is saved.
- Testing saves in Studio: the Stop button ends the session before the leave-save finishes, so only the 60s autosave (or `Player:Kick()` from a server `execute_luau`) is reliable there. Save logs `💾 saved data for <name>`.
- New players start with `START_GOLD = 50000` in `PlayerData` (a testing value; Notes.txt wants 300).
- `/give <Unit>` debug chat command only works in Studio.

## Known issues

- No session locking: a player in two servers at once could overwrite their own data.
- Not saved: luck buff timer, shop stock rotation, current wall layer/progress.
- `regenReduction` and `PlagueDoctor.poison` are defined but unused; Goblin poison is hardcoded by unit name.

## Conventions

- Lua/Luau, tabs for indentation, `local function` for helpers, forward-declare locals that are used before they are defined.
- Section headers use `-- ====` banner comments. Keep that style in existing files.
- Player data is keyed by `tostring(player.UserId)`.
- Rarity order: Common, Uncommon, Rare, Cursed, Legendary, Abyssal, Eldritch, Eternal. Grave tiers: Mossy, Stone, Ancient, Cursed, Shadow, Abyssal, Eldritch, Void, Eternal, Celestial (one unlocked per ascension).
- Sell value: `Economy.sellValue(oneIn)` = `math.floor(oneIn ^ 1.2 * 5)`, times `1 + coinBoost * 0.5`. Wall gold = `floor(1000 * layer)` times `(1 + rebirths) + coinBoost * 0.5`. DPS: `damage / attackCD`. Grave luck = best-of-N rolls (N = luck / 100), boosted by `luckBoost` upgrade (+10% per level) and the 2x wheel buff.
- `rollBaseRarity` rolls `math.random(1, 10000)` so 0.75% and 0.25% odds work.

## Roblox gotchas

- `Enum.KeyCode.BackQuote` does not exist, and `Tilde` may be intercepted by the console. Prefer a HUD button or `I`.
- Create **all** RemoteEvents/Functions at server startup. Lazily created remotes make client `WaitForChild` time out.
- Forward-declare locals before functions that reference them (e.g. `local wheelPanel`). Numbers and strings are copied by value, so share them across modules via getters or a state table.
- `BodyVelocity`/`BodyGyro` are used for unit movement (deprecated but working).

## Remotes

Created in `Modules/Remotes.lua` (a list; add new names there). Client -> server: BuyGraveRequest, BuyUpgrade, ClaimQuest, DigGrave, PlaceAtGrave, PlaceBest, PlayerAscend, RequestData, SellUnit, SwapInventory, WheelSpin. Server -> client: AddGold (sell banner only), BuyGraveResult, DamageHit, DataSync, DigRejected, Notice, OpenGrave/OpenSell/OpenUpgrade, QuestUpdate, RollResult, SelectGrave, ShopStockUpdate, WallBreak, WheelResult, WheelSpinsUpdate; RemoteFunction GetWallPos.
