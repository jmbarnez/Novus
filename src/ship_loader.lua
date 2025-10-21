-- Ship Design Loader
-- Loads ship designs from ship_designs/ directory and provides factory function

local ECS = require('src.ecs')
local Components = require('src.components')
local Constants = require('src.constants')

local ShipLoader = {
    designs = {}
}

-- Load a single ship design file
function ShipLoader.loadDesign(designId, filepath)
    local success, design = pcall(require, filepath)
    if success and design then
        ShipLoader.designs[designId] = design
        -- Loaded ship design
        return true
    else
        -- Failed to load ship design
        return false
    end
end

-- Load all ship designs from a directory
function ShipLoader.loadAllDesigns(directory)
    directory = directory or "src.ship_designs"
    
    -- Known ship designs to load
    local knownDesigns = {
        "starter_drone",
        "red_scout",
        "standard_combat",
        "starter_hexagon"
    }
    
    local loadedCount = 0
    for _, designId in ipairs(knownDesigns) do
        local filepath = directory .. "." .. designId
        if ShipLoader.loadDesign(designId, filepath) then
            loadedCount = loadedCount + 1
        end
    end
    
    -- Loaded ship designs
end

-- Create a ship entity from a design
function ShipLoader.createShip(designId, x, y, controllerType, controllerId)
    local design = ShipLoader.designs[designId]
    if not design then
        -- Unknown ship design
        return nil
    end
    
    -- Create entity
    local shipId = ECS.createEntity()
    
    -- Core components
    ECS.addComponent(shipId, "Position", Components.Position(x or 0, y or 0))
    ECS.addComponent(shipId, "Velocity", Components.Velocity(0, 0))
    ECS.addComponent(shipId, "Acceleration", Components.Acceleration(0, 0))
    
    -- Physics
    ECS.addComponent(shipId, "Physics", Components.Physics(
        design.friction or 0.95,
        design.mass or 1,
        design.angularDamping or 0.95  -- Ships get controlled damping by default
    ))
    
    -- Determine color based on controller type
    local shipColor = design.color
    if not shipColor then
        -- If no color specified in design, use controller-based colors
        if controllerType == "player" then
            shipColor = {0.2, 0.5, 1, 1} -- Blue for player
        elseif controllerType == "ai" then
            shipColor = {1, 0.15, 0.15, 1} -- Red for AI
        else
            shipColor = {0.5, 0.5, 0.5, 1} -- Gray for uncontrolled
        end
    end
    
    -- Visual
    if design.polygon then
        ECS.addComponent(shipId, "PolygonShape", Components.PolygonShape(design.polygon, 0))
        ECS.addComponent(shipId, "Renderable", Components.Renderable(
            "polygon", nil, nil, nil, shipColor
        ))
        
        -- Calculate realistic moment of inertia based on polygon shape and mass
        local mass = design.mass or 1
        local inertia = Components.calculatePolygonInertia(design.polygon, mass)
        ECS.addComponent(shipId, "RotationalMass", Components.RotationalMass(inertia))
        ECS.addComponent(shipId, "AngularVelocity", Components.AngularVelocity(0))
    end
    
    -- Add Force accumulator for force-based physics
    ECS.addComponent(shipId, "Force", Components.Force(0, 0, 0))
    
    -- Collision
    if design.collisionRadius then
        ECS.addComponent(shipId, "Collidable", Components.Collidable(design.collisionRadius))
    end
    
    -- Hull/Shield
    if design.hull then
        ECS.addComponent(shipId, "Hull", Components.Hull(design.hull.current, design.hull.max))
    end
    if design.shield then
        ECS.addComponent(shipId, "Shield", Components.Shield(
            design.shield.current,
            design.shield.max,
            design.shield.regenRate or 5,
            design.shield.regenDelay or 3
        ))
    end
    
    -- Hull/Shield only - no durability component
    
    -- Turret
    if design.turretSlots and design.turretSlots > 0 then
        ECS.addComponent(shipId, "TurretSlots", Components.TurretSlots(design.turretSlots))
        
        local initialTurretModuleName = nil
        if controllerType == "ai" then
            -- AI ships get their default turret module if specified in design
            initialTurretModuleName = design.defaultTurret or nil
        elseif controllerType == "player" then
            -- Player ships start with a default turret (e.g., basic_cannon) for convenience
            initialTurretModuleName = "basic_cannon"
        end
        
        -- Validate the initial turret module exists
        if initialTurretModuleName and initialTurretModuleName ~= "" then
            local TurretSystem = require('src.systems.turret')
            if not TurretSystem.turretModules or not TurretSystem.turretModules[initialTurretModuleName] then
                -- Warning: default turret module not found; clearing default
                initialTurretModuleName = nil
            end
        end
        ECS.addComponent(shipId, "Turret", Components.Turret(initialTurretModuleName))
        
        -- Add Heat component for all turret-equipped ships (supports laser turrets and potential future heat mechanics)
        ECS.addComponent(shipId, "Heat", Components.Heat())
    end
    
    -- Defensive slots
    if design.defensiveSlots and design.defensiveSlots > 0 then
        ECS.addComponent(shipId, "DefensiveSlots", Components.DefensiveSlots(design.defensiveSlots))
    end
    
    -- Trail emitter (for player-controlled ships typically)
    if design.hasTrail then
        -- Determine trail color based on controller type
        local trailColor = {0.3, 0.7, 1.0} -- Default blue-white for player
        if controllerType == "ai" then
            trailColor = {1.0, 0.1, 0.1} -- Red for AI/enemy
        end
        
        ECS.addComponent(shipId, "TrailEmitter", Components.TrailEmitter(
            Constants.trail_emit_rate,
            Constants.trail_max_particles,
            Constants.trail_particle_life,
            Constants.trail_spread_angle,
            Constants.trail_speed_multiplier,
            trailColor
        ))
    end
    
    -- All ships get cargo and wreckage components
    ECS.addComponent(shipId, "Cargo", Components.Cargo({}, design.cargoCapacity or 50))
    ECS.addComponent(shipId, "Wreckage", Components.Wreckage(designId))
    
    -- Controller setup
    if controllerType == "player" and controllerId then
        -- Player-controlled ship
        ECS.addComponent(shipId, "ControlledBy", Components.ControlledBy(controllerId))
        ECS.addComponent(shipId, "CameraTarget", Components.CameraTarget())
        ECS.addComponent(shipId, "Boundary", Components.Boundary(Constants.world_min_x, Constants.world_max_x, Constants.world_min_y, Constants.world_max_y))
        
        -- Player ships get magnetic field
        local radius = design.collisionRadius and design.collisionRadius * 1.5 or 50
        ECS.addComponent(shipId, "MagneticField", Components.MagneticField(radius))
        
        -- Link the pilot's InputControlled to this ship
        local inputComp = ECS.getComponent(controllerId, "InputControlled")
        if inputComp then
            inputComp.targetEntity = shipId
        end
        
    elseif controllerType == "ai" then
        -- AI-controlled ship
        if design.aiType then
            -- Create patrol points relative to spawn position instead of absolute coordinates
            local relativePatrolPoints = {}
            local basePatrolPoints = design.patrolPoints or {{x=0,y=0}}
            for _, point in ipairs(basePatrolPoints) do
                table.insert(relativePatrolPoints, {x = x + point.x, y = y + point.y})
            end

            ECS.addComponent(shipId, "AIController", Components.AIController(
                design.aiType or "patrol",
                relativePatrolPoints,
                design.patrolSpeed or 60,
                design.detectionRange or 400,
                design.engageRange or 240
            ))
        end
        -- Auto-tag AI type based on turret when available
        local t = ECS.getComponent(shipId, "Turret")
        if t and t.moduleName and t.moduleName ~= "" and t.moduleName ~= "default" then
            if t.moduleName == "mining_laser" or t.moduleName == "salvage_laser" then
                ECS.addComponent(shipId, "MiningAI", Components.MiningAI())
                local ai = ECS.getComponent(shipId, "AIController")
                if ai then ai.state = "mining" end
            else
                ECS.addComponent(shipId, "CombatAI", Components.CombatAI())
            end
        end
    end
    
    -- Created ship
    return shipId
end

-- Get design info
function ShipLoader.getDesign(designId)
    return ShipLoader.designs[designId]
end

-- List all loaded designs
function ShipLoader.listDesigns()
    local list = {}
    for id, design in pairs(ShipLoader.designs) do
        table.insert(list, {id = id, name = design.name, description = design.description})
    end
    return list
end

return ShipLoader
