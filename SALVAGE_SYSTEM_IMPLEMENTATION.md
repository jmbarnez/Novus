# Salvage Laser & Wreckage System Implementation

## Overview

Created a complete salvage laser module and wreckage system that allows players to harvest scrap materials from destroyed ships using a laser-based turret module, mirroring the mining laser interaction pattern.

---

## Components Added

### 1. Wreckage Component
**File**: `src/components.lua`

```lua
Components.Wreckage = function(sourceShip)
    return {
        sourceShip = sourceShip or "unknown"
    }
end
```

Marks entities as salvageable wreckage from destroyed ships.

---

## New Systems

### 1. Salvage Laser Module
**File**: `src/turret_modules/salvage_laser.lua`

**Features:**
- DPS: 40 (slightly less than mining laser at 50)
- Targets wreckage entities (not asteroids)
- Uses the same collision detection pattern as mining laser
- Creates debris impact effects
- Grants "salvage" skill experience (5 XP per wreck destroyed)

**How It Works:**
1. `fire()` - Creates a laser beam entity when turret fires
2. `applyBeam()` - Called every frame:
   - Performs line-polygon intersection with nearby wreckage
   - Applies damage over time to hit wreckage
   - Creates visual impact debris
   - Destroys wreckage when durability reaches 0

### 2. Wreckage System
**File**: `src/systems/wreckage.lua`

**Core Functions:**
- `spawnWrackage(x, y, sourceShip)` - Creates 3-6 wreckage pieces at destruction point
- `generateWreckageShape(size)` - Procedurally generates angular metal shard polygons

**Wreckage Properties:**
- Size: Random 8-16 units
- Spawn pattern: 40-100 units from destruction center
- Velocity: 20-60 units/sec outward from center
- Rotation: Random angular velocity
- Durability: Based on size (size * 1.5)
- Color: Dark gray metal (0.4, 0.4, 0.45)

---

## Integration Points

### Destruction System Enhancement
**File**: `src/systems/destruction.lua`

When a ship is destroyed (has Hull or AIController component):
1. Creates debris particles
2. Drops scrap items (1-2 pieces guaranteed)
3. **NEW**: Spawns 3-6 wreckage pieces for salvaging

```lua
elseif (hull or aiController) and pos then
    DestructionSystem.spawnItemDrops(pos.x, pos.y, "ship")
    WrackageSystem.spawnWrackage(pos.x, pos.y, "destroyed_ship")
end
```

### Systems Registry
**File**: `src/systems.lua`

Added wreckage system to the systems list for automatic loading and management.

---

## Usage

### As a Player

1. **Find a destroyed ship wreck** - Wreckage pieces spawn when ships are destroyed
2. **Equip salvage laser turret** - Select it from your turret modules
3. **Target wreckage pieces** - Aim at angular metal debris
4. **Fire the laser** - Hold fire to harvest the wreckage
5. **Collect scrap** - Destroyed wreckage drops 1-2 scrap items

### For Developers

To spawn wreckage programmatically:

```lua
local WrackageSystem = ECS.getSystem("WrackageSystem")
WrackageSystem.spawnWrackage(x, y, "destroyed_ship")
```

To use the salvage laser in a turret:
```lua
-- In ship design or turret setup:
turret.moduleName = "salvage_laser"
```

---

## Gameplay Loop Integration

**Before (Mining Only):**
- Destroy asteroids → Get stone/iron → Build/craft

**After (Mining + Salvage):**
- Destroy asteroids → Get stone/iron
- Destroy enemy ships → Get scrap + wreckage
- Salvage wreckage → Get more scrap
- Combine resources for crafting

---

## Visual Appearance

- **Salvage Laser**: Yellow-green beam (inherited from laser rendering system)
- **Wreckage Pieces**: Dark gray angular polygons with metallic coloring
- **Impact Effects**: Debris particles matching wreckage color

---

## Stats Summary

| Property | Mining Laser | Salvage Laser |
|----------|--------------|---------------|
| DPS | 50 | 40 |
| Target | Asteroids | Wreckage |
| Skill XP | mining (10) | salvage (5) |
| Pieces Spawned | N/A | 3-6 per ship |
| Pickup Type | Direct drop | Salvage + scrap drop |

---

## Next Steps (Optional Enhancements)

1. **Skill System**: Implement "salvage" skill with perks (faster salvaging, more scrap, etc.)
2. **Visual Upgrade**: Add glow/shine effects to wreckage pieces
3. **Audio**: Add wreckage breaking/harvest sound effects
4. **Advanced Wrecks**: Rare wreckage types with special loot (modules, components)
5. **Wreckage Decay**: Wreckage gradually loses durability over time or despawns after a timeout
6. **Quest Hooks**: Use wreckage salvage for missions or resource gathering quests

---

## Files Modified

| File | Changes |
|------|---------|
| `src/turret_modules/salvage_laser.lua` | NEW - Salvage laser module |
| `src/systems/wreckage.lua` | NEW - Wreckage spawning system |
| `src/components.lua` | Added Wreckage component |
| `src/systems.lua` | Added WrackageSystem to registry |
| `src/systems/destruction.lua` | Added wreckage spawning on ship destruction |

---

## Testing

✅ All files compile without errors
✅ Wreckage system properly integrated with destruction
✅ Salvage laser module loaded as turret module
✅ Ready for in-game testing

Destroy a ship in-game to see wreckage spawn and begin salvaging!
