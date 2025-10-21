-- Basic Cannon Turret Module
-- Fires a yellow ball projectile that shatters on impact

local ECS = require('src.ecs')
local Components = require('src.components')
local DebrisSystem = require('src.systems.debris')

local BasicCannon = {
    name = "basic_cannon",
    displayName = "Basic Cannon",
    BALL_SPEED = 200,
    BALL_RADIUS = 8,
    BALL_COLOR = {1, 0.9, 0.2, 1},
    COOLDOWN = 2, -- Time between shots in seconds
    DPS = 10, -- Damage per shot
    design = {
        shape = "custom",
        size = 16,
        color = {1, 0.9, 0.2, 1}
    },
    draw = function(self, x, y)
        local size = self.design.size -- Use design.size
        love.graphics.setColor(0.3, 0.3, 0.3, 1)
        love.graphics.rectangle("fill", x - size/4, y - size/2, size/2, size, 4, 4)
        love.graphics.setColor(1, 0.9, 0.2, 1)
        love.graphics.circle("fill", x, y + size/2, size/4)
        love.graphics.setColor(0.2, 0.2, 0.2, 1)
        love.graphics.rectangle("fill", x - size/2, y + size/3, size, size/3, 4, 4)
    end
}

function BasicCannon.fire(ownerId, startX, startY, endX, endY)
    -- Calculate direction
    local dx = endX - startX
    local dy = endY - startY
    local dist = math.sqrt(dx * dx + dy * dy)
    if dist == 0 then return end
    local dirX = dx / dist
    local dirY = dy / dist

    -- Offset spawn position to barrel end (away from ship center)
    -- Barrel extends from ship center by approximately the ship's radius
    local ownerCollidable = ECS.getComponent(ownerId, "Collidable")
    local barrelLength = ownerCollidable and (ownerCollidable.radius + BasicCannon.BALL_RADIUS + 5) or 20
    
    local spawnX = startX + dirX * barrelLength
    local spawnY = startY + dirY * barrelLength

    -- Create projectile entity
    local ballId = ECS.createEntity()
    ECS.addComponent(ballId, "Position", Components.Position(spawnX, spawnY))
    ECS.addComponent(ballId, "Velocity", Components.Velocity(dirX * BasicCannon.BALL_SPEED, dirY * BasicCannon.BALL_SPEED))
    ECS.addComponent(ballId, "Renderable", Components.Renderable("circle", nil, nil, BasicCannon.BALL_RADIUS, BasicCannon.BALL_COLOR))
    ECS.addComponent(ballId, "Collidable", Components.Collidable(BasicCannon.BALL_RADIUS))
    ECS.addComponent(ballId, "Physics", Components.Physics(1.0, 0.5, 0.99))
    ECS.addComponent(ballId, "Durability", Components.Durability(1, 1))
        ECS.addComponent(ballId, "Projectile", {ownerId = ownerId, damage = BasicCannon.DPS, brittle = true, isMissile = false})
    ECS.addComponent(ballId, "ShatterEffect", {
        numPieces = 8,
        color = BasicCannon.BALL_COLOR
    })
end

return BasicCannon
