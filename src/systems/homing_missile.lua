-- Homing Missile System
-- Handles guidance for missiles that home in on locked targets

local ECS = require('src.ecs')

local HomingMissileSystem = {
    name = "HomingMissileSystem",
    priority = 3 -- Run after physics but before collision
}

function HomingMissileSystem.update(dt)
    -- Handle homing missiles (with HomingMissile component)
    local homingMissiles = ECS.getEntitiesWith({"HomingMissile", "Position", "Velocity", "PolygonShape"})

    for _, missileId in ipairs(homingMissiles) do
        local homing = ECS.getComponent(missileId, "HomingMissile")
        local position = ECS.getComponent(missileId, "Position")
        local velocity = ECS.getComponent(missileId, "Velocity")
        local polygonShape = ECS.getComponent(missileId, "PolygonShape")

        if not (homing and position and velocity and polygonShape) then goto continue_homing end

        -- Check if target still exists and is valid
        local targetPos = nil
        if homing.targetId then
            targetPos = ECS.getComponent(homing.targetId, "Position")
            -- If target no longer exists or is destroyed, stop homing
            if not targetPos then
                -- Remove homing component, missile will continue straight
                ECS.removeComponent(missileId, "HomingMissile")
                print(string.format("[HomingMissile] Target %d lost, missile %d continues unguided", homing.targetId, missileId))
                goto continue_homing
            end
        end

        if targetPos then
            -- Calculate direction to target
            local dx = targetPos.x - position.x
            local dy = targetPos.y - position.y
            local distToTarget = math.sqrt(dx * dx + dy * dy)

            -- Check if within maximum range
            if distToTarget > homing.maxRange then
                -- Target too far, stop homing
                ECS.removeComponent(missileId, "HomingMissile")
                print(string.format("[HomingMissile] Target out of range, missile %d continues unguided", missileId))
                goto continue_homing
            end

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
            end
        end

        ::continue_homing::
    end

    -- Handle all missiles (including non-homing ones) - update rotation to match velocity
    local allMissiles = ECS.getEntitiesWith({"Projectile", "Position", "Velocity", "PolygonShape"})

    for _, missileId in ipairs(allMissiles) do
        local velocity = ECS.getComponent(missileId, "Velocity")
        local polygonShape = ECS.getComponent(missileId, "PolygonShape")
        local projectile = ECS.getComponent(missileId, "Projectile")

        -- Only handle missiles (not other projectiles like cannon balls)
        if projectile and projectile.isMissile and velocity and polygonShape then
            local speed = math.sqrt(velocity.vx * velocity.vx + velocity.vy * velocity.vy)
            if speed > 0 then
                local currentDirX = velocity.vx / speed
                local currentDirY = velocity.vy / speed
                polygonShape.rotation = math.atan2(currentDirY, currentDirX)
            end
        end
    end
end

return HomingMissileSystem
