local Components = require('src.components')

local TurretPrefab = {}

local function regularPolygon(sides, radius)
    local verts = {}
    local angleStep = (2 * math.pi) / sides
    for i = 1, sides do
        local angle = (i - 1) * angleStep
        table.insert(verts, {x = math.cos(angle) * radius, y = math.sin(angle) * radius})
    end
    return verts
end

function TurretPrefab.generate(spawnData)
    spawnData = spawnData or {}
    
    local x = spawnData.x or 0
    local y = spawnData.y or 0
    local size = spawnData.size or 40
    local mass = spawnData.mass or 800
    local color = spawnData.color or {0.7, 0.7, 0.9, 1}
    local owner = spawnData.owner or "player"  -- "player" or "enemy"
    local hullValue = spawnData.hull or 2000
    local shieldValue = spawnData.shield or 500
    
    -- Simple circular turret base
    local hullSides = spawnData.hullSides or 8
    local hullRadius = spawnData.hullRadius or size
    local verts = regularPolygon(hullSides, hullRadius)
    local inertia = Components.calculatePolygonInertia(verts, mass)
    
    -- Create polygon shape with turret offset (centered at origin for circular turret)
    local polygonShape = Components.PolygonShape(verts, spawnData.hullRotation or 0)
    polygonShape.turretOffsetX = 0  -- Turret is at center of circular base
    polygonShape.turretOffsetY = 0
    
    -- Components for the turret
    local components = {
        Position = Components.Position(x, y),
        Velocity = Components.Velocity(0, 0),
        Physics = Components.Physics(0.999, mass, 0.999),  -- High friction to prevent movement
        PolygonShape = polygonShape,
        RotationalMass = Components.RotationalMass(inertia),
        Collidable = Components.Collidable(spawnData.collidableRadius or hullRadius),
        Renderable = Components.Renderable("polygon", nil, nil, nil, color),
        TurretWorldObject = Components.TurretWorldObject(),
        Hull = Components.Hull(hullValue, hullValue),
        Shield = Components.Shield(shieldValue, shieldValue, 0, 0),
        Energy = Components.Energy(1000, 1000, 50),  -- Turrets need energy and regen for their weapons
    }
    
    -- Add turret slots and turret component for module support
    if spawnData.turretSlots and spawnData.turretSlots > 0 then
        components.TurretSlots = Components.TurretSlots(spawnData.turretSlots)
        
        -- If a default turret module is specified, add it
        if spawnData.defaultTurret then
            components.Turret = Components.Turret(spawnData.defaultTurret)
        else
            -- Default empty turret
            components.Turret = Components.Turret(nil)
        end
        
        -- Default turret config
        components.TurretConfig = Components.TurretConfig(true, 1.0, 4)
    else
        -- Default: 1 turret slot
        components.TurretSlots = Components.TurretSlots(1)
        components.Turret = Components.Turret(nil)
        components.TurretConfig = Components.TurretConfig(true, 1.0, 4)
    end
    
    -- Add AI component based on owner
    if owner == "enemy" then
        components.AI = Components.AI({
            type = "turret",  -- Special turret AI type
            state = "idle",
            detectionRadius = spawnData.detectionRadius or 1500,
            owner = "enemy"
        })
    else
        -- Player turret - controlled by turret AI system
        components.AI = Components.AI({
            type = "turret",
            state = "idle",
            detectionRadius = spawnData.detectionRadius or 1500,
            owner = "player"
        })
    end
    
    -- Add defensive and generator slots if specified
    if spawnData.defensiveSlots and spawnData.defensiveSlots > 0 then
        components.DefensiveSlots = Components.DefensiveSlots(spawnData.defensiveSlots)
    end
    
    if spawnData.generatorSlots and spawnData.generatorSlots > 0 then
        components.GeneratorSlots = Components.GeneratorSlots(spawnData.generatorSlots)
    end
    
    return components
end

return TurretPrefab

