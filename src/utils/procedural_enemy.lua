-- Procedural Enemy Generator
-- Generates basic enemy drones with AI

local ProceduralShip = require "src.utils.procedural_ship"
local EnemyBehaviors = require "src.ai.behaviors.enemy_behaviors"
local EnemyProceduralConfig = require "src.data.procedural_enemy_config"

local ProceduralEnemy = {}

-- Generate a basic enemy drone configuration
-- @param seed: Random seed for generation
-- @param base_level: Base level for the enemy (from sector difficulty)
-- @return enemy_config: Configuration table for spawning
function ProceduralEnemy.generate(seed, base_level)
    base_level = base_level or EnemyProceduralConfig.LEVEL.BASE_LEVEL
    local rng = love.math.newRandomGenerator(seed)

    -- Generate level with some variation
    local level = base_level + rng:random(
        EnemyProceduralConfig.LEVEL.VARIATION_MIN,
        EnemyProceduralConfig.LEVEL.VARIATION_MAX
    )
    if level < 1 then level = 1 end

    -- Calculate level multiplier
    local level_mult = 1 + (level - EnemyProceduralConfig.LEVEL.BASE_LEVEL) * EnemyProceduralConfig.LEVEL.LEVEL_MULT_PER_LEVEL

    -- Generate procedural ship appearance
    local ship_seed = seed + EnemyProceduralConfig.SHIP_SEED_OFFSET
    local ship_data = ProceduralShip.generate(ship_seed)

    if ship_data and ship_data.engine_mounts then
        for _, mount in ipairs(ship_data.engine_mounts) do
            local r = EnemyProceduralConfig.ENGINE_TRAIL_COLOR.R
            local g = EnemyProceduralConfig.ENGINE_TRAIL_COLOR.G_MIN + rng:random() * EnemyProceduralConfig.ENGINE_TRAIL_COLOR.G_RANGE
            local b = EnemyProceduralConfig.ENGINE_TRAIL_COLOR.B_MIN + rng:random() * EnemyProceduralConfig.ENGINE_TRAIL_COLOR.B_RANGE
            mount.color = { r, g, b, EnemyProceduralConfig.ENGINE_TRAIL_COLOR.A }
        end
    end

    if ship_data and ship_data.render_data and ship_data.render_data.engines then
        for _, eng in ipairs(ship_data.render_data.engines) do
            local r = EnemyProceduralConfig.ENGINE_GLOW_COLOR.R
            local g = EnemyProceduralConfig.ENGINE_GLOW_COLOR.G_MIN + rng:random() * EnemyProceduralConfig.ENGINE_GLOW_COLOR.G_RANGE
            local b = EnemyProceduralConfig.ENGINE_GLOW_COLOR.B_MIN + rng:random() * EnemyProceduralConfig.ENGINE_GLOW_COLOR.B_RANGE
            eng.color = { r, g, b, EnemyProceduralConfig.ENGINE_GLOW_COLOR.A }
        end
    end

    -- Base stats
    local base_hp = ship_data.max_hull or EnemyProceduralConfig.BASE_STATS.DEFAULT_BASE_HULL
    local base_shield = ship_data.max_shield or EnemyProceduralConfig.BASE_STATS.DEFAULT_BASE_SHIELD
    local base_speed = ship_data.max_speed or EnemyProceduralConfig.BASE_STATS.DEFAULT_BASE_SPEED
    local base_thrust = ship_data.thrust or EnemyProceduralConfig.BASE_STATS.DEFAULT_BASE_THRUST

    -- Apply level scaling
    local hp = math.floor(base_hp * level_mult)
    local shield = math.floor(base_shield * level_mult)
    local max_speed = base_speed
    local thrust = base_thrust
    local detection_range = EnemyProceduralConfig.DETECTION.RANGE -- Simple fixed detection range for now

    -- Red enemy color
    local color = {
        EnemyProceduralConfig.COLOR.R,
        EnemyProceduralConfig.COLOR.G,
        EnemyProceduralConfig.COLOR.B,
    }

    -- Always use basic drone behavior
    local behavior_tree = EnemyBehaviors.createBasicDrone()

    -- Create name
    local name = "Enemy Drone Lv." .. level

    return {
        -- Identity
        name = name,
        level = level,

        -- Ship appearance (from procedural generation)
        ship_data = ship_data,
        radius = ship_data.radius or EnemyProceduralConfig.BASE_STATS.DEFAULT_RADIUS,
        color = color,

        -- Stats
        max_hull = hp,
        max_shield = shield,
        shield_regen = EnemyProceduralConfig.BASE_STATS.SHIELD_REGEN_BASE
            + level * EnemyProceduralConfig.BASE_STATS.SHIELD_REGEN_PER_LEVEL,
        max_speed = max_speed,
        thrust = thrust,
        rotation_speed = ship_data.rotation_speed or EnemyProceduralConfig.BASE_STATS.DEFAULT_ROTATION_SPEED,
        mass = ship_data.mass or EnemyProceduralConfig.BASE_STATS.DEFAULT_MASS,

        -- AI
        detection_range = detection_range,
        behavior_tree = behavior_tree,
    }
end

return ProceduralEnemy
