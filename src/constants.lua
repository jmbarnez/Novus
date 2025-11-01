---@diagnostic disable: undefined-global
-- Constants - A central place for all game configuration values

local Constants = {}

-- Dynamic screen dimensions - get current window resolution
function Constants.getScreenWidth()
    if love and love.graphics and love.graphics.getWidth then
        return love.graphics.getWidth()
    end
    return Constants.screen_width
end

function Constants.getScreenHeight()
    if love and love.graphics and love.graphics.getHeight then
        return love.graphics.getHeight()
    end
    return Constants.screen_height
end

-- Backwards compatibility - these will be removed in favor of dynamic functions
-- NOTE: These are now deprecated and should not be used. Use Constants.getScreenWidth() and Constants.getScreenHeight() instead.
Constants.screen_width = 1920
Constants.screen_height = 1080

-- World dimensions (much larger than screen for exploration)
-- NOTE: Reduced world size to half of previous value for tighter play area
-- World origin moved to (0,0) for easier chunk indexing and reasoning
Constants.world_width = 20000
Constants.world_height = 20000
Constants.world_min_x = 0
Constants.world_max_x = Constants.world_min_x + Constants.world_width
Constants.world_min_y = 0
Constants.world_max_y = Constants.world_min_y + Constants.world_height
Constants.WORLD_RADIUS = Constants.world_width / 2 -- half width

-- Chunking settings
-- Size of each world chunk in world units. Chunks are square (CHUNK_SIZE x CHUNK_SIZE).
-- Increase chunk size to 10,000 so a 20,000x20,000 world is 2x2 chunks
Constants.CHUNK_SIZE = 10000

-- Convert world coordinates to chunk coordinates (integer chunk indices)
function Constants.worldToChunk(x, y)
    -- Convert coordinates into 0-based chunk indices using world_min as origin and clamp to valid range
    local cx = math.floor((x - Constants.world_min_x) / Constants.CHUNK_SIZE)
    local cy = math.floor((y - Constants.world_min_y) / Constants.CHUNK_SIZE)
    local maxCx = math.floor(Constants.world_width / Constants.CHUNK_SIZE) - 1
    local maxCy = math.floor(Constants.world_height / Constants.CHUNK_SIZE) - 1
    if cx < 0 then cx = 0 end
    if cy < 0 then cy = 0 end
    if cx > maxCx then cx = maxCx end
    if cy > maxCy then cy = maxCy end
    return cx, cy
end

-- Helper to create a stable chunk key for table indexing
function Constants.chunkKey(cx, cy)
    return tostring(cx) .. "," .. tostring(cy)
end

-- Player physics
Constants.player_friction = 0.9999  -- Near-zero friction for space (nearly no deceleration)
Constants.player_max_speed = 1200

-- Trail settings
Constants.trail_emit_rate = 50
Constants.trail_max_particles = 100
Constants.trail_particle_life = 1.5
Constants.trail_spread_angle = 0.4
Constants.trail_speed_multiplier = 0.3
Constants.trail_particle_size_min = 1.5
Constants.trail_particle_size_max = 2.5

-- UI settings
Constants.ui_speed_bar_width = 200
Constants.ui_speed_bar_height = 20
-- UI scaling constants (add for reference resolution)
Constants.ui_health_bar_width = 240
Constants.ui_health_bar_height = 16

-- Asteroid settings
Constants.asteroid_cluster_count = 15
Constants.asteroid_cluster_radius = 750
Constants.asteroid_size_min = 20
Constants.asteroid_size_max = 60
Constants.asteroid_velocity_min = 10
Constants.asteroid_velocity_max = 40
Constants.asteroid_rotation_min = -1
Constants.asteroid_rotation_max = 1
Constants.asteroid_vertices_min = 6
Constants.asteroid_vertices_max = 10

-- Asteroid cluster respawning system settings
Constants.asteroid_num_clusters = 1  -- Number of clusters to create
Constants.asteroids_per_cluster = 30  -- Max asteroids per cluster
Constants.cluster_respawn_interval = 24  -- Was 3, now much slower: seconds between respawn checks
Constants.cluster_respawn_delay = 20  -- Was 1, increased for much slower individual asteroid respawn

-- Magnetic collection settings
Constants.magnet_pull_speed = 500  -- Units per second
Constants.magnet_collect_distance = 30  -- Distance to collect bits
Constants.magnet_radius_scale = 1.5  -- Multiplier for collisionRadius to get magnetic field radius

-- AI settings
Constants.ai_default_speed = 80
Constants.ai_detection_radius = 1200
Constants.ai_fire_range = 2500
Constants.ai_patrol_speed_default = 60
Constants.ai_detection_range_default = 400
Constants.ai_engage_range_default = 240

-- World spawning settings
Constants.asteroid_field_density = 150  -- Reduced further for performance (was 500, then 200)
Constants.asteroid_field_thickness = 3000
Constants.mining_drones_count = 5
Constants.cannon_drones_count = 10

-- Asteroid cluster enemy spawn configuration
Constants.cluster_enemy_spawn_chance = 0.5 -- 50% chance a given cluster will spawn an enemy group
Constants.cluster_miner_count_min = 1
Constants.cluster_miner_count_max = 2
Constants.cluster_combat_count_min = 3
Constants.cluster_combat_count_max = 5

-- Bit spawning speeds (when destroyed)
Constants.bit_spawn_speed_asteroid_min = 40
Constants.bit_spawn_speed_asteroid_max = 120
Constants.bit_spawn_speed_wreckage_min = 30
Constants.bit_spawn_speed_wreckage_max = 80
Constants.bit_spawn_speed_debris_min = 20
Constants.bit_spawn_speed_debris_max = 50

return Constants
