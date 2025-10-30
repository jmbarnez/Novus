---@diagnostic disable: undefined-global
-- Laser Asteroid Booster sub-module

local LaserAsteroidBooster = {
    id = "laser_asteroid_booster",
    displayName = "Laser Asteroid Booster",
    description = "Increases laser damage against asteroids by 50%.",
    value = 120,
    volume = 0.1,
    -- Compatibility constraints for equipping
    compatible = {
        moduleType = "turret",
        skill = "lasers"
    },
    -- Passive effects read by turret modules
    effects = {
        asteroidDamageMultiplier = 1.5
    }
}

return LaserAsteroidBooster


