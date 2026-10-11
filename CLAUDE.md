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
- `Workspace.Shops`: `GraveShopkeeper`, `SellShopkeeper`, `UpgradeShopkeeper`, each with a ProximityPrompt.
- `Workspace.HubFloor`, `ServerStorage.Models` (optional `Tombstone` model, optional per-unit models named after the unit key; scripts inside them are stripped on spawn).

## Architecture

**Server** (`src/server/init.server.lua` is a thin bootstrap: player lifecycle + Heartbeat loop). Logic lives in `src/server/Modules/`:
- `Remotes` (creates every remote), `PlotRegistry` (shared `playerPlots`/`getPlot`)
- `Plots` (claiming, grave slots, ascend), `Walls` (HP bar, preview queue, break/reset), `Army` (spawn/recall/placement handlers + unit AI)
- `Rolling` (rarity/unit rolls, pity), `Digging` (DigGrave handler), `Wheel`, `Quests`, `Upgrades`, `GraveShop` (stock rotation), `ShopNpcs` (NPC prompts + sell)
- Dependency order (no cycles): Remotes -> PlotRegistry/Quests/Upgrades/Rolling/Wheel/GraveShop -> Walls -> Army -> Plots. Modules attach their own remote handlers when required.

**Shared data** (`src/shared`, `ReplicatedStorage.Shared`): `Units` (stats, rarity pools, emojis, `getBaseOneIn`), `Graves`, `Rarities`. The server uses these; the client still has its own copies (to be migrated).

**Client** (`src/client/init.client.lua`, ~2300 lines) plus `Modules/`: `GravesDock`, `InventoryPanel`, `ShopPanel`, `QuestsPanel`, `HUD`. The main script still holds game state (gold, gems, inventory, upgrades), unit/grave display tables, the toolbar, the roll animation, ascend/sell/upgrade/wheel panels and the main loop. All UI is built in code (no StarterGui instances).

**Duplicated data:** the client still has its own `UNIT_INFO`, `UNIT_DPS`, `UNIT_ONE_IN`, `GRAVE_DATA` tables duplicating `src/shared`. Keep them in sync until the client is migrated.

## Known issues (do not build on top of these without fixing)

- **No persistence.** No DataStore anywhere. All progress is lost on leave.
- **Client-authoritative economy.** Gold, gems, inventory and upgrades live on the client; the server trusts remotes. Exploitable: `DeployUnit` (client sets damage), `SummonUnit`, `PlaceAtGrave`/`PlaceBest` (client-reported inventory), `SellUnit` (client-reported oneIn), `BuyUpgrade`, `PlayerAscend`, `BuyGraveRequest` (no cost deducted), `AddGold`/`AddGems` (server tells the client what it earned). `SpendGold` has no handler. `/give` debug chat command is open to everyone. Client starts with `gold = 50000` for testing.
- `regenReduction` and `PlagueDoctor.poison` are defined but unused; Goblin poison is hardcoded by unit name.

## Conventions

- Lua/Luau, tabs for indentation, `local function` for helpers, forward-declare locals that are used before they are defined.
- Section headers use `-- ====` banner comments. Keep that style in existing files.
- Player data is keyed by `tostring(player.UserId)`.
- Rarity order: Common, Uncommon, Rare, Cursed, Legendary, Abyssal, Eldritch, Eternal. Grave tiers: Mossy, Stone, Ancient, Cursed, Shadow, Abyssal, Eldritch, Void, Eternal, Celestial (one unlocked per ascension).
- Sell value: `math.floor(oneIn ^ 1.2 * 5)`. DPS: `damage / attackCD`. Grave luck = best-of-N rolls (N = luck / 100), boosted by `luckBoost` upgrade (+10% per level) and the 2x wheel buff.
- `rollBaseRarity` rolls `math.random(1, 10000)` so 0.75% and 0.25% odds work.

## Roblox gotchas

- `Enum.KeyCode.BackQuote` does not exist, and `Tilde` may be intercepted by the console. Prefer a HUD button or `I`.
- Create **all** RemoteEvents/Functions at server startup. Lazily created remotes make client `WaitForChild` time out.
- Forward-declare locals before functions that reference them (e.g. `local wheelPanel`). Numbers and strings are copied by value, so share them across modules via getters or a state table.
- `BodyVelocity`/`BodyGyro` are used for unit movement (deprecated but working).

## Remotes

Created in `init.server.lua`. Names: SummonUnit, WallBreak, DamageHit, DeployUnit, UndeployUnit, PlayerAscend, SelectGrave, PlaceAtGrave, RecallUnit, PlaceBest, PlaceBestResult, GetWallPos (RemoteFunction), WheelSpin, WheelResult, WheelSpinsUpdate, BuyGraveRequest, BuyGraveResult, ShopStockUpdate, QuestUpdate, ClaimQuest, AddGems, AddGold, SpendGold, OpenGrave, OpenSell, OpenUpgrade, SellUnit, BuyUpgrade, UpgradeGranted, DigGrave, RollResult.
