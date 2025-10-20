-- Constants - A central place for all game configuration values

local Constants = {}

-- Screen dimensions
Constants.screen_width = 1920
Constants.screen_height = 1080

-- World dimensions (much larger than screen for exploration)
Constants.world_width = 20000
Constants.world_height = 20000
Constants.world_min_x = -10000
Constants.world_max_x = 10000
Constants.world_min_y = -10000
Constants.world_max_y = 10000

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
Constants.asteroid_cluster_radius = 500
Constants.asteroid_size_min = 20
Constants.asteroid_size_max = 60
Constants.asteroid_velocity_min = 10
Constants.asteroid_velocity_max = 40
Constants.asteroid_rotation_min = -1
Constants.asteroid_rotation_max = 1
Constants.asteroid_vertices_min = 6
Constants.asteroid_vertices_max = 10

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

-- Bit spawning speeds (when destroyed)
Constants.bit_spawn_speed_asteroid_min = 40
Constants.bit_spawn_speed_asteroid_max = 120
Constants.bit_spawn_speed_wreckage_min = 30
Constants.bit_spawn_speed_wreckage_max = 80
Constants.bit_spawn_speed_debris_min = 20
Constants.bit_spawn_speed_debris_max = 50

return Constants