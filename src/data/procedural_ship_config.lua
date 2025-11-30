local ShipProceduralConfig = {
    SIZE = {
        SMALL = {
            PROBABILITY_CUTOFF = 0.33,
            LENGTH_MIN = 22,
            LENGTH_VARIATION = 16,
            WIDTH_MIN = 12,
            WIDTH_VARIATION = 10,
        },
        MEDIUM = {
            PROBABILITY_CUTOFF = 0.66,
            LENGTH_MIN = 26,
            LENGTH_VARIATION = 20,
            WIDTH_MIN = 16,
            WIDTH_VARIATION = 14,
        },
        LARGE = {
            LENGTH_MIN = 32,
            LENGTH_VARIATION = 22,
            WIDTH_MIN = 20,
            WIDTH_VARIATION = 18,
        },
        RADIUS_MULTIPLIER = 0.5,
    },

    CLASS_BREAKPOINTS = {
        SMALL_MAX_LENGTH = 30,
        MEDIUM_MAX_LENGTH = 40,
    },

    CLASS_MULTIPLIERS = {
        SMALL = { MASS = 0.85, HP = 0.9, SHIELD = 0.8, SPEED = 1.2 },
        MEDIUM = { MASS = 1.0, HP = 1.0, SHIELD = 1.0, SPEED = 1.0 },
        LARGE = { MASS = 1.35, HP = 1.4, SHIELD = 1.5, SPEED = 0.8 },
    },

    STATS = {
        MASS_RADIUS_DIVISOR = 15,
        HULL_BASE = 50,
        HULL_RANDOM_MAX = 100,
        SHIELD_BASE = 20,
        SHIELD_RANDOM_MAX = 80,
        SPEED_RADIUS_SCALE = 1.5,
        SPEED_RADIUS_DIVISOR = 40,
        SHIELD_REGEN = 5,
    },

    PHYSICS = {
        RESTITUTION = 0.2,
    },

    LOADOUT = {
        WEAPON_NAME = "pulse_laser",
        CARGO_CAPACITY = 50,
        MAGNET_RADIUS = 100,
        MAGNET_FORCE = 20,
    },

    COLOR_SCHEMES = { "warm", "cool", "neutral", "vibrant" },

    ENGINES = {
        MIN_COUNT = 2,
        MAX_COUNT = 4,
    },

    PANEL_LINES = {
        MIN_COUNT = 4,
        MAX_COUNT = 8,
    },
}

return ShipProceduralConfig
