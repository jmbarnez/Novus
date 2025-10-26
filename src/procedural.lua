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

-- Spawn multiple entities using a template with collision avoidance
-- @param templateName string: Name of the template to use
-- @param count number: Number of entities to spawn
-- @param spawnStrategy string: Strategy for positioning ("cluster", "grid", "edge")
-- @param strategyData table: Configuration for the spawn strategy
-- @return table: Array of component data tables
function Procedural.spawnMultiple(templateName, count, spawnStrategy, strategyData)
    local SpawnCollisionUtils = require('src.spawn_collision_utils')
    local entities = {}
    local entityRadius = 30  -- Default collision radius for spawned entities
    local minDistance = 150  -- Minimum distance between entity centers
    
    for i = 1, count do
        local spawnData = Procedural.calculateSpawnPosition(spawnStrategy, strategyData, i)
        local maxAttempts = 20  -- Try up to 20 times to find a valid spawn position
        local attempts = 0
        local validPosition = false
        
        while attempts < maxAttempts and not validPosition do
            -- Use universal collision detection to check if position is safe
            validPosition = SpawnCollisionUtils.isPositionSafe(
                spawnData.x, 
                spawnData.y, 
                entityRadius, 
                minDistance, 
                {}  -- no excluded types
            )
            
            -- If position is invalid, try a new random position
            if not validPosition then
                spawnData = Procedural.calculateSpawnPosition(spawnStrategy, strategyData, i)
                attempts = attempts + 1
            end
        end
        
        -- Only add entity if we found a valid position
        if validPosition then
            local entityData = Procedural.generateEntity(templateName, spawnData)
            table.insert(entities, entityData)
        end
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
        local Constants = require('src.constants')
        local screenWidth = data.screenWidth or Constants.getScreenWidth()
        local screenHeight = data.screenHeight or Constants.getScreenHeight()
        
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
        
        -- Heavy asteroid mass based on size (much heavier - not easily pushed)
        -- Density scales cubically with size for realistic mass
        local asteroidMass = size * size * 0.25  -- Halved mass (previously 0.5)
        
        -- Calculate realistic rotational inertia based on actual polygon shape
        local rotationalInertia = Components.calculatePolygonInertia(vertices, asteroidMass)
        -- Asteroids are extra resistant to rotation (multiply by 2)
        rotationalInertia = rotationalInertia * 2
        
        -- Determine asteroid type
        -- Change: do not create standalone crystal asteroids. Iron asteroids may rarely host crystal formations.
        local asteroidType = "stone"
        local rand = math.random()
        if rand < 0.55 then
            asteroidType = "iron"
        else
            asteroidType = "stone"
        end
        local crystalFormation = false
        if asteroidType == "iron" and math.random() < 0.05 then
            crystalFormation = true
        end
        
        -- Different colors for different asteroid types
        local color
        if asteroidType == "iron" and crystalFormation then
            color = {0.65, 0.45, 0.6, 1}  -- Iron with crystal tint
        elseif asteroidType == "iron" then
            color = {0.6, 0.4, 0.2, 1}  -- Brown iron asteroid
        else
            color = {0.5, 0.5, 0.5, 1}  -- Gray stone asteroid
        end
        
        -- Set XP reward based on asteroid type
        local xpReward = nil  -- Default (uses SkillXP calculation)
        if asteroidType == "iron" then
            xpReward = 18  -- Iron asteroids give 18 XP
        end
        
        return {
            Position = Components.Position(spawnData.x, spawnData.y),
            Velocity = Components.Velocity(velocity.vx, velocity.vy),
            Physics = Components.Physics(0.999, asteroidMass, 0.985), -- Low friction, HEAVY mass, minimal rotation damping
            PolygonShape = Components.PolygonShape(vertices, spawnData.angle or 0),
            AngularVelocity = Components.AngularVelocity(angularVelocity),
            RotationalMass = Components.RotationalMass(rotationalInertia), -- Calculated from shape - hard to spin
            Collidable = Components.Collidable(size / 2), -- Bounding radius
            Durability = Components.Durability(size * 2, size * 2),
            Asteroid = Components.Asteroid(asteroidType, crystalFormation, xpReward),
            Renderable = Components.Renderable("polygon", nil, nil, nil, color)
        }
    end)
end

-- Register warp gate template
Procedural.registerTemplate("warp_gate", function(spawnData)
    local x = spawnData.x or 0
    local y = spawnData.y or 0
    local active = (spawnData.warpGateData and spawnData.warpGateData.active) or spawnData.active or false
    return {
        Position = Components.Position(x, y),
        Renderable = Components.Renderable("circle", nil, nil, 80, active and {0.2, 0.5, 1, 0.28} or {0.88,0.18,0.18,0.28}),
        Collidable = Components.Collidable(80),
        WarpGate = Components.WarpGate({active=active, destination = spawnData.destination}),
    }
end)

-- Register station template
Procedural.registerTemplate("station", function(spawnData)
    local x = spawnData.x or 0
    local y = spawnData.y or 0
    local size = spawnData.size or 120 -- Large space station radius
    local mass = spawnData.mass or 1500
    local color = spawnData.color or {0.8, 0.8, 0.95, 1} -- Pale blue-gray
    local label = spawnData.label -- for on-map station names
    
    local detail = spawnData.detail or {}
    
    -- Polygon hull helpers
    local function regularPolygon(sides, radius)
        local verts = {}
        local angleStep = (2 * math.pi) / sides
        for i = 1, sides do
            local angle = (i-1) * angleStep
            table.insert(verts, {x = math.cos(angle) * radius, y = math.sin(angle) * radius})
        end
        return verts
    end

    local function buildStationDetails(hullRadius, detailDef)
        local parts = {}
        if not detailDef then return parts end

        local function add(part)
            if part then
                table.insert(parts, part)
            end
        end

        if detailDef.modules then
            for _, module in ipairs(detailDef.modules) do
                local moduleType = module.type or module.kind
                if moduleType == "ring" then
                    add({
                        type = "ring",
                        radius = module.radius or hullRadius,
                        width = module.width or module.thickness or 10,
                        color = module.color or {0.68, 0.82, 1, 0.32},
                        spinSpeed = module.spinSpeed
                    })
                elseif moduleType == "disc" or moduleType == "core" then
                    add({
                        type = "circle",
                        radius = module.radius or (hullRadius * 0.3),
                        color = module.color or {1, 1, 1, 0.3},
                        spinSpeed = module.spinSpeed
                    })
                elseif moduleType == "spokes" then
                    local count = module.count or 4
                    local inner = module.innerRadius or (hullRadius * 0.2)
                    local outer = module.outerRadius or hullRadius
                    local width = module.width or 8
                    local offset = module.angleOffset or 0
                    local len = outer - inner
                    for i = 1, count do
                        local angle = offset + (i - 1) * ((2 * math.pi) / count)
                        add({
                            type = "rect",
                            x = math.cos(angle) * (inner + len / 2),
                            y = math.sin(angle) * (inner + len / 2),
                            width = len,
                            height = width,
                            rot = angle,
                            color = module.color or {0.75, 0.85, 1, 0.35},
                            spinSpeed = module.spinSpeed
                        })
                    end
                elseif moduleType == "arms" then
                    local count = module.count or 3
                    local radius = module.radius or (hullRadius + 12)
                    local length = module.length or 40
                    local width = module.width or 12
                    local offset = module.angleOffset or 0
                    for i = 1, count do
                        local angle = offset + (i - 1) * ((2 * math.pi) / count)
                        add({
                            type = "rect",
                            x = math.cos(angle) * radius,
                            y = math.sin(angle) * radius,
                            width = length,
                            height = width,
                            rot = angle,
                            color = module.color or {0.6, 0.75, 0.95, 0.5},
                            spinSpeed = module.spinSpeed
                        })
                        if module.capRadius then
                            local tipDistance = radius + (module.capOffset or (length / 2))
                            add({
                                type = "circle",
                                x = math.cos(angle) * tipDistance,
                                y = math.sin(angle) * tipDistance,
                                radius = module.capRadius,
                                color = module.capColor or module.color or {0.6, 0.75, 0.95, 0.5}
                            })
                        end
                    end
                elseif moduleType == "panels" then
                    local count = module.count or 4
                    local radius = module.radius or (hullRadius + 18)
                    local width = module.width or 48
                    local height = module.height or 14
                    local offset = module.angleOffset or 0
                    for i = 1, count do
                        local angle = offset + (i - 1) * ((2 * math.pi) / count)
                        add({
                            type = "rect",
                            x = math.cos(angle) * radius,
                            y = math.sin(angle) * radius,
                            width = width,
                            height = height,
                            rot = angle,
                            color = module.color or {0.3, 0.7, 1, 0.46},
                            spinSpeed = module.spinSpeed
                        })
                    end
                elseif moduleType == "pods" then
                    local count = module.count or 4
                    local radius = module.radius or (hullRadius + 40)
                    local sides = module.sides or 6
                    local podRadius = module.podRadius or (radius * 0.08)
                    local offset = module.angleOffset or 0
                    local rotationOffset = module.rotationOffset or 0
                    for i = 1, count do
                        local angle = offset + (i - 1) * ((2 * math.pi) / count)
                        local px = math.cos(angle) * radius
                        local py = math.sin(angle) * radius
                        add({
                            type = "polygon",
                            x = px,
                            y = py,
                            rot = angle + rotationOffset,
                            color = module.color or {0.7, 0.85, 1, 0.5},
                            vertices = regularPolygon(sides, podRadius),
                            spinSpeed = module.spinSpeed
                        })
                        if module.glow then
                            add({
                                type = "glow",
                                x = px,
                                y = py,
                                radius = module.glow.radius or (podRadius * 1.2),
                                color = module.glow.color or module.color or {0.7, 0.85, 1, 0.25}
                            })
                        end
                    end
                elseif moduleType == "light_ring" or moduleType == "lights" or moduleType == "beacons" then
                    local count = module.count or 10
                    local radius = module.radius or (hullRadius + 20)
                    local size = module.size or 6
                    local offset = module.angleOffset or 0
                    for i = 1, count do
                        local angle = offset + (i - 1) * ((2 * math.pi) / count)
                        add({
                            type = "glow",
                            x = math.cos(angle) * radius,
                            y = math.sin(angle) * radius,
                            radius = size,
                            color = module.color or {1, 1, 1, 0.35}
                        })
                    end
                elseif moduleType == "dish" or moduleType == "radar" then
                    add({
                        type = "arc",
                        radius = module.radius or (hullRadius * 0.6),
                        startAngle = module.startAngle or -0.4,
                        endAngle = module.endAngle or 0.4,
                        width = module.width or 3,
                        color = module.color or {0.9, 0.95, 1, 0.55},
                        spinSpeed = module.spinSpeed or 0.6
                    })
                    add({
                        type = "rect",
                        width = module.mastLength or 22,
                        height = module.mastWidth or 6,
                        rot = module.mastAngle or 0,
                        color = module.mastColor or module.color or {0.75, 0.8, 0.95, 0.6}
                    })
                    if module.capRadius then
                        add({
                            type = "circle",
                            radius = module.capRadius,
                            color = module.capColor or module.color or {0.9, 0.95, 1, 0.5}
                        })
                    end
                elseif moduleType == "antenna" then
                    add({
                        type = "line",
                        rot = module.angle or 0,
                        x1 = 0,
                        y1 = 0,
                        x2 = module.length or (hullRadius * 0.75),
                        y2 = 0,
                        width = module.width or 2,
                        color = module.color or {0.9, 0.95, 1, 0.7},
                        spinSpeed = module.spinSpeed
                    })
                elseif moduleType == "shield" then
                    add({
                        type = "glow",
                        radius = module.radius or (hullRadius * 1.3),
                        color = module.color or {0.5, 0.7, 1, 0.2}
                    })
                elseif moduleType == "core_glow" then
                    add({
                        type = "glow",
                        radius = module.radius or (hullRadius * 0.35),
                        color = module.color or {1, 1, 1, 0.3}
                    })
                end
            end
        end

        -- Legacy field support for older configs
        if detailDef.habitatRing then
            add({
                type = "ring",
                radius = detailDef.habitatRing.radius or (hullRadius - 12),
                color = detailDef.habitatRing.color or {0.7, 0.7, 1, 0.16},
                width = detailDef.habitatRing.width or 12
            })
        end
        if detailDef.solarPanels then
            local c = detailDef.solarPanels.count or 4
            local angleStep = 2 * math.pi / c
            for i = 1, c do
                local angle = (i - 1) * angleStep
                add({
                    type = "rect",
                    x = math.cos(angle) * (detailDef.solarPanels.radius or (hullRadius + 40)),
                    y = math.sin(angle) * (detailDef.solarPanels.radius or (hullRadius + 40)),
                    width = detailDef.solarPanels.width or 50,
                    height = detailDef.solarPanels.height or 12,
                    rot = angle,
                    color = detailDef.solarPanels.color or {0.2, 0.7, 1, 0.28}
                })
            end
        end
        if detailDef.core then
            add({
                type = "circle",
                radius = detailDef.core.radius or (hullRadius * 0.28),
                color = detailDef.core.color or {1, 1, 1, 0.25}
            })
        end
        if detailDef.spokes and not detailDef.modules then
            local c = detailDef.spokes.count or 4
            local inner = detailDef.spokes.innerRadius or (hullRadius * 0.2)
            local outer = detailDef.spokes.outerRadius or (hullRadius * 0.95)
            local w = detailDef.spokes.width or 8
            local angleStep = 2 * math.pi / c
            for i = 1, c do
                local a = (i - 1) * angleStep
                local len = outer - inner
                add({
                    type = "rect",
                    x = math.cos(a) * (inner + len / 2),
                    y = math.sin(a) * (inner + len / 2),
                    width = len,
                    height = w,
                    rot = a,
                    color = detailDef.spokes.color or {0.75, 0.8, 0.95, 0.35}
                })
            end
        end
        if detailDef.dockingArms and not detailDef.modules then
            local c = detailDef.dockingArms.count or 3
            local radius = detailDef.dockingArms.radius or (hullRadius + 10)
            local len = detailDef.dockingArms.length or 40
            local w = detailDef.dockingArms.width or 12
            local offset = detailDef.dockingArms.angleOffset or 0
            local angleStep = 2 * math.pi / c
            for i = 1, c do
                local a = offset + (i - 1) * angleStep
                add({
                    type = "rect",
                    x = math.cos(a) * radius,
                    y = math.sin(a) * radius,
                    width = len,
                    height = w,
                    rot = a,
                    color = detailDef.dockingArms.color or {0.6, 0.75, 0.95, 0.5}
                })
            end
        end
        if detailDef.lights and not detailDef.modules then
            local c = detailDef.lights.count or 8
            local r = detailDef.lights.radius or (hullRadius + 16)
            local col = detailDef.lights.color or {1, 1, 1, 0.35}
            local angleStep = 2 * math.pi / c
            for i = 1, c do
                local a = (i - 1) * angleStep
                add({
                    type = "glow",
                    x = math.cos(a) * r,
                    y = math.sin(a) * r,
                    radius = detailDef.lights.size or 6,
                    color = col
                })
            end
        end
        if detailDef.radar and not detailDef.modules then
            local r = detailDef.radar.radius or (hullRadius * 0.6)
            add({
                type = "arc",
                radius = r,
                startAngle = detailDef.radar.startAngle or -0.4,
                endAngle = detailDef.radar.endAngle or 0.4,
                width = detailDef.radar.width or 3,
                color = detailDef.radar.color or {0.9, 0.95, 1, 0.55},
                spinSpeed = detailDef.radar.spinSpeed or 0.6
            })
            add({
                type = "rect",
                width = (detailDef.radar.mastLength or 22),
                height = (detailDef.radar.mastWidth or 6),
                rot = detailDef.radar.mastAngle or 0,
                color = detailDef.radar.mastColor or {0.75, 0.8, 0.95, 0.6}
            })
        end
        if detailDef.antenna and not detailDef.modules then
            local a = detailDef.antenna.angle or 0
            local len = detailDef.antenna.length or (hullRadius * 0.8)
            local w = detailDef.antenna.width or 2
            add({
                type = "line",
                rot = a,
                x1 = 0,
                y1 = 0,
                x2 = len,
                y2 = 0,
                width = w,
                color = detailDef.antenna.color or {0.9, 0.95, 1, 0.7}
            })
        end

        return parts
    end

    local hullSides = detail.hullSides or spawnData.hullSides or 8
    local hullRadius = detail.hullRadius or size
    local verts = regularPolygon(hullSides, hullRadius)
    local inertia = Components.calculatePolygonInertia(verts, mass)

    -- Compose details for rendering system
    local drawDetails = buildStationDetails(hullRadius, detail)
    -- Only the main base polygon/shape gets physics, collidable, etc!
    return {
        Position = Components.Position(x, y),
        Velocity = Components.Velocity(0, 0),  -- Static station with zero velocity
        Physics = Components.Physics(0.995, mass, 0.999),
        PolygonShape = Components.PolygonShape(verts, detail.hullRotation or 0),
        RotationalMass = Components.RotationalMass(inertia),
        Collidable = Components.Collidable(detail.collidableRadius or hullRadius),
        Renderable = Components.Renderable("polygon", nil, nil, nil, detail.hullColor or color),
        Station = Components.Station(),  -- Explicit station marker
        StationDetails = drawDetails,
        StationLabel = label and {label} or nil,
        FloatingQuestionMark = detail.disableQuestionMark and nil or Components.FloatingQuestionMark(12, 1.5, {1, 1, 0.2, 0.9}),
    }
end)

-- Initialize all default templates
function Procedural.init()
    Procedural.registerAsteroidTemplate()
    -- ...existing code...
end

return Procedural
