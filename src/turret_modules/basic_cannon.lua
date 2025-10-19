-- Basic Cannon Turret Module
-- Fires a yellow ball projectile that shatters on impact

local ECS = require('src.ecs')
local Components = require('src.components')
local DebrisSystem = require('src.systems.debris')

local BasicCannon = {
    name = "basic_cannon",
    BALL_SPEED = 200,
    BALL_RADIUS = 8,
    BALL_COLOR = {1, 0.9, 0.2, 1},
}

function BasicCannon.fire(ownerId, startX, startY, endX, endY)
    -- Calculate direction
    local dx = endX - startX
    local dy = endY - startY
    local dist = math.sqrt(dx * dx + dy * dy)
    if dist == 0 then return end
    local dirX = dx / dist
    local dirY = dy / dist

    -- Offset spawn position so projectile starts well away from the ship to prevent collision/sticking
    -- Use a larger offset (25 units) to ensure it clears the player ship's collision radius
    local spawnX = startX + dirX * 25
    local spawnY = startY + dirY * 25

    print(string.format("[Cannon] Fire dir: (%.2f, %.2f) | spawn: (%.2f, %.2f) -> (%.2f, %.2f)", dirX, dirY, startX, startY, spawnX, spawnY))

    -- Create projectile entity
    local ballId = ECS.createEntity()
    ECS.addComponent(ballId, "Position", Components.Position(spawnX, spawnY))
    ECS.addComponent(ballId, "Velocity", Components.Velocity(dirX * BasicCannon.BALL_SPEED, dirY * BasicCannon.BALL_SPEED))
    ECS.addComponent(ballId, "Renderable", Components.Renderable("circle", nil, nil, BasicCannon.BALL_RADIUS, BasicCannon.BALL_COLOR))
    ECS.addComponent(ballId, "Collidable", Components.Collidable(BasicCannon.BALL_RADIUS))
    -- Give projectile physics so it participates naturally in collisions
    ECS.addComponent(ballId, "Physics", Components.Physics(1, 0.01)) -- no friction, low mass
    -- Small durability so it breaks upon a strong impact (brittle)
    ECS.addComponent(ballId, "Durability", Components.Durability(1, 1)) -- Destroy on impact
    -- Mark projectile as brittle so collision handling can treat it specially
    ECS.addComponent(ballId, "Projectile", {ownerId = ownerId, damage = 10, brittle = true, isMiningLaser = false})
    
    -- Add shatter effect component to spawn debris particles on destruction
    ECS.addComponent(ballId, "ShatterEffect", {
        numPieces = 8,
        color = BasicCannon.BALL_COLOR
    })
    
    print(string.format("[Cannon] Created projectile %d | vel: (%.2f, %.2f) | pos: (%.2f, %.2f)", ballId, dirX * BasicCannon.BALL_SPEED, dirY * BasicCannon.BALL_SPEED, spawnX, spawnY))
end

return BasicCannon
