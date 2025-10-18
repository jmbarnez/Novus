-- Constants - A central place for all game configuration values

local Constants = {}

-- Screen dimensions
Constants.screen_width = 1920
Constants.screen_height = 1080

-- Player physics
Constants.player_friction = 0.9999
Constants.player_max_speed = 300

-- Trail settings
Constants.trail_emit_rate = 25
Constants.trail_max_particles = 40
Constants.trail_particle_life = 1.5
Constants.trail_spread_angle = 0.4
Constants.trail_speed_multiplier = 0.3
Constants.trail_particle_size_min = 0.5
Constants.trail_particle_size_max = 1.0

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

return Constants