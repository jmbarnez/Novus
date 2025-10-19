---@diagnostic disable: undefined-global
-- Turret Range Calculator - Calculates firing range based on projectile properties
-- Helps AI determine if enemies are within firing range

local ECS = require('src.ecs')

local TurretRange = {}

-- Turret projectile specifications - maps turret module name to projectile properties
local PROJECTILE_SPECS = {
    basic_cannon = {
        speed = 200,        -- pixels per second
        lifetime = 8        -- seconds before disappearing
    },
    combat_laser = {
        speed = math.huge,  -- Laser is instant/infinite speed (line-of-sight)
        lifetime = 0.1      -- Very short, just the beam duration
    },
    mining_laser = {
        speed = math.huge,  -- Laser is instant (line-of-sight)
        lifetime = 0.1
    },
    salvage_laser = {
        speed = math.huge,  -- Laser is instant (line-of-sight)
        lifetime = 0.1
    }
}

-- Calculate the maximum firing range for a turret module
-- Range = projectile_speed * projectile_lifetime
-- For instant weapons (lasers), this is effectively infinite (we return a large number)
-- @param moduleName string: Name of the turret module (e.g., "basic_cannon", "combat_laser")
-- @return number: Maximum firing range in pixels
function TurretRange.getMaxRange(moduleName)
    local spec = PROJECTILE_SPECS[moduleName]
    
    if not spec then
        -- Unknown module, return a safe default
        return 500
    end
    
    if spec.speed == math.huge then
        -- Instant/laser weapons have effectively infinite range within the world
        -- Return a very large number instead of infinity to avoid issues
        return 5000
    end
    
    return spec.speed * spec.lifetime
end

-- Get firing delay (cooldown) for a turret
-- Different weapons have different rates of fire
-- @param moduleName string: Name of the turret module
-- @return number: Cooldown in seconds between shots
function TurretRange.getFireCooldown(moduleName)
    local COOLDOWNS = {
        basic_cannon = 0.3,      -- 3.3 shots per second
        combat_laser = 0.05,     -- Always firing continuous beam
        mining_laser = 0.05,     -- Always firing continuous beam
        salvage_laser = 0.05     -- Always firing continuous beam
    }
    
    return COOLDOWNS[moduleName] or 0.5
end

return TurretRange
