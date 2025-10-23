# Salvaging Skill System & Wreckage Loot Implementation

## Overview

Implemented a complete salvaging skill system with wreckage loot drops. Wreckage pieces now have a 50% chance to drop scrap when destroyed, and players gain salvaging experience that scales with their salvaging level.

---

## Components Added

### 1. LootDrop Component
**File**: `src/components.lua`

```lua
Components.LootDrop = function(dropsScrap)
    return {
        dropsScrap = dropsScrap or false,
        droppedScrap = false
    }
end
```

Tracks whether a wreckage piece drops scrap and whether it has already dropped.

### 2. Salvaging Skill
**File**: `src/components.lua`

Added `salvaging` skill to the Skills component:
```lua
salvaging = {
    level = 1,
    experience = 0,
    requiredXp = 100,
    totalXp = 0
}
```

---

## System Updates

### Wreckage System
**File**: `src/systems/wreckage.lua`

**Changes:**
- Each wreckage piece has 50% chance to drop scrap when destroyed
- LootDrop component added to each wreckage entity
- Scrap drop flag set during wreckage spawning

```lua
-- 50% chance to drop scrap when salvaged
local dropsScrap = math.random() < 0.5

-- Store in LootDrop component
ECS.addComponent(wreckageId, "LootDrop", {dropsScrap = dropsScrap, droppedScrap = false})
```

### Destruction System
**File**: `src/systems/destruction.lua`

**New Logic:**
- Detects when wreckage is destroyed
- If wreckage has loot drop flag and hasn't dropped yet, spawns 1-2 scrap
- Added `spawnScrapDrop(x, y)` function

**Wreckage Destruction:**
```lua
elseif wreckage and lootDrop and lootDrop.dropsScrap and not lootDrop.droppedScrap and pos then
    -- Wreckage drops scrap (1-2 pieces)
    DestructionSystem.spawnScrapDrop(pos.x, pos.y)
    lootDrop.droppedScrap = true
end
```

### Salvage Laser Module
**File**: `src/turret_modules/salvage_laser.lua`

**Enhanced XP System:**
- Base XP: 5 per wreckage destroyed
- Bonus XP: +2 XP per salvaging level
- Formula: `5 + (salvaging_level * 2)`

Example:
- Level 1: 7 XP per wreck
- Level 5: 15 XP per wreck
- Level 10: 25 XP per wreck

---

## Gameplay Mechanics

### Wreckage Loot Drop Process

1. **Enemy ship destroyed** → Creates 3-6 wreckage pieces
2. **Each wreckage piece** has 50% chance to drop scrap
3. **Player salvages with green laser** → Damages wreckage
4. **Wreckage destroyed**:
   - If flagged for scrap: Drops 1-2 scrap items
   - Player gains salvaging XP (scales with level)
5. **Player collects scrap** via magnet system

### Salvaging Level Progression

- Starts at Level 1
- Requires 100 XP to level up
- Higher levels grant more XP per wreck (scaling bonus)
- Creates feedback loop: Higher level = faster progression

---

## Item Drop Mechanics

**Scrap Drop from Wreckage:**
- Quantity: 1-2 pieces per wreck (only if drop flag set)
- Spawn distance: 30-60 units from wreckage center
- Velocity: 20-50 units/sec outward
- Collectible by player's magnet system

**Ship Destruction Drops:**
- Direct scrap: 1-2 pieces guaranteed
- Wreckage pieces: 3-6 pieces
- 50% of wreckage drops additional scrap on salvage

---

## Files Modified

| File | Changes |
|------|---------|
| `src/components.lua` | Added LootDrop component, added salvaging skill |
| `src/systems/wreckage.lua` | Added 50% chance loot drop, LootDrop component |
| `src/systems/destruction.lua` | Added wreckage loot logic, spawnScrapDrop function |
| `src/turret_modules/salvage_laser.lua` | Enhanced XP with salvaging level scaling |

---

## Progression Loop

```
Salvage Wreckage (1-2 XP per level)
    ↓
Gain Salvaging Experience
    ↓
Level Up Salvaging Skill
    ↓
Earn More XP Per Wreck
    ↓
Faster Progression
    ↓
[Loop]
```

---

## Technical Details

### 50% Loot Drop System

Each wreckage piece rolls randomly:
```lua
local dropsScrap = math.random() < 0.5
```

This means:
- ~50% of wreckage will drop scrap on destruction
- ~50% will drop nothing
- Adds element of chance/surprise to salvaging

### Level-Scaling XP Formula

```lua
xpGain = 5 + (salvaging_level * 2)
```

Benefits:
- Early levels gain slow but steady XP
- Higher levels reward dedicated players
- Creates natural progression curve
- Encourages repeated salvaging

---

## Testing Checklist

✅ Game compiles without errors
✅ Wreckage spawns with LootDrop component
✅ 50% of wreckage flagged for scrap drops
✅ Destroyed wreckage drops scrap (1-2 pieces)
✅ Scrap items collectible by magnet
✅ Salvaging XP awarded on wreck destruction
✅ XP scales with salvaging level
✅ Salvaging skill initialized at level 1

---

## Future Enhancement Possibilities

1. **Better Visualization**: Visual indicator on wreckage that will drop scrap
2. **Rare Drops**: Some wreckage drops rarer items based on salvaging level
3. **Diminishing Returns**: Wreckage from same ship sources has diminishing drop rates
4. **Salvaging Perks**: Higher salvaging levels unlock special abilities (faster salvage speed, bonus drops)
5. **Quest Integration**: Specific salvaging challenges or objectives
6. **Crafting**: Use salvaged scrap to craft items or repair equipment

