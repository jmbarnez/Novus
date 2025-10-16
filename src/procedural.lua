-- Procedural Content Generation System
-- Template-based system for generating any entity type with configurable rules

local Procedural = {}
local Components = require('src.components')
local Constants = require('src.constants')

-- Template registry for different entity types
local templates = {}

-- Register a procedural template
-- @param templateName string: Name of the template
-- @param templateFunction function: Function that returns component data for the entity
function Procedural.registerTemplate(templateName, templateFunction)
    templates[templateName] = templateFunction
end

-- Generate an entity using a template
-- @param templateName string: Name of the template to use
-- @param spawnData table: Optional spawn configuration (position, etc.)
-- @return table: Component data table ready for ECS
function Procedural.generateEntity(templateName, spawnData)
    local template = templates[templateName]
    if not template then
        error("Template not found: " .. templateName)
    end
    
    return template(spawnData or {})
end

-- Spawn multiple entities using a template
-- @param templateName string: Name of the template to use
-- @param count number: Number of entities to spawn
-- @param spawnStrategy string: Strategy for positioning ("cluster", "grid", "edge")
-- @param strategyData table: Configuration for the spawn strategy
-- @return table: Array of component data tables
function Procedural.spawnMultiple(templateName, count, spawnStrategy, strategyData)
    local entities = {}
    
    for i = 1, count do
        local spawnData = Procedural.calculateSpawnPosition(spawnStrategy, strategyData, i)
        local entityData = Procedural.generateEntity(templateName, spawnData)
        table.insert(entities, entityData)
    end
    
    return entities
end

-- Calculate spawn position based on strategy
-- @param strategy string: Spawn strategy name
-- @param data table: Strategy configuration
-- @param index number: Entity index (for grid patterns)
-- @return table: Spawn data with position
function Procedural.calculateSpawnPosition(strategy, data, index)
    local spawnData = {
        x = 0,
        y = 0,
        angle = 0
    }
    
    if strategy == "cluster" then
        -- Random position within cluster radius
        local angle = math.random() * 2 * math.pi
        local distance = math.random() * (data.radius or 100)
        spawnData.x = (data.centerX or 0) + math.cos(angle) * distance
        spawnData.y = (data.centerY or 0) + math.sin(angle) * distance
        spawnData.angle = math.random() * 2 * math.pi
    elseif strategy == "grid" then
        -- Grid pattern
        local cols = data.cols or math.ceil(math.sqrt(data.count or 1))
        local spacing = data.spacing or 100
        local row = math.floor((index - 1) / cols)
        local col = (index - 1) % cols
        spawnData.x = (data.startX or 0) + col * spacing
        spawnData.y = (data.startY or 0) + row * spacing
        spawnData.angle = math.random() * 2 * math.pi
    elseif strategy == "edge" then
        -- Spawn at screen edges
        local side = math.random(4) -- 1=top, 2=right, 3=bottom, 4=left
        local screenWidth = data.screenWidth or 1920
        local screenHeight = data.screenHeight or 1080
        
        if side == 1 then -- Top
            spawnData.x = math.random() * screenWidth
            spawnData.y = -50
        elseif side == 2 then -- Right
            spawnData.x = screenWidth + 50
            spawnData.y = math.random() * screenHeight
        elseif side == 3 then -- Bottom
            spawnData.x = math.random() * screenWidth
            spawnData.y = screenHeight + 50
        else -- Left
            spawnData.x = -50
            spawnData.y = math.random() * screenHeight
        end
        spawnData.angle = math.random() * 2 * math.pi
    end
    
    return spawnData
end

-- Generate random irregular polygon vertices
-- @param vertexCount number: Number of vertices (6-10)
-- @param baseRadius number: Base radius for the polygon
-- @return table: Array of {x, y} vertex coordinates
function Procedural.generatePolygonVertices(vertexCount, baseRadius)
    local vertices = {}
    local angleStep = (2 * math.pi) / vertexCount
    
    for i = 1, vertexCount do
        local angle = (i - 1) * angleStep
        -- Add random variation to radius (±30%)
        local radius = baseRadius * (0.7 + math.random() * 0.6)
        local x = math.cos(angle) * radius
        local y = math.sin(angle) * radius
        table.insert(vertices, {x = x, y = y})
    end
    
    return vertices
end

-- Generate random value within range
-- @param min number: Minimum value
-- @param max number: Maximum value
-- @return number: Random value between min and max
function Procedural.randomRange(min, max)
    return min + math.random() * (max - min)
end

-- Generate random velocity vector
-- @param minSpeed number: Minimum speed
-- @param maxSpeed number: Maximum speed
-- @return table: {vx, vy} velocity components
function Procedural.randomVelocity(minSpeed, maxSpeed)
    local speed = Procedural.randomRange(minSpeed, maxSpeed)
    local angle = math.random() * 2 * math.pi
    return {
        vx = math.cos(angle) * speed,
        vy = math.sin(angle) * speed
    }
end

-- Register asteroid template
function Procedural.registerAsteroidTemplate()
    Procedural.registerTemplate("asteroid", function(spawnData)
        local size = Procedural.randomRange(Constants.asteroid_size_min, Constants.asteroid_size_max)
        local vertexCount = math.random(Constants.asteroid_vertices_min, Constants.asteroid_vertices_max)
        local vertices = Procedural.generatePolygonVertices(vertexCount, size / 2)
        local velocity = Procedural.randomVelocity(Constants.asteroid_velocity_min, Constants.asteroid_velocity_max)
        local angularVelocity = Procedural.randomRange(Constants.asteroid_rotation_min, Constants.asteroid_rotation_max)
        
        return {
            Position = Components.Position(spawnData.x, spawnData.y),
            Velocity = Components.Velocity(velocity.vx, velocity.vy),
            Physics = Components.Physics(0.999, 100, 1), -- Low friction, moderate max speed
            PolygonShape = Components.PolygonShape(vertices, spawnData.angle or 0),
            AngularVelocity = Components.AngularVelocity(angularVelocity),
            Collidable = Components.Collidable(size / 2), -- Bounding radius
            Durability = Components.Durability(size * 2, size * 2),
            Asteroid = Components.Asteroid(),
            Renderable = Components.Renderable("polygon", nil, nil, nil, {0.6, 0.4, 0.2, 1}) -- Brownish color
        }
    end)
end

-- Initialize all default templates
function Procedural.init()
    Procedural.registerAsteroidTemplate()
    print("Procedural content generation system initialized")
end

return Procedural
