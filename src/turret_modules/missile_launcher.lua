-- Missile Launcher Turret Module
-- Fires homing missiles that lock onto targeted enemies, or fly straight if no target is locked

local ECS = require('src.ecs')
local Components = require('src.components')

local MissileLauncher = {
    name = "missile_launcher",
    displayName = "Missile Launcher",
    MISSILE_SPEED = 150,
    MISSILE_RADIUS = 6,
    MISSILE_COLOR = {1, 0.3, 0.1, 1}, -- Orange-red
    HOMING_TURN_RATE = 2.0, -- Radians per second turning rate
    COOLDOWN = 3, -- Time between shots in seconds
    DPS = 25, -- Damage per missile
    RANGE = 1000, -- Maximum range missiles can home
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

    -- Get the owner entity's input component to check for targeted enemy
    local inputComp = ECS.getComponent(ownerId, "InputControlled")
    local targetedEnemy = inputComp and inputComp.targetedEnemy

    -- Create missile entity
    local missileId = ECS.createEntity()
    ECS.addComponent(missileId, "Position", Components.Position(spawnX, spawnY))
    ECS.addComponent(missileId, "Velocity", Components.Velocity(dirX * MissileLauncher.MISSILE_SPEED, dirY * MissileLauncher.MISSILE_SPEED))

    -- Create missile shape (elongated with pointed nose and fins)
    local missileLength = MissileLauncher.MISSILE_RADIUS * 3  -- Missile is 3 times longer than radius
    local missileWidth = MissileLauncher.MISSILE_RADIUS * 0.6  -- Slightly narrower than the collision radius
    local missileVertices = {
        {x = missileLength, y = 0},        -- Nose tip
        {x = missileLength * 0.7, y = missileWidth * 0.5},  -- Nose shoulder
        {x = -missileLength * 0.3, y = missileWidth * 0.5}, -- Body top
        {x = -missileLength * 0.8, y = missileWidth * 0.8}, -- Fin top
        {x = -missileLength, y = 0},       -- Tail center
        {x = -missileLength * 0.8, y = -missileWidth * 0.8}, -- Fin bottom
        {x = -missileLength * 0.3, y = -missileWidth * 0.5}, -- Body bottom
        {x = missileLength * 0.7, y = -missileWidth * 0.5}   -- Nose shoulder bottom
    }

    -- Calculate initial rotation to face the direction of travel
    local initialRotation = math.atan2(dirY, dirX)

    ECS.addComponent(missileId, "PolygonShape", Components.PolygonShape(missileVertices, initialRotation))
    ECS.addComponent(missileId, "Renderable", Components.Renderable("polygon", nil, nil, nil, MissileLauncher.MISSILE_COLOR))
    ECS.addComponent(missileId, "Collidable", Components.Collidable(MissileLauncher.MISSILE_RADIUS))
    -- Give missile physics with low friction for sustained flight
    ECS.addComponent(missileId, "Physics", Components.Physics(1, 0.98))
    -- Missile durability - survives longer than basic projectiles
    ECS.addComponent(missileId, "Durability", Components.Durability(3, 3)) -- Takes 3 hits to destroy
    -- Mark as projectile
    ECS.addComponent(missileId, "Projectile", {ownerId = ownerId, damage = MissileLauncher.DPS, brittle = false, isMissile = true})

    -- Add homing component if target is locked
    if targetedEnemy then
        ECS.addComponent(missileId, "HomingMissile", {
            targetId = targetedEnemy,
            turnRate = MissileLauncher.HOMING_TURN_RATE,
            maxRange = MissileLauncher.RANGE,
            initialDirection = {x = dirX, y = dirY}
        })
        print(string.format("[MissileLauncher] Fired homing missile targeting enemy %d", targetedEnemy))
    else
        print("[MissileLauncher] Fired unguided missile (no target lock)")
    end
end

return MissileLauncher
