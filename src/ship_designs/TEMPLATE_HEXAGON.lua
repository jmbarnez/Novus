-- Hexagonal Drone Template
-- A clean template for creating hexagonal drone designs
-- This shows the expected structure for ship designs to work with the upgraded render system

return {
    -- === DISPLAY INFO ===
    name = "Hexagon Drone",
    description = "A clean hexagonal drone design with mounted turret",

    -- === VISUAL DESIGN ===
    -- Polygon: array of {x, y} vertices defining the ship shape
    -- Coordinates are relative to ship center (0, 0)
    -- Vertices should be in clockwise order for proper rendering
    polygon = {
        -- Top point
        {x = 0,    y = -8},
        -- Upper right
        {x = 6.93, y = -4},
        -- Lower right
        {x = 6.93, y = 4},
        -- Bottom right
        {x = 0,    y = 8},
        -- Lower left
        {x = -6.93, y = 4},
        -- Upper left
        {x = -6.93, y = -4},
    },

    -- Colors: Simple structure with stripes and cockpit colors
    -- These are used by the render system to draw the ship with color layers
    colors = {
        -- stripes: Main hull color (RGBA: 0-1 range)
        stripes = {0.2, 0.5, 1, 1},    -- Blue hull
        
        -- cockpit: Detail/highlight color (automatically darkened by render system)
        cockpit = {0.15, 0.15, 0.22, 1}, -- Dark blue cockpit
    },

    -- Collision radius: Bounding circle radius for physics/collision
    collisionRadius = 7,

    -- === STATS ===
    -- Hull: Current and max health
    hull = {current = 80, max = 80},
    
    -- Shield: Optional (set to nil to disable)
    -- structure: { current, max, regenRate, regenDelay }
    shield = nil,

    -- === PHYSICS ===
    -- Friction: 0-1, higher = more friction (1.0 = no coasting, 0.99+ = space physics)
    friction = 0.9999,
    
    -- Mass: Weight of the ship (affects acceleration and collision response)
    -- Reference: projectiles = 0.5, this drone = 5-10, asteroids = 50-500
    mass = 5,
    
    -- Angular damping: 0-1, how fast rotation slows down
    angularDamping = 0.95,

    -- === EQUIPMENT ===
    -- Turret slots: Number of weapon hardpoints
    turretSlots = 1,
    
    -- Default turret: Module ID to equip at spawn (empty string = none)
    defaultTurret = "",
    
    -- Defensive slots: Number of shield/defense hardpoints
    defensiveSlots = 1,
    
    -- Cargo capacity: Max items this ship can hold
    cargoCapacity = 10,

    -- === ABILITIES ===
    -- Has trail: Whether this ship shows engine trail particles
    hasTrail = true,

    -- === AI SETTINGS (for enemy drones) ===
    -- Only used when AI-controlled (controllerType = "ai")
    aiType = "patrol",           -- Behavior type: "patrol", "guard", "aggressive", etc.
    detectionRange = 800,        -- How far AI can "see" enemies
    engageRange = 240,          -- How close before attacking
    patrolSpeed = 120,          -- Base movement speed
}

-- === HOW THE RENDER SYSTEM USES THIS ===
--
-- 1. ShipLoader reads this design and creates an entity with:
--    - Position, Velocity, Physics components
--    - PolygonShape (from polygon table)
--    - Renderable (with colors table)
--    - Hull, equipment, etc.
--
-- 2. RenderSystem draws the ship:
--    a. Calls drawPolygon() with the polygon vertices
--    b. Resolves colors using resolveColors(colors table)
--    c. Draws hull using colors.stripes (main color)
--    d. Draws cockpit dot using colors.cockpit (darkened detail color)
--    e. Draws outline with darkened hull color
--
-- 3. Turret rendering:
--    - Renders at ship center and rotates with mouse aim (player)
--    - Or rotates toward target (AI)
--    - Turret is always white (independent of ship color)
--
-- === CUSTOMIZATION TIPS ===
--
-- Change ship color:
--    colors.stripes = {r, g, b, a}  -- Main hull color (0-1 range)
--    colors.cockpit = {r, g, b, a}  -- Cockpit highlight (gets darkened automatically)
--
-- Change ship shape:
--    - Add/remove vertices in polygon array
--    - Keep vertices ordered clockwise
--    - Larger coordinates = larger ship
--
-- Tweak physics:
--    - mass: Higher = slower, lower = faster
--    - angularDamping: Higher = less spinny, lower = more spinny
--    - friction: Keep near 1.0 for space physics (no drag)
--
-- Add weapons/defense:
--    - turretSlots: 1 = one gun, 2 = dual guns, etc.
--    - defaultTurret: "basic_cannon", "mining_laser", etc. (see src/turret_modules/)
--    - defensiveSlots: Number of shield modules
