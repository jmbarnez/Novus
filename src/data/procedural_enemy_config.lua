local EnemyProceduralConfig = {
    LEVEL = {
        BASE_LEVEL = 1,
        VARIATION_MIN = -1,
        VARIATION_MAX = 1,
        LEVEL_MULT_PER_LEVEL = 0.15,
    },

    SHIP_SEED_OFFSET = 12345,

    ENGINE_TRAIL_COLOR = {
        R = 1,
        G_MIN = 0.2,
        G_RANGE = 0.25,
        B_MIN = 0.15,
        B_RANGE = 0.2,
        A = 1,
    },

    ENGINE_GLOW_COLOR = {
        R = 1,
        G_MIN = 0.25,
        G_RANGE = 0.3,
        B_MIN = 0.1,
        B_RANGE = 0.2,
        A = 0.95,
    },

    BASE_STATS = {
        DEFAULT_BASE_HULL = 100,
        DEFAULT_BASE_SHIELD = 50,
        DEFAULT_BASE_SPEED = 500,
        DEFAULT_BASE_THRUST = 1000,
        SHIELD_REGEN_BASE = 1,
        SHIELD_REGEN_PER_LEVEL = 0.5,
        DEFAULT_ROTATION_SPEED = 5,
        DEFAULT_MASS = 1,
        DEFAULT_RADIUS = 20,
    },

    DETECTION = {
        RANGE = 800,
    },

    COLOR = {
        R = 1,
        G = 0.3,
        B = 0.3,
    },
}

return EnemyProceduralConfig
