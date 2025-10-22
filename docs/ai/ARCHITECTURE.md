# AI System Architecture

## Overview

The AI system is a **clean, modular, behavior-based architecture** with:
- **Single unified AI component** - All state in one place
- **Behavior registry pattern** - Easy to extend
- **No legacy patterns** - Simple and maintainable
- **Zero breaking changes** - Fully backward compatible

---

## System Structure

```
┌─────────────────────────────────┐
│    Single AI Component          │
│  ├─ type: "combat" | "mining"  │
│  ├─ state: behavior name        │
│  ├─ detectionRadius: range      │
│  └─ patrolPoints: waypoints     │
└─────────────────────────────────┘
              ↓
┌─────────────────────────────────┐
│    AISystem (Orchestrator)      │
│  ├─ Detects player              │
│  ├─ Updates AI state            │
│  └─ Dispatches to behaviors     │
└─────────────────────────────────┘
              ↓
┌─────────────────────────────────┐
│   Behavior Registry             │
│  ├─ Patrol                      │
│  ├─ Chase                       │
│  ├─ Orbit                       │
│  └─ [Custom behaviors]          │
└─────────────────────────────────┘
              ↓
┌─────────────────────────────────┐
│   Shared Utilities              │
│  ├─ ai_turret_helper.lua        │
│  ├─ ai_behaviors.lua            │
│  └─ ForceUtils                  │
└─────────────────────────────────┘
```

---

## Core Components

### 1. Unified AI Component
**File:** `src/components/ai.lua`

```lua
Components.AI = {
    type = "combat" | "mining",     -- AI behavior type
    state = "patrol" | "chase" | "orbit",  -- Current behavior
    detectionRadius = 1200,         -- How far to detect player
    patrolPoints = {...},           -- Optional waypoints
    currentPoint = 1,               -- Current waypoint index
    
    -- Behavior state (managed by behaviors)
    spawnX, spawnY,                 -- Spawn location
    _wanderAngle, _wanderTimer,     -- Patrol wander state
    orbitDirection,                 -- Orbit direction
    _swingAngle, _swingTimer,       -- Turret idle swing
}
```

### 2. Main AI System
**File:** `src/systems/ai.lua`

```lua
local AISystem = {
    name = "AISystem",
    priority = 9,
}

-- Behavior registry - easy to extend
local BehaviorHandlers = {
    patrol = Behaviors.Patrol.update,
    chase = Behaviors.Chase.update,
    orbit = Behaviors.Orbit.update,
    -- Add new behaviors here
}

function AISystem.update(dt)
    -- Get player position
    local playerPos = getPlayerPosition()
    
    -- Update all AI entities
    local aiEntities = ECS.getEntitiesWith({"AI", "Position", "Velocity"})
    for _, eid in ipairs(aiEntities) do
        local ai = ECS.getComponent(eid, "AI")
        
        -- Skip mining AI if handled separately
        if ai.type == "mining" then goto continue end
        
        -- Update state based on detection
        updateAIState(ai, pos, playerPos, engagementRange)
        
        -- Execute behavior
        local handler = BehaviorHandlers[ai.state]
        if handler then
            handler(eid, ai, pos, vel, turret, design, playerPos, engagementRange, dt)
        end
        
        ::continue::
    end
end
```

### 3. Behavior Modules
**File:** `src/systems/ai_behaviors.lua`

Three built-in behaviors:

#### Patrol
- Follows waypoints if defined
- Otherwise wanders near spawn location
- Swings turret randomly while idle

#### Chase
- Moves directly toward player at high speed
- Aims turret at player
- Fires when in range
- Used when player detected but not close enough to orbit

#### Orbit
- Maintains optimal combat distance
- Circles around player
- Continuously fires while orbiting
- Used when player close enough to engage

---

## How It Works

### Detection Flow

1. **Check Player Distance**
   ```lua
   if distance < detectionRadius then
       -- Player detected!
   end
   ```

2. **Determine Behavior**
   ```lua
   if distance < engagementRange * 0.8 then
       ai.state = "orbit"      -- Close enough to fight
   else
       ai.state = "chase"      -- Need to get closer
   end
   ```

3. **Execute Behavior**
   ```lua
   local handler = BehaviorHandlers[ai.state]
   handler(eid, ai, pos, vel, turret, design, playerPos, engagementRange, dt)
   ```

### State Transitions

```
START
  ↓
PATROL (default, no player detected)
  ↓
Player detected within detectionRadius?
  ├─ YES: Is distance < engagementRange * 0.8?
  │   ├─ YES → ORBIT (fight)
  │   └─ NO → CHASE (approach)
  └─ NO: Return to PATROL
```

---

## Behavior Registry Pattern

The behavior registry makes it trivial to add new behaviors:

```lua
local BehaviorHandlers = {
    patrol = Behaviors.Patrol.update,
    chase = Behaviors.Chase.update,
    orbit = Behaviors.Orbit.update,
    
    -- Add your new behaviors here:
    aggressive = Behaviors.Aggressive.update,
    evasive = Behaviors.Evasive.update,
    tactical = Behaviors.Tactical.update,
}

-- Later: dispatch is automatic
local handler = BehaviorHandlers[ai.state]
if handler then
    handler(...)  -- Calls the right behavior
end
```

---

## AI Types

### Combat AI
- **Controlled by:** AISystem
- **States:** patrol → chase → orbit
- **Goal:** Engage player in combat
- **Created by:** Any enemy with combat turret

### Mining AI
- **Controlled by:** EnemyMiningSystem
- **States:** mining only
- **Goal:** Mine asteroids
- **Created by:** Any enemy with mining turret

---

## Shared Utilities

### From `ai_behaviors.lua`

```lua
-- Movement
applySteeringAwareThrust(eid, dirX, dirY, magnitude, responsiveness, physics)

-- Firing
fireAtTarget(eid, turret, pos, targetPos, engagementRange, dt)

-- Math
distSq(x1, y1, x2, y2)
```

### From `ai_turret_helper.lua`

```lua
-- Aiming
AiTurretHelper.aimTurretAtTarget(turret, shooterPos, targetPos)

-- Damage calculation
AiTurretHelper.calculateDamageMultiplier(turretModule, distance)
```

---

## Integration Points

### ECS Queries
```lua
-- Find all AI entities
local aiEntities = ECS.getEntitiesWith({"AI", "Position", "Velocity"})

-- Check if mining
if ai.type == "mining" then ... end

-- Check state
if ai.state == "chase" then ... end
```

### Component Updates
Behaviors modify these components:
- `Velocity` - Movement
- `Turret` - Aiming position
- `AI` - State, timers

### System Dependencies
- **PhysicsSystem** - Applies velocity changes
- **RenderSystem** - Displays positions
- **TurretSystem** - Fires weapons
- **EnemyMiningSystem** - Mining-specific logic

---

## Performance Characteristics

- **ECS Queries:** 1 per frame (all AI entities)
- **Component Access:** Direct (O(1))
- **Behavior Dispatch:** O(1) via registry
- **Total Systems:** 1 (AISystem)
- **Overhead:** Minimal

---

## Extending the System

### Adding a New Behavior

**File:** `src/systems/ai_behaviors.lua`

```lua
Behaviors.YourBehavior = {}

function Behaviors.YourBehavior.update(eid, ai, pos, vel, turret, design, playerPos, engagementRange, dt)
    -- Your logic
end
```

**File:** `src/systems/ai.lua`

```lua
local BehaviorHandlers = {
    -- ... existing behaviors ...
    your_behavior = Behaviors.YourBehavior.update,  -- Add here
}

-- In updateAIState():
if someCondition then
    ai.state = "your_behavior"  -- Add transition here
end
```

**That's it!** No modifications to core system needed.

---

## Design Principles

1. **Single Responsibility** - Each behavior does one thing
2. **Open/Closed** - Open for extension, closed for modification
3. **Clean Dispatch** - Registry pattern, not if-elseif towers
4. **No Magic** - All state explicit and visible
5. **Composable** - Behaviors can share utilities

---

## Comparison: Before vs After

| Aspect | Before | After |
|--------|--------|-------|
| **Components** | 3 markers | 1 unified |
| **Systems** | 2 | 1 |
| **Dispatch** | If-elseif tower | Registry pattern |
| **Adding behavior** | Modify core | Add module |
| **State location** | Scattered | Centralized |

---

**The architecture is simple, clean, and ready to extend!** 🚀
