# Common AI Behavior Patterns

Ready-to-use behavior implementations.

---

## Pattern 1: Chase Aggressively

```lua
Behaviors.Aggressive = {}

function Behaviors.Aggressive.update(eid, ai, pos, vel, turret, design, playerPos, engagementRange, dt)
    local thrustForce = design.thrustForce or 0
    if thrustForce == 0 or not playerPos then return end
    
    local dx = playerPos.x - pos.x
    local dy = playerPos.y - pos.y
    local dist = math.sqrt(dx*dx + dy*dy)
    
    if dist > 0 then
        -- Charge at full speed
        local physics = ECS.getComponent(eid, "Physics")
        applySteeringAwareThrust(eid, dx/dist, dy/dist, thrustForce * 1.2,
                                 design.steeringResponsiveness, physics)
    end
    
    -- Always fire
    if turret and playerPos then
        AiTurretHelper.aimTurretAtTarget(turret, pos, playerPos)
        fireAtTarget(eid, turret, pos, playerPos, engagementRange, dt)
    end
end
```

---

## Pattern 2: Evasive/Fleeing

```lua
Behaviors.Evasive = {}

function Behaviors.Evasive.update(eid, ai, pos, vel, turret, design, playerPos, engagementRange, dt)
    local thrustForce = design.thrustForce or 0
    if thrustForce == 0 or not playerPos then return end
    
    local dx = playerPos.x - pos.x
    local dy = playerPos.y - pos.y
    local dist = math.sqrt(dx*dx + dy*dy)
    
    if dist > 0 then
        -- Move AWAY from player
        local physics = ECS.getComponent(eid, "Physics")
        applySteeringAwareThrust(eid, -dx/dist, -dy/dist, thrustForce,
                                 design.steeringResponsiveness, physics)
    end
    
    -- Try to kite with distance attacks
    if turret and dist > engagementRange * 0.5 then
        AiTurretHelper.aimTurretAtTarget(turret, pos, playerPos)
        fireAtTarget(eid, turret, pos, playerPos, engagementRange, dt)
    end
end
```

---

## Pattern 3: Defensive (Static Position)

```lua
Behaviors.Defensive = {}

function Behaviors.Defensive.update(eid, ai, pos, vel, turret, design, playerPos, engagementRange, dt)
    local thrustForce = design.thrustForce or 0
    if thrustForce == 0 or not playerPos then return end
    
    -- Stay roughly in place
    local dx = playerPos.x - pos.x
    local dy = playerPos.y - pos.y
    local dist = math.sqrt(dx*dx + dy*dy)
    
    -- If player gets too close, move back slightly
    if dist < 100 then
        local physics = ECS.getComponent(eid, "Physics")
        applySteeringAwareThrust(eid, -dx/dist, -dy/dist, thrustForce * 0.3,
                                 design.steeringResponsiveness, physics)
    end
    
    -- Always fire at player
    if turret then
        AiTurretHelper.aimTurretAtTarget(turret, pos, playerPos)
        fireAtTarget(eid, turret, pos, playerPos, engagementRange, dt)
    end
end
```

---

## Pattern 4: Tactical (Figure-8 Pattern)

```lua
Behaviors.Tactical = {}

function Behaviors.Tactical.update(eid, ai, pos, vel, turret, design, playerPos, engagementRange, dt)
    local thrustForce = design.thrustForce or 0
    if thrustForce == 0 or not playerPos then return end
    
    local dx = playerPos.x - pos.x
    local dy = playerPos.y - pos.y
    local dist = math.sqrt(dx*dx + dy*dy)
    
    if dist <= 0 then return end
    
    -- Calculate figure-8 pattern
    local time = love.timer.getTime()
    local pattern = math.sin(time * 2) * 0.5 + 0.5  -- Oscillates 0-1
    
    -- Perpendicular for orbiting
    local perpX = -dy / dist
    local perpY = dx / dist
    
    -- Mix between perpendicular (orbit) and towards player (advance)
    local moveX = perpX * (1 - pattern) + (dx / dist) * pattern
    local moveY = perpY * (1 - pattern) + (dy / dist) * pattern
    
    local physics = ECS.getComponent(eid, "Physics")
    applySteeringAwareThrust(eid, moveX, moveY, thrustForce * 0.8,
                             design.steeringResponsiveness, physics)
    
    -- Fire continuously
    if turret then
        AiTurretHelper.aimTurretAtTarget(turret, pos, playerPos)
        fireAtTarget(eid, turret, pos, playerPos, engagementRange, dt)
    end
end
```

---

## Pattern 5: Cautious (Keeps Distance)

```lua
Behaviors.Cautious = {}

function Behaviors.Cautious.update(eid, ai, pos, vel, turret, design, playerPos, engagementRange, dt)
    local thrustForce = design.thrustForce or 0
    if thrustForce == 0 or not playerPos then return end
    
    local dx = playerPos.x - pos.x
    local dy = playerPos.y - pos.y
    local dist = math.sqrt(dx*dx + dy*dy)
    
    -- Maintain safe distance
    local safeDistance = engagementRange * 1.2
    
    if dist > safeDistance then
        -- Too far, move closer
        if dist > 0 then
            local physics = ECS.getComponent(eid, "Physics")
            applySteeringAwareThrust(eid, dx/dist, dy/dist, thrustForce * 0.5,
                                     design.steeringResponsiveness, physics)
        end
    elseif dist < safeDistance * 0.8 then
        -- Too close, back away
        if dist > 0 then
            local physics = ECS.getComponent(eid, "Physics")
            applySteeringAwareThrust(eid, -dx/dist, -dy/dist, thrustForce * 0.5,
                                     design.steeringResponsiveness, physics)
        end
    end
    
    -- Fire only when in good position
    if turret and dist > engagementRange * 0.9 and dist < safeDistance then
        fireAtTarget(eid, turret, pos, playerPos, engagementRange, dt)
    end
end
```

---

## Pattern 6: Sniper (Long Range)

```lua
Behaviors.Sniper = {}

function Behaviors.Sniper.update(eid, ai, pos, vel, turret, design, playerPos, engagementRange, dt)
    local thrustForce = design.thrustForce or 0
    if thrustForce == 0 or not playerPos then return end
    
    local dx = playerPos.x - pos.x
    local dy = playerPos.y - pos.y
    local dist = math.sqrt(dx*dx + dy*dy)
    
    -- Stay far away
    local optimalDistance = engagementRange * 1.5
    
    if dist < optimalDistance then
        -- Move back to maintain distance
        if dist > 0 then
            local physics = ECS.getComponent(eid, "Physics")
            applySteeringAwareThrust(eid, -dx/dist, -dy/dist, thrustForce * 0.6,
                                     design.steeringResponsiveness, physics)
        end
    elseif dist > optimalDistance * 1.2 then
        -- Too far, move closer
        if dist > 0 then
            local physics = ECS.getComponent(eid, "Physics")
            applySteeringAwareThrust(eid, dx/dist, dy/dist, thrustForce * 0.3,
                                     design.steeringResponsiveness, physics)
        end
    end
    
    -- Aim and fire
    if turret then
        AiTurretHelper.aimTurretAtTarget(turret, pos, playerPos)
        fireAtTarget(eid, turret, pos, playerPos, engagementRange, dt)
    end
end
```

---

## How to Use

1. **Copy one of these patterns** from above
2. **Customize for your needs** - adjust speeds, distances, firing logic
3. **Add to `src/systems/ai_behaviors.lua`**
4. **Register in behavior handlers** in `src/systems/ai.lua`
5. **Add state transition** for when to use it

---

## Combining Patterns

You can mix elements from different patterns:

```lua
Behaviors.Hybrid = {}

function Behaviors.Hybrid.update(eid, ai, pos, vel, turret, design, playerPos, engagementRange, dt)
    -- Use tactical movement (figure-8)
    -- But cautious firing (only when safe)
    -- And evasive retreat (when low health)
    
    local hull = ECS.getComponent(eid, "Hull")
    local health = hull and (hull.current / hull.max) or 1
    
    if health < 0.3 then
        -- Low health - run!
        -- ... evasive logic ...
    else
        -- Healthy - attack tactically
        -- ... tactical logic ...
    end
end
```

---

## Testing Your Behavior

Add debug output:

```lua
function Behaviors.YourBehavior.update(eid, ai, pos, vel, turret, design, playerPos, engagementRange, dt)
    if math.random() < 0.01 then  -- Print occasionally
        print(string.format(
            "Entity %d: state=%s, health=%.1f%%",
            eid, ai.state, (health.current / health.max) * 100
        ))
    end
    
    -- Your behavior logic...
end
```

---

**Pick a pattern and customize it!** 🚀
