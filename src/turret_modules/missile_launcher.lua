-- Missile Launcher Turret Module
-- Fires homing missiles that lock onto targeted enemies, or fly straight if no target is locked

local ECS = require('src.ecs')
local Components = require('src.components')

local MissileLauncher = {
    name = "missile_launcher",
    displayName = "Missile Launcher",
    MISSILE_SPEED = 50,
    MISSILE_RADIUS = 2,
    MISSILE_COLOR = {1, 0.3, 0.1, 1}, -- Orange-red
    MISSILE_ACCELERATION = 800, -- Acceleration in pixels per second squared
    MISSILE_MAX_SPEED = 800, -- Maximum speed after acceleration
    HOMING_TURN_RATE = 8.0, -- Radians per second turning rate (increased from 4.0 for better tracking)
    COOLDOWN = 3, -- Time between shots in seconds
    DPS = 25, -- Damage per missile
    LIFETIME = 5, -- Maximum flight time in seconds before self-destruct
    design = {
        shape = "custom",
        size = 18,
        color = {1, 0.3, 0.1, 1}
    },
    draw = function(self, x, y)
        local size = self.design.size
        love.graphics.setColor(0.2, 0.2, 0.2, 1)
        love.graphics.rectangle("fill", x - size/3, y - size/2, size * 0.65, size, 4, 4)
        love.graphics.setColor(1, 0.3, 0.1, 1)
        love.graphics.circle("fill", x, y - size/2.5, size/3)
        love.graphics.setColor(0.8, 0.8, 0.8, 1)
        love.graphics.rectangle("fill", x - size/4, y + size/3, size/2, size/6, 2, 2)
        love.graphics.setColor(0.9, 0.2, 0.1, 0.8)
        love.graphics.circle("fill", x, y - size/2.5, size/4.5)
    end
}

function MissileLauncher.fire(ownerId, startX, startY, endX, endY)
    -- Calculate initial direction
    local dx = endX - startX
    local dy = endY - startY
    local dist = math.sqrt(dx * dx + dy * dy)
    if dist == 0 then return end
    local dirX = dx / dist
    local dirY = dy / dist

    -- Offset spawn position so missile starts well away from the ship
    local spawnX = startX + dirX * 30
    local spawnY = startY + dirY * 30

    -- Get the targeting info from the pilot (not the drone)
    -- The ownerId is the drone/ship, which has a ControlledBy component pointing to the pilot
    local controlledBy = ECS.getComponent(ownerId, "ControlledBy")
    local pilotId = controlledBy and controlledBy.pilotId
    local inputComp = pilotId and ECS.getComponent(pilotId, "InputControlled")
    local targetedEnemy = inputComp and inputComp.targetedEnemy
    -- Also check if player is currently targeting (not yet locked)
    local targetingTarget = inputComp and inputComp.targetingTarget
    
    -- Use locked target if available, otherwise use target being aimed at
    local preferredTarget = targetedEnemy or targetingTarget
    
    -- Create missile entity
    local missileId = ECS.createEntity()
    ECS.addComponent(missileId, "Position", Components.Position(spawnX, spawnY))
    ECS.addComponent(missileId, "Velocity", Components.Velocity(dirX * MissileLauncher.MISSILE_SPEED, dirY * MissileLauncher.MISSILE_SPEED))

    -- Add acceleration component for missile boost
    ECS.addComponent(missileId, "Acceleration", {
        ax = dirX * MissileLauncher.MISSILE_ACCELERATION,
        ay = dirY * MissileLauncher.MISSILE_ACCELERATION,
        maxSpeed = MissileLauncher.MISSILE_MAX_SPEED
    })

    -- Create missile shape (elongated with pointed nose and fins)
    local missileLength = MissileLauncher.MISSILE_RADIUS * 3  -- Missile is 3 times longer than radius
    local missileWidth = MissileLauncher.MISSILE_RADIUS * 0.6  -- Slightly narrower than the collision radius
    -- Define missile shape facing +X so rotation can line up with velocity
    local missileBaseVertices = {
        {x = 0, y = -missileLength},        -- Nose tip (up in base space)
        {x = missileWidth * 0.5, y = -missileLength * 0.7},  -- Nose shoulder right
        {x = missileWidth * 0.5, y = missileLength * 0.3},   -- Body right
        {x = missileWidth * 0.8, y = missileLength * 0.8},   -- Fin right
        {x = 0, y = missileLength},         -- Tail center (down)
        {x = -missileWidth * 0.8, y = missileLength * 0.8},  -- Fin left
        {x = -missileWidth * 0.5, y = missileLength * 0.3},  -- Body left
        {x = -missileWidth * 0.5, y = -missileLength * 0.7}  -- Nose shoulder left
    }
    local missileVertices = {}
    for _, vertex in ipairs(missileBaseVertices) do
        -- Rotate 90 degrees counterclockwise so nose points forward along +X at zero rotation
        table.insert(missileVertices, {x = -vertex.y, y = vertex.x})
    end

    -- Calculate initial rotation to face the direction of travel
    local initialRotation = math.atan2(dirY, dirX)

    ECS.addComponent(missileId, "PolygonShape", Components.PolygonShape(missileVertices, initialRotation))
    ECS.addComponent(missileId, "Renderable", Components.Renderable("polygon", nil, initialRotation, MissileLauncher.MISSILE_RADIUS, MissileLauncher.MISSILE_COLOR))
    ECS.addComponent(missileId, "Collidable", Components.Collidable(MissileLauncher.MISSILE_RADIUS))
    -- Give missile physics with low friction for sustained flight
    ECS.addComponent(missileId, "Physics", Components.Physics(1.0, 1.5, 1.0)) -- no friction, light mass, rotation damping
    -- Missile durability - survives longer than basic projectiles
    ECS.addComponent(missileId, "Durability", Components.Durability(3, 3)) -- Takes 3 hits to destroy
    -- Mark as projectile
    ECS.addComponent(missileId, "Projectile", {ownerId = ownerId, damage = MissileLauncher.DPS, brittle = false, isMissile = true})
    
    -- Add homing component if target locked - use the player's locked/targeting target
    local homingTarget = preferredTarget
    
    if homingTarget then
        ECS.addComponent(missileId, "MissileHoming", {
            targetId = homingTarget,
            turnRate = MissileLauncher.HOMING_TURN_RATE,
            maxRange = MissileLauncher.RANGE,
            acceleration = MissileLauncher.MISSILE_ACCELERATION
        })
    end
    
    -- Add age tracking for lifecycle management
    ECS.addComponent(missileId, "MissileAge", {
        maxAge = MissileLauncher.LIFETIME,
        age = 0
    })
    
    -- Add trail emitter for missile exhaust effect
    ECS.addComponent(missileId, "TrailEmitter", Components.TrailEmitter(
        30,  -- emitRate: 30 particles per second (fairly frequent)
        50,  -- maxParticles: limit per missile
        0.3, -- particleLife: 0.3 seconds (short-lived trail)
        0.3, -- spreadAngle: 0.3 radians spread
        0.2, -- speedMultiplier: 0.2 (slower particles for exhaust effect)
        {1.0, 0.5, 0.1} -- trailColor: orange-red exhaust color
    ))
    
    -- Add shatter effect for explosion when missile expires
    ECS.addComponent(missileId, "ShatterEffect", {
        numPieces = 12, -- Number of debris pieces
        color = {1.0, 0.3, 0.1, 1} -- Orange-red explosion color
    })
end

-- Update homing behavior for a missile
function MissileLauncher.updateHoming(missileId, dt)
    local homing = ECS.getComponent(missileId, "MissileHoming")
    if not homing then return end
    
    local position = ECS.getComponent(missileId, "Position")
    local velocity = ECS.getComponent(missileId, "Velocity")
    local polygonShape = ECS.getComponent(missileId, "PolygonShape")
    local acceleration = ECS.getComponent(missileId, "Acceleration")
    
    if not (position and velocity and polygonShape) then return end
    
    -- Check if target still exists and is valid
    local targetPos = nil
    if homing.targetId then
        targetPos = ECS.getComponent(homing.targetId, "Position")
        -- If target no longer exists or is destroyed, stop homing
        if not targetPos then
            ECS.removeComponent(missileId, "MissileHoming")
            return
        end
    end
    
    if targetPos then
        -- Calculate direction to target
        local dx = targetPos.x - position.x
        local dy = targetPos.y - position.y
        local distToTarget = math.sqrt(dx * dx + dy * dy)
        
        -- No range limit - missiles will home indefinitely until target is destroyed or missile expires
        
        -- Normalize target direction
        local targetDirX = dx / distToTarget
        local targetDirY = dy / distToTarget
        
        -- Get current velocity direction
        local speed = math.sqrt(velocity.vx * velocity.vx + velocity.vy * velocity.vy)
        if speed > 0 then
            local currentDirX = velocity.vx / speed
            local currentDirY = velocity.vy / speed
            
            -- Calculate angle difference
            local currentAngle = math.atan2(currentDirY, currentDirX)
            local targetAngle = math.atan2(targetDirY, targetDirX)
            local angleDiff = targetAngle - currentAngle
            
            -- Normalize angle difference to [-pi, pi]
            while angleDiff > math.pi do angleDiff = angleDiff - 2 * math.pi end
            while angleDiff < -math.pi do angleDiff = angleDiff + 2 * math.pi end
            
            -- Limit turning rate
            local maxTurn = homing.turnRate * dt
            if angleDiff > maxTurn then angleDiff = maxTurn end
            if angleDiff < -maxTurn then angleDiff = -maxTurn end
            
            -- Apply rotation to current direction
            local newAngle = currentAngle + angleDiff
            local newDirX = math.cos(newAngle)
            local newDirY = math.sin(newAngle)
            
            -- Update velocity to maintain speed but change direction
            velocity.vx = newDirX * speed
            velocity.vy = newDirY * speed
            
            -- Update polygon rotation to match new direction
            polygonShape.rotation = newAngle
            
            -- Apply acceleration in direction of travel
            if acceleration then
                acceleration.ax = newDirX * homing.acceleration
                acceleration.ay = newDirY * homing.acceleration
            end
        end
    end
    
    -- Also update rotation for non-homing missiles
    local speed = math.sqrt(velocity.vx * velocity.vx + velocity.vy * velocity.vy)
    if speed > 0 then
        local currentDirX = velocity.vx / speed
        local currentDirY = velocity.vy / speed
        -- Use math.atan2(y, x) for proper 360-degree angle calculation
        polygonShape.rotation = math.atan2(currentDirY, currentDirX)
    end
    
    -- Apply acceleration for all missiles
    if acceleration then
        local currentSpeed = math.sqrt(velocity.vx * velocity.vx + velocity.vy * velocity.vy)
        if currentSpeed > 0 then
            local dirX = velocity.vx / currentSpeed
            local dirY = velocity.vy / currentSpeed
            acceleration.ax = dirX * MissileLauncher.MISSILE_ACCELERATION
            acceleration.ay = dirY * MissileLauncher.MISSILE_ACCELERATION
        end
    end
    
    -- Apply maxSpeed cap
    local speed = math.sqrt(velocity.vx * velocity.vx + velocity.vy * velocity.vy)
    if speed > MissileLauncher.MISSILE_MAX_SPEED then
        velocity.vx = (velocity.vx / speed) * MissileLauncher.MISSILE_MAX_SPEED
        velocity.vy = (velocity.vy / speed) * MissileLauncher.MISSILE_MAX_SPEED
    end
end

-- Update missile age and lifecycle
function MissileLauncher.updateAge(missileId, dt)
    local lifecycle = ECS.getComponent(missileId, "MissileAge")
    if not lifecycle then return end
    
    -- Increase age
    lifecycle.age = lifecycle.age + dt
    
    -- Check if missile has exceeded max age
    if lifecycle.age >= lifecycle.maxAge then
        -- Self-destruct: set durability to 0 to trigger destruction system
        local durability = ECS.getComponent(missileId, "Durability")
        if durability then
            durability.current = 0
        end
    end
end

return MissileLauncher
