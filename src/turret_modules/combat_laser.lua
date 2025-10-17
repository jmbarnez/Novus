-- Combat Laser Turret Module
-- Fires a fast, thin, red laser bolt projectile

local ECS = require('src.ecs')
local Components = require('src.components')

local CombatLaser = {
    name = "combat_laser",
    BOLT_SPEED = 800,
    BOLT_WIDTH = 2,
    BOLT_HEIGHT = 10,
    BOLT_COLOR = {1, 0.2, 0.2, 1}, -- Red
}

function CombatLaser.fire(ownerId, startX, startY, endX, endY)
    -- Calculate direction
    local dx = endX - startX
    local dy = endY - startY
    local dist = math.sqrt(dx * dx + dy * dy)
    if dist == 0 then return end
    local dirX = dx / dist
    local dirY = dy / dist

    -- Offset spawn position
    local spawnX = startX + dirX * 15
    local spawnY = startY + dirY * 15

    -- Create projectile entity
    local boltId = ECS.createEntity()
    ECS.addComponent(boltId, "Position", Components.Position(spawnX, spawnY))
    ECS.addComponent(boltId, "Velocity", Components.Velocity(dirX * CombatLaser.BOLT_SPEED, dirY * CombatLaser.BOLT_SPEED))
    ECS.addComponent(boltId, "Renderable", Components.Renderable("rectangle", CombatLaser.BOLT_WIDTH, CombatLaser.BOLT_HEIGHT, nil, CombatLaser.BOLT_COLOR))
    ECS.addComponent(boltId, "Collidable", Components.Collidable(CombatLaser.BOLT_HEIGHT / 2))
    ECS.addComponent(boltId, "Physics", Components.Physics(1, CombatLaser.BOLT_SPEED, 0.01)) -- No friction, high speed, low mass
    ECS.addComponent(boltId, "Durability", Components.Durability(1, 1)) -- Destroy on impact
    ECS.addComponent(boltId, "Projectile", {ownerId = ownerId, damage = 15, brittle = true, ownerImmunityTime = 0.1})
end

return CombatLaser
