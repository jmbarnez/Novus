# Item Drop System Analysis

## Current Architecture

Yes, the item drop system is modular. The current implementation uses a clean, component-based architecture that can be easily extended to handle enemy loot drops from destroyed ships.

---

## Current Item Drop Flow

### Asteroid Destruction → Item Spawn

**File**: `src/systems/destruction.lua`

When an asteroid is destroyed:

- Selects random items (stone, iron)
- Randomizes drop locations around the destruction point
- Creates item entities with Position, Velocity, Physics, Item, Stack, and Renderable components
- Returns item entity IDs

### Item Collection → Player Cargo

**File**: `src/systems/magnet.lua`

- Finds all items in world with Item + Position components
- For each item:
  - Applies magnet pull effect (if within range)
  - Collects item when close enough
  - Adds to pilot's cargo and updates count
  - Shows notification and plays sound
  - Calls itemDef.onCollect() hook if defined
  - Destroys the collected item entity

---

## Why It's Modular

1. **Generic Item Entity Creation**
   - `spawnItemDrops()` doesn't care about source (asteroid vs ship)
   - Uses generic Item, Stack, Velocity, Physics components
   - Any entity can drop items

2. **Decoupled Collection System**
   - `PickupSystem` just looks for entities with Item + Position components
   - Doesn't know or care what created the items
   - Works on any item, anywhere

3. **Component-Based Architecture**
   - Items are defined by their components
   - New item types just add more rows to ItemDefs
   - No hardcoding of item sources

---

## How to Handle Enemy Ship Loot

### Option 1: Reuse `DestructionSystem.spawnItemDrops()` (RECOMMENDED)

Modify `destruction.lua` to check for both asteroids and ships:

```lua
function DestructionSystem.update(dt)
    -- Check if entity is a ship
    local asteroid = ECS.getComponent(entityId, "Asteroid")
    local hull = ECS.getComponent(entityId, "Hull")
    local aiController = ECS.getComponent(entityId, "AIController")
    
    if asteroid and pos then
        DestructionSystem.spawnItemDrops(pos.x, pos.y, "asteroid")
    elseif (hull or aiController) and pos then
        DestructionSystem.spawnItemDrops(pos.x, pos.y, "ship")
    end
end
```

### Option 2: Create a Generic Loot Table System

```lua
-- Create LootSystem.lua
local LootSystem = {
    tables = {
        asteroid = {
            {item = "stone", weight = 0.6},
            {item = "iron", weight = 0.4}
        },
        enemy_scout = {
            {item = "iron", weight = 0.5},
            {item = "combat_laser_module", weight = 0.3},
            {item = "basic_cannon_module", weight = 0.2}
        },
        enemy_combat = {
            {item = "combat_laser_module", weight = 0.7},
            {item = "mining_laser_module", weight = 0.2},
            {item = "iron", weight = 0.1}
        }
    }
}
```

---

## Recommended Implementation Steps

### Step 1: Add to Destruction System

Modify `src/systems/destruction.lua` to handle both asteroid and ship destruction.

### Step 2: Parameterize `spawnItemDrops()`

Update the function to accept an entityType parameter:

```lua
function DestructionSystem.spawnItemDrops(x, y, entityType)
    entityType = entityType or "asteroid"
    
    local itemTypes
    if entityType == "asteroid" then
        itemTypes = {"stone", "iron"}
    elseif entityType == "ship" then
        itemTypes = {"iron", "combat_laser_module", "basic_cannon_module"}
    end
    
    -- Rest of implementation unchanged
end
```

### Step 3: Define Enemy Loot Tables

Add loot definitions to ship designs:

```lua
-- In src/ship_designs/red_scout.lua
design.loot = {
    dropCount = {min = 1, max = 3},
    items = {"iron", "combat_laser_module"}
}
```

---

## Key Files Involved

| File | Purpose | Modularity |
|------|---------|-----------|
| `src/systems/destruction.lua` | Entity destruction & loot spawning | Already generic |
| `src/systems/magnet.lua` | Item collection & cargo | Already generic |
| `src/items/item_loader.lua` | Item definitions | Easily extensible |
| `src/ship_loader.lua` | Ship creation | Can add loot tables |
| `src/components.lua` | Entity components | Already sufficient |

---

## Verdict

YES - The system is already modular.

To support enemy loot drops:

1. Add a check for destroyed ships in `DestructionSystem.update()`
2. Call the existing `spawnItemDrops()` function with different parameters
3. Define what items each enemy type drops
4. The existing `PickupSystem` automatically collects them

No major refactoring needed - just extend existing systems with parameterization.
