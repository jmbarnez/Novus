# Enemy Loot System Implementation

## What Was Set Up

### 1. Created Scrap Item
**File**: `src/items/scrap.lua`

- New item type for salvaging from destroyed ships
- Gray metallic appearance with highlights
- Stackable and tradeable (value: 2)
- Automatically loaded by the item loader system

### 2. Modified Destruction System
**File**: `src/systems/destruction.lua`

#### Changes:
- **Parameterized `spawnItemDrops(x, y, entityType)`** - Now accepts entity type parameter
- **Added entity type detection** in update loop:
  - Asteroids: Calls with `"asteroid"` type
  - Ships: Calls with `"ship"` type
- **Implemented loot tables**:
  - **Asteroids**: Drop 2-4 items (stone or iron)
  - **Ships**: Drop 1-2 scrap (guaranteed)

#### How It Works:
```lua
-- When a ship is destroyed:
DestructionSystem.spawnItemDrops(x, y, "ship")
  ├─ Selects 1-2 scrap items
  ├─ Spawns them in random directions
  ├─ Gives them outward velocity
  └─ Creates them as collectible entities

-- When an asteroid is destroyed:
DestructionSystem.spawnItemDrops(x, y, "asteroid")
  ├─ Selects 2-4 items (stone/iron mix)
  ├─ Same spawning behavior as ships
  └─ Different loot table
```

## How It Integrates

### Item Collection (No Changes Needed)
The existing `PickupSystem` in `src/systems/magnet.lua` automatically collects ship loot:
- Finds any entity with Item + Position components
- Doesn't care if items came from asteroids or ships
- Pulls them toward the player's drone
- Adds to player's cargo

## Testing the System

To see enemy loot in action:
1. Destroy an AI-controlled enemy ship
2. Watch 1-2 scrap items drop and spread out
3. Your drone's magnet automatically pulls them in
4. Scrap items appear in your inventory

## Extensibility

To add different loot for specific enemy types in the future:

```lua
-- In src/ship_loader.lua, you can add loot definitions:
design.loot = {
    dropCount = {min = 1, max = 3},
    items = {"scrap", "combat_laser_module"}
}

-- Then modify spawnItemDrops() to check for ship-specific loot tables
```

The system is already modular and ready for expansion!
