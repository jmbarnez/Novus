# WARP.md

This file provides guidance to WARP (warp.dev) when working with code in this repository.

---

## Commands

### Running the Game

**Windows:**
```powershell
RUN.bat
```

**Linux/Mac:**
```bash
love .
```

The game requires Love2D 11.3+ installed. Run script automatically checks common installation paths on Windows.

### Building Distribution Package

**Windows:**
```powershell
BUILD.bat
```

Creates `dist/novus.love` which can be distributed. The script tries 7-Zip first, falls back to PowerShell's Compress-Archive.

### Running Tests

**Windows:**
```powershell
RUN_TESTS.bat
```

**All platforms:**
```bash
lua tests/run_tests.lua
```

**Run a single test:**
```bash
lua tests/run_tests.lua ecs_core_test.lua
```

Tests require `lua` or `luajit` on PATH. The runner adds `./src/` to `package.path` so tests must be run from the repository root.

### Profiling

In-game:
- **F10**: Toggle profiler (press twice to see results)
- **F9**: Debug canvas entities

---

## Architecture

### Entity Component System (ECS)

The entire game is built on a custom ECS architecture centered around `src/ecs.lua`. This is the **foundation** of the codebase.

**Key ECS concepts:**
- **Entities** are numeric IDs (recycled to prevent overflow)
- **Components** are pure data tables stored by type
- **Systems** contain logic and operate on entities with specific components
- **Component Index**: O(n) query performance using indexed component sets

**Critical ECS functions:**
- `ECS.createEntity()` / `ECS.destroyEntity(entityId)`
- `ECS.addComponent(entityId, componentType, componentData)`
- `ECS.getComponent(entityId, componentType)` - retrieve single component
- `ECS.getEntitiesWith({componentTypes})` - query entities (used by all systems)
- `ECS.registerSystem(systemName, system)` - register systems with optional priority

**System Priority:**
Systems execute in priority order (lower = earlier). Set via `system.priority = number`. If not set, defaults to 1000. Systems with equal priority execute in alphabetical order by name.

### Game Loop Flow

1. `main.lua` - Love2D entry point, delegates to:
2. `src/core.lua` - Core game orchestration
3. `src/game_init.lua` - Initialization, entity/system setup
4. ECS systems execute every frame via `ECS.update(dt)` and `ECS.draw()`

**Fixed timestep:** The game uses TimeManager for fixed timestep physics (see `main.lua` lines 87-113). Core game logic runs in fixed steps while rendering interpolates.

### System Execution Order

**Critical: System order matters.** Changing order can break gameplay. Systems are registered in `src/game_init.lua` (lines 98-134).

**Execution phases:**
1. **Physics & Movement** - PhysicsSystem, PhysicsCollisionSystem, BoundarySystem
2. **Input & Camera** - InputSystem, CameraSystem
3. **Combat & AI** - CombatAlertSystem, BehaviorTreeSystem, AISystem, CollisionSystem
4. **Items & Collection** - MagnetSystem
5. **Destruction & Effects** - DestructionSystem, DebrisSystem, TurretSystem, ProjectileSystem
6. **Rendering** - RenderSystem (priority 100), HUDSystem (priority 200), UISystem (priority 300)

See `docs/SYSTEM_DEPENDENCIES.md` for detailed system dependency graph.

### Entity Pools

**Performance-critical pattern:** Frequently created/destroyed entities use pools to avoid GC pressure.

Pools defined in `src/game_init.lua` (lines 22-95):
- `laser_beam` - Max 64 entities (combat/mining lasers)
- `trail_particle` - Max 512 entities (particle trails)

**Creating pooled entities:**
```lua
local EntityPool = require('src.entity_pool')
local laserEntity = EntityPool.acquire("laser_beam")
-- Use entity...
EntityPool.release("laser_beam", laserEntity)
```

**Registering new pools:**
```lua
EntityPool.registerPool(
    "pool_name",
    function() -- factory: create new entity
        local id = ECS.createEntity()
        -- Add components...
        return id
    end,
    function(id) -- reset: prepare for reuse
        -- Clear component data...
    end,
    maxSize
)
```

### Component Serialization

Save/load system uses custom serialization per component type. Register in `src/ecs.lua`:

```lua
ECS.registerComponentSerializer('ComponentType', {
    serialize = function(entityId, componentData)
        -- Return serializable table or nil to skip
    end,
    deserialize = function(entityId, serializedData)
        -- Return restored component data
    end
})
```

### AI System

**Behavior tree-based AI** (not scripted). Modular, data-driven design.

**Key files:**
- `src/systems/behavior_tree_system.lua` - BT execution engine
- `src/systems/ai_behaviors.lua` - Behavior node library
- `src/ai/` - AI configuration and data structures
- `docs/ai/` - Complete AI documentation

**To add new AI behavior:**
1. Add behavior node function to `ai_behaviors.lua`
2. Register in behavior tree system
3. Use in BT definitions (see `docs/ai/QUICK_START.md`)

### Rendering Pipeline

**Multi-layer canvas system:**
1. World entities render to game canvas
2. UI systems render to separate UI canvas
3. Final composition in `RenderSystem`

**Canvas entity** created in `game_init.lua` (line 139). Canvas size uses `DisplayManager.getRenderDimensions()` for proper scaling.

**Shaders:** Managed by `src/shader_manager.lua`. Aurora shader used in start screen. Initialize early (before first use).

### World Coordinate System

- World bounds: -10000 to 10000 (both X and Y)
- World radius: 10000 units
- Screen space vs. world space conversions in camera system

**Lua 5.1 Compatibility:** Love2D uses LuaJIT 2.1 (Lua 5.1 compatible). No Lua 5.2+ syntax allowed (no goto, bitwise ops, etc.).

---

## Development Patterns

### Adding a New System

1. Create `src/systems/new_system.lua`:
```lua
local NewSystem = { priority = 50 } -- optional priority

function NewSystem.update(dt)
    local entities = ECS.getEntitiesWith({"RequiredComponent"})
    for _, entityId in ipairs(entities) do
        local comp = ECS.getComponent(entityId, "RequiredComponent")
        -- System logic...
    end
end

function NewSystem.draw()
    -- Render logic if needed
end

return NewSystem
```

2. Register in `src/game_init.lua` (function `registerSystems`):
```lua
ECS.registerSystem("NewSystem", require('src.systems.new_system'))
```

3. Consider system priority to control execution order

### Adding a New Component

1. Define in `src/components.lua`:
```lua
function Components.NewComponent(param1, param2)
    return {
        param1 = param1,
        param2 = param2,
    }
end
```

2. If component needs save/load, register serializer in `src/ecs.lua`

### Query Patterns

**Find specific entities:**
```lua
-- Single component type
local entities = ECS.getEntitiesWith({"Position"})

-- Multiple components (AND logic)
local entities = ECS.getEntitiesWith({"Position", "Velocity", "Health"})
```

**Performance note:** Query complexity is O(n) where n = entities with rarest component. Component index enables fast queries.

### Common Entity Patterns

**Player-controlled ship:**
- Components: `Position`, `Velocity`, `Physics`, `InputControlled`, `Renderable`, `Hull`, `ControlledBy`
- `ControlledBy` component links ship to pilot entity

**AI enemy ship:**
- Components: `Position`, `Velocity`, `Physics`, `AIControlled`, `Renderable`, `Hull`, `BehaviorTree`
- Behavior tree defines AI decision-making

**Projectile:**
- Components: `Position`, `Velocity`, `Projectile`, `Collidable`
- Managed by ProjectileSystem (lifetime, collision)

---

## Code Conventions

### File Naming
- `snake_case` for file names
- `PascalCase` for module tables

### Module Structure
```lua
local ModuleName = {}

-- Private functions (local)
local function helperFunction()
    -- ...
end

-- Public API
function ModuleName.publicFunction()
    -- ...
end

return ModuleName
```

### Testing
- Tests are plain Lua files in `tests/` directory
- Tests must run from repository root (module paths depend on this)
- Add tests for core logic (ECS, pools, algorithms)
- Keep tests fast and deterministic

---

## Important Notes

### Never Commit Unless Asked
Do not use `git commit` unless the user explicitly requests it. This is critical - users expect to review changes before committing.

### State Management
- **Game state machine:** "start" → "loading" → "game" (see `main.lua` line 15)
- **Save/load:** Uses `src/save_load.lua` and `src/game_state.lua`
- **Snapshot system:** Entire game state serializable via `ECS.serialize()`

### Performance Considerations
- Entity pools prevent GC pressure from frequent creation/destruction
- Quadtree spatial partitioning for collision detection (see `src/systems/quadtree.lua`)
- Component index enables O(n) queries instead of O(nm)
- Fixed timestep physics for deterministic simulation

### Coordinate Systems
Camera transforms between screen space and world space. When adding input handling or UI positioning, ensure correct coordinate space. See `docs/COORDINATE_CONVERSION.md`.

### Common Pitfalls
- **Destroying entities during iteration:** Use deferred destruction or collect IDs first
- **Modifying component arrays during query:** Can break iteration
- **Adding systems without considering order:** Check system dependencies first
- **Forgetting to register systems:** System won't execute if not registered in `game_init.lua`

---

## Resources

- **Core documentation:** `docs/ARCHITECTURE.md`, `docs/SYSTEM_DEPENDENCIES.md`
- **AI system:** `docs/ai/README.md` (comprehensive AI documentation)
- **Performance:** `docs/OPTIMIZATION_SUMMARY.md`
- **Contributing:** `CONTRIBUTING.md`

---

**Repository Type:** Love2D (Lua) game using custom ECS architecture  
**Entry Point:** `main.lua` (must stay in root for Love2D)  
**Core Module:** `src/core.lua` → `src/ecs.lua`  
**Language:** Lua 5.1 (LuaJIT 2.1 via Love2D 11.3+)
