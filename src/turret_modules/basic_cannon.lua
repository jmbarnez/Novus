---@diagnostic disable: undefined-global
-- Basic Cannon Turret Module
-- Fires a yellow ball projectile that shatters on impact

local ECS = require('src.ecs')
local Components = require('src.components')
local DebrisSystem = require('src.systems.debris')
local SoundSystem = require('src.systems.sound')

local BasicCannon = {
    id = "basic_cannon_turret",
    name = "basic_cannon",
    displayName = "Basic Cannon",
    description = "A simple kinetic cannon that fires yellow projectiles.",
    stackable = false,
    value = 80,
    volume = 0.3,
    skill = "kinetic", -- Skill awarded for this turret
    levelRequirement = 2, -- Requires player level 2
    BALL_SPEED = 200,
    BALL_RADIUS = 4,
    BALL_COLOR = {1, 0.9, 0.2, 1},
    BALL_LIFETIME = 6, -- Seconds before projectile shatters
    COOLDOWN = 2, -- Time between shots in seconds
    DPS = 40, -- Damage per shot (increased from 10)
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

local cannonSoundName = "cannon_shot"
local cannonSoundPath = "assets/sounds/cannon_shot.flac"
local attemptedSoundLoad = false

local function ensureSoundLoaded()
    if attemptedSoundLoad then
        return
    end
    attemptedSoundLoad = true

    if not SoundSystem or not SoundSystem.load then
        return
    end

    if SoundSystem.sounds and SoundSystem.sounds[cannonSoundName] then
        return
    end

    if love and love.filesystem and love.filesystem.getInfo and love.filesystem.getInfo(cannonSoundPath) then
        SoundSystem.load(cannonSoundName, cannonSoundPath)
    end
end

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
    -- Apply damage multiplier from owner ship
    local damageMultiplier = 1.0
    local ownerDamageMultiplier = ECS.getComponent(ownerId, "DamageMultiplier")
    if ownerDamageMultiplier then
        damageMultiplier = ownerDamageMultiplier.multiplier
    end
    
    ECS.addComponent(ballId, "Projectile", {ownerId = ownerId, damage = BasicCannon.DPS * damageMultiplier, brittle = true, isMissile = false, weaponModule = BasicCannon.name})
    ECS.addComponent(ballId, "ShatterEffect", {
        numPieces = 8,
        color = BasicCannon.BALL_COLOR
    })
    ECS.addComponent(ballId, "ProjectileLifetime", {
        age = 0,
        maxAge = BasicCannon.BALL_LIFETIME
    })

    ensureSoundLoaded()
    if SoundSystem and SoundSystem.play then
        -- Get listener position (camera/player position)
        local listenerX, listenerY = 0, 0
        local cameraEntities = ECS.getEntitiesWith({"Camera", "Position"})
        if #cameraEntities > 0 then
            local cameraPos = ECS.getComponent(cameraEntities[1], "Position")
            listenerX, listenerY = cameraPos.x + 400, cameraPos.y + 300  -- Approximate screen center
        end
        SoundSystem.play(cannonSoundName, {
            volume = 75,
            position = {x = spawnX, y = spawnY},
            listener = {x = listenerX, y = listenerY}
        })
    end
end

return BasicCannon
