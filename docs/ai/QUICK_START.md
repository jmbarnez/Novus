# AI Behavior Quick Start

## Add a Behavior in 5 Minutes

### Step 1: Define Your Behavior
Edit `src/systems/ai_behaviors.lua`:

```lua
Behaviors.YourBehavior = {}

function Behaviors.YourBehavior.update(eid, ai, pos, vel, turret, design, playerPos, engagementRange, dt)
    -- Your logic here
    local thrustForce = design.thrustForce or 0
    if thrustForce == 0 or not playerPos then return end
    
    -- Example: Chase player
    local dx = playerPos.x - pos.x
    local dy = playerPos.y - pos.y
    local dist = math.sqrt(dx*dx + dy*dy)
    
    if dist > 0 then
        -- Move toward player
        applySteeringAwareThrust(eid, dx/dist, dy/dist, thrustForce, 
                                 design.steeringResponsiveness, ECS.getComponent(eid, "Physics"))
    end
end
```

### Step 2: Register the Behavior
Edit `src/systems/ai.lua`, in `BehaviorHandlers`:

```lua
local BehaviorHandlers = {
    patrol = Behaviors.Patrol.update,
    chase = Behaviors.Chase.update,
    orbit = Behaviors.Orbit.update,
    your_behavior = Behaviors.YourBehavior.update,  -- ← Add here
}
```

### Step 3: Add State Transition
Edit `src/systems/ai.lua`, in `updateAIState()`:

```lua
if playerPos then
    if dsq < detectionRadiusSq then
        if dist < someDistance then
            ai.state = "your_behavior"  -- ← Add here
        end
    end
end
```

Done! ~15 lines total.

---

## Common Patterns

### Pattern 1: Chase
```lua
Behaviors.Chase = {}
function Behaviors.Chase.update(eid, ai, pos, vel, turret, design, playerPos, engagementRange, dt)
    local dx = playerPos.x - pos.x
    local dy = playerPos.y - pos.y
    local dist = math.sqrt(dx*dx + dy*dy)
    
    if dist > 0 then
        applySteeringAwareThrust(eid, dx/dist, dy/dist, design.thrustForce, 
                                 design.steeringResponsiveness, ECS.getComponent(eid, "Physics"))
    end
    
    if turret and dist < engagementRange then
        fireAtTarget(eid, turret, pos, playerPos, engagementRange, dt)
    end
end
```

### Pattern 2: Orbit
```lua
Behaviors.Orbit = {}
function Behaviors.Orbit.update(eid, ai, pos, vel, turret, design, playerPos, engagementRange, dt)
    local dx = playerPos.x - pos.x
    local dy = playerPos.y - pos.y
    local dist = math.sqrt(dx*dx + dy*dy)
    
    if dist > 0 then
        -- Move perpendicular (side to side)
        local perpX = -dy / dist
        local perpY = dx / dist
        applySteeringAwareThrust(eid, perpX, perpY, design.thrustForce * 0.6,
                                 design.steeringResponsiveness, ECS.getComponent(eid, "Physics"))
    end
    
    if turret then
        AiTurretHelper.aimTurretAtTarget(turret, pos, playerPos)
        fireAtTarget(eid, turret, pos, playerPos, engagementRange, dt)
    end
end
```

### Pattern 3: Flee
```lua
Behaviors.Flee = {}
function Behaviors.Flee.update(eid, ai, pos, vel, turret, design, playerPos, engagementRange, dt)
    local dx = playerPos.x - pos.x
    local dy = playerPos.y - pos.y
    local dist = math.sqrt(dx*dx + dy*dy)
    
    if dist > 0 then
        -- Move AWAY from player
        applySteeringAwareThrust(eid, -dx/dist, -dy/dist, design.thrustForce,
                                 design.steeringResponsiveness, ECS.getComponent(eid, "Physics"))
    end
end
```

---

## Available Utilities

### Movement
```lua
applySteeringAwareThrust(eid, dirX, dirY, magnitude, responsiveness, physics)
```
Smooth, physics-aware movement.

### Firing
```lua
fireAtTarget(eid, turret, pos, targetPos, range, dt)
```
Complete firing pipeline.

### Turret Aiming
```lua
AiTurretHelper.aimTurretAtTarget(turret, shooterPos, targetPos)
```

---

## Debugging

Add logging:
```lua
print(string.format("Entity %d: state=%s, dist=%.0f", eid, ai.state, dist))
```

Check state transitions:
```lua
if ai.state ~= oldState then
    print("STATE:", oldState, "->", ai.state)
end
```

---

## Component Reference

### AI Component
```lua
{
    type = "combat" | "mining",
    state = "patrol" | "chase" | "orbit",
    detectionRadius = 1200,
    patrolPoints = {...},
}
```

### Ship Design
```lua
{
    thrustForce = number,
    steeringResponsiveness = number,
    orbitDistance = number,
    wanderRadius = number,
}
```

---

**Start simple, add complexity later!** 🚀
