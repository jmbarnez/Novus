-- Enhanced Asteroid Cluster Respawning System
-- Manages asteroid clusters with automatic respawning when asteroids are destroyed
--
-- Features:
-- - Three asteroid types: Stone (50%), Iron (35%), Crystal (15%)
-- - Enhanced visual design with realistic colors and multi-layer rendering
-- - Crystal asteroids have animated sparkle effects and glow
-- - Varied physics properties based on asteroid type
-- - Enhanced XP rewards for rare asteroid types
-- - Realistic mineral-based color variations for stone asteroids

local Constants = require('src.constants')
local ECS = require('src.ecs')
local Components = require('src.components')
local Procedural = require('src.procedural')

local AsteroidClusters = {}

-- Cluster data structure
local clusters = {}
local nextClusterId = 1

-- Initialize clusters with spawning
function AsteroidClusters.init()
    clusters = {}
    nextClusterId = 1
    
    -- Calculate cluster positions distributed across the world
    local numClusters = Constants.asteroid_num_clusters
    local worldWidth = Constants.world_max_x - Constants.world_min_x
    local worldHeight = Constants.world_max_y - Constants.world_min_y
    local spacing = worldWidth / (numClusters + 1)
    
    for i = 1, numClusters do
        local clusterX = Constants.world_min_x + spacing * i + (math.random() - 0.5) * 500
        local clusterY = (math.random() - 0.5) * worldHeight * 0.6  -- Don't go too far to edges
        
        -- Clamp to world bounds
        clusterX = math.max(Constants.world_min_x + 500, math.min(Constants.world_max_x - 500, clusterX))
        clusterY = math.max(Constants.world_min_y + 500, math.min(Constants.world_max_y - 500, clusterY))
        
        local clusterId = nextClusterId
        nextClusterId = nextClusterId + 1
        
        clusters[clusterId] = {
            id = clusterId,
            centerX = clusterX,
            centerY = clusterY,
            radius = Constants.asteroid_cluster_radius,
            maxAsteroids = Constants.asteroids_per_cluster,
            asteroids = {},  -- List of asteroid entity IDs
            respawnTimer = 0,
            respawnQueue = {},  -- Asteroids waiting to respawn
        }
        
        -- Spawn initial asteroids in cluster
        AsteroidClusters.spawnCluster(clusterId)
    end
end

-- Spawn asteroids in a cluster
function AsteroidClusters.spawnCluster(clusterId)
    local cluster = clusters[clusterId]
    if not cluster then return end
    
    local count = cluster.maxAsteroids
    local spawnedPositions = {}  -- Track positions for collision avoidance
    local minDistance = 150  -- Minimum distance between asteroid centers
    
    for i = 1, count do
        local maxAttempts = 20
        local attempts = 0
        local validPosition = false
        local x, y
        
        while attempts < maxAttempts and not validPosition do
            -- Random position within cluster radius
            local angle = math.random() * 2 * math.pi
            local distance = math.random() * cluster.radius
            x = cluster.centerX + math.cos(angle) * distance
            y = cluster.centerY + math.sin(angle) * distance
            
            -- Check collision with existing asteroids
            validPosition = true
            for _, pos in ipairs(spawnedPositions) do
                local dx = x - pos.x
                local dy = y - pos.y
                local dist = math.sqrt(dx * dx + dy * dy)
                
                if dist < minDistance then
                    validPosition = false
                    break
                end
            end
            
            attempts = attempts + 1
        end
        
        -- Only spawn if we found a valid position
        if validPosition then
            local asteroidId = AsteroidClusters.createAsteroid(x, y)
            if asteroidId then
                table.insert(cluster.asteroids, asteroidId)
                table.insert(spawnedPositions, {x = x, y = y})
            end
        end
    end
end

-- Create a single asteroid
function AsteroidClusters.createAsteroid(x, y)
    -- Enhanced asteroid type determination with crystal asteroids
    local asteroidType = "stone"
    local rand = math.random()

    -- Stone: 50% (most common)
    -- Iron: 35% (valuable)
    -- Crystal: 15% (rare and valuable)
    if rand < 0.15 then
        asteroidType = "crystal"
    elseif rand < 0.5 then
        asteroidType = "iron"
    else
        asteroidType = "stone"
    end

    local size = Procedural.randomRange(Constants.asteroid_size_min, Constants.asteroid_size_max)

    -- Vary size based on asteroid type for more visual distinction
    local sizeMultiplier = 1.0
    if asteroidType == "crystal" then
        sizeMultiplier = 0.8 + math.random() * 0.4  -- 0.8-1.2x (slightly smaller but denser)
    elseif asteroidType == "iron" then
        sizeMultiplier = 0.9 + math.random() * 0.3  -- 0.9-1.2x (medium variation)
    else -- stone
        sizeMultiplier = 0.7 + math.random() * 0.6  -- 0.7-1.3x (wide variation)
    end
    size = size * sizeMultiplier

    local vertexCount = math.random(Constants.asteroid_vertices_min, Constants.asteroid_vertices_max)

    -- Vary vertex count based on type for different shapes
    if asteroidType == "crystal" then
        vertexCount = math.random(6, 8)  -- More regular, geometric shapes for crystals
    elseif asteroidType == "iron" then
        vertexCount = math.random(7, 10)  -- Medium irregularity
    else -- stone
        vertexCount = math.random(Constants.asteroid_vertices_min, Constants.asteroid_vertices_max)  -- Full range
    end

    local vertices = Procedural.generatePolygonVertices(vertexCount, size / 2)

    local asteroidMass = size * size * 0.5
    local rotationalInertia = Components.calculatePolygonInertia(vertices, asteroidMass) * 2

    -- Adjust physics properties based on asteroid type
    local friction = 0.999
    local angularDamping = 0.985
    local durabilityMultiplier = 1.0

    if asteroidType == "crystal" then
        durabilityMultiplier = 1.5  -- Crystals are harder to break
        angularDamping = 0.99  -- Crystals rotate slower (more stable)
    elseif asteroidType == "iron" then
        durabilityMultiplier = 1.2  -- Iron is denser
        friction = 0.998  -- Iron asteroids have slightly less friction
    else -- stone
        durabilityMultiplier = 1.0  -- Standard stone
    end

    local asteroidId = ECS.createEntity()
    ECS.addComponent(asteroidId, "Position", Components.Position(x, y))
    ECS.addComponent(asteroidId, "Velocity", Components.Velocity(0, 0))
    ECS.addComponent(asteroidId, "Physics", Components.Physics(friction, asteroidMass, angularDamping))
    ECS.addComponent(asteroidId, "PolygonShape", Components.PolygonShape(vertices, 0))
    ECS.addComponent(asteroidId, "AngularVelocity", Components.AngularVelocity(0))
    ECS.addComponent(asteroidId, "RotationalMass", Components.RotationalMass(rotationalInertia))
    ECS.addComponent(asteroidId, "Collidable", Components.Collidable(size / 2))
    ECS.addComponent(asteroidId, "Durability", Components.Durability(size * 2 * durabilityMultiplier, size * 2 * durabilityMultiplier))

    -- Set XP reward based on asteroid type
    local xpReward = nil  -- Default (uses SkillXP calculation)
    if asteroidType == "iron" then
        xpReward = 18  -- Iron asteroids give 18 XP
    elseif asteroidType == "crystal" then
        xpReward = 35  -- Crystal asteroids give 35 XP (rare and valuable)
    end

    -- Create crystal formation data for crystal asteroids
    local crystalFormation = nil
    if asteroidType == "crystal" then
        crystalFormation = {
            crystals = {},
            glowIntensity = 0.3 + math.random() * 0.4, -- 0.3-0.7 glow intensity
            formationType = math.random(1, 3), -- Different crystal formations
        }
    end

    ECS.addComponent(asteroidId, "Asteroid", Components.Asteroid(asteroidType, crystalFormation, xpReward))

    -- Enhanced colors for different asteroid types
    local baseColor, accentColor, shadowColor

    if asteroidType == "crystal" then
        -- Crystal asteroids: purple/magenta with glow
        local hue = 0.7 + math.random() * 0.1  -- Purple to magenta range
        local sat = 0.6 + math.random() * 0.3  -- High saturation
        local brightness = 0.7 + math.random() * 0.2  -- Bright crystals

        -- Convert HSV to RGB (simplified)
        baseColor = {hue * sat * brightness, (1 - hue) * sat * brightness, brightness, 1}
        accentColor = {math.min(1, baseColor[1] + 0.3), math.min(1, baseColor[2] + 0.3), math.min(1, baseColor[3] + 0.3), 0.8}
        shadowColor = {baseColor[1] * 0.4, baseColor[2] * 0.4, baseColor[3] * 0.4, 0.7}

    elseif asteroidType == "iron" then
        -- Enhanced iron asteroids: rich metallic browns and oranges
        local rustFactor = 0.3 + math.random() * 0.4  -- Vary the rust level
        baseColor = {
            0.5 + rustFactor * 0.3,  -- Red component (more rust = more red)
            0.3 + rustFactor * 0.2,  -- Green component
            0.1 + rustFactor * 0.15, -- Blue component (less blue = more rust)
            1
        }
        accentColor = {math.min(1, baseColor[1] + 0.25), math.min(1, baseColor[2] + 0.2), math.min(1, baseColor[3] + 0.1), 0.6}
        shadowColor = {baseColor[1] * 0.5, baseColor[2] * 0.5, baseColor[3] * 0.5, 0.8}

    else -- stone
        -- Enhanced stone asteroids: varied gray with mineral streaks
        local mineralType = math.random(1, 4)
        if mineralType == 1 then
            -- Quartz-like stone (slightly blue-gray)
            baseColor = {0.45, 0.48, 0.55, 1}
        elseif mineralType == 2 then
            -- Granite-like stone (warm gray)
            baseColor = {0.5, 0.45, 0.4, 1}
        elseif mineralType == 3 then
            -- Shale-like stone (darker gray)
            baseColor = {0.35, 0.38, 0.42, 1}
        else
            -- Feldspar-like stone (slightly pink-gray)
            baseColor = {0.5, 0.45, 0.48, 1}
        end

        accentColor = {math.min(1, baseColor[1] + 0.2), math.min(1, baseColor[2] + 0.2), math.min(1, baseColor[3] + 0.2), 0.5}
        shadowColor = {baseColor[1] * 0.6, baseColor[2] * 0.6, baseColor[3] * 0.6, 0.7}
    end

    -- Enhanced renderable with multi-layer coloring for depth
    ECS.addComponent(asteroidId, "Renderable", Components.Renderable("polygon", nil, nil, nil, {
        stripes = baseColor,
        accent = accentColor,
        shadow = shadowColor,
        detail = asteroidType == "crystal" and {1, 1, 1, 0.3} or {0.8, 0.8, 0.8, 0.4}
    }))

    return asteroidId
end

-- Mark asteroid for respawning when destroyed
function AsteroidClusters.markForRespawn(asteroidId, clusterData)
    if clusterData and clusterData.respawnQueue then
        table.insert(clusterData.respawnQueue, {
            clusterId = clusterData.id,
            spawnTime = 0,
        })
    end
end

-- Update clusters (handle respawning)
function AsteroidClusters.update(dt)
    for clusterId, cluster in pairs(clusters) do
        -- Update respawn timer
        cluster.respawnTimer = cluster.respawnTimer + dt
        
        -- Clean up destroyed asteroids from the list
        local validAsteroids = {}
        for _, asteroidId in ipairs(cluster.asteroids) do
            if ECS.getComponent(asteroidId, "Position") then
                table.insert(validAsteroids, asteroidId)
            end
        end
        cluster.asteroids = validAsteroids
        
        -- Check if we need to respawn asteroids
        if cluster.respawnTimer >= Constants.cluster_respawn_interval then
            cluster.respawnTimer = 0
            
            -- Respawn queue items
            local stillWaiting = {}
            for _, item in ipairs(cluster.respawnQueue) do
                item.spawnTime = item.spawnTime + Constants.cluster_respawn_interval
                
                if item.spawnTime >= Constants.cluster_respawn_delay then
                    -- Time to spawn!
                    local asteroidCount = #cluster.asteroids
                    if asteroidCount < cluster.maxAsteroids then
                        -- Collision check against existing asteroids
                        local minDistance = 150
                        local maxAttempts = 20
                        local attempts = 0
                        local validPosition = false
                        local x, y
                        
                        while attempts < maxAttempts and not validPosition do
                            local angle = math.random() * 2 * math.pi
                            local distance = math.random() * cluster.radius
                            x = cluster.centerX + math.cos(angle) * distance
                            y = cluster.centerY + math.sin(angle) * distance
                            
                            validPosition = true
                            for _, asteroidId in ipairs(cluster.asteroids) do
                                local pos = ECS.getComponent(asteroidId, "Position")
                                if pos then
                                    local dx = x - pos.x
                                    local dy = y - pos.y
                                    local dist = math.sqrt(dx * dx + dy * dy)
                                    
                                    if dist < minDistance then
                                        validPosition = false
                                        break
                                    end
                                end
                            end
                            
                            attempts = attempts + 1
                        end
                        
                        if validPosition then
                            -- Respawn asteroids maintain the same type distribution as initial spawn
                            local newAsteroidId = AsteroidClusters.createAsteroid(x, y)
                            if newAsteroidId then
                                table.insert(cluster.asteroids, newAsteroidId)
                            end
                        end
                    end
                else
                    -- Still waiting
                    table.insert(stillWaiting, item)
                end
            end
            cluster.respawnQueue = stillWaiting
        end
    end
end

-- Get cluster data by ID
function AsteroidClusters.getCluster(clusterId)
    return clusters[clusterId]
end

-- Get all clusters
function AsteroidClusters.getClusters()
    return clusters
end

-- Get cluster containing an asteroid (if it exists in respawn system)
function AsteroidClusters.getClusterForAsteroid(asteroidId)
    for clusterId, cluster in pairs(clusters) do
        for _, id in ipairs(cluster.asteroids) do
            if id == asteroidId then
                return cluster
            end
        end
    end
    return nil
end

function AsteroidClusters.clear()
    clusters = {}
    nextClusterId = 1
end

function AsteroidClusters.serialize()
    local data = {
        nextClusterId = nextClusterId,
        clusters = {}
    }

    for id, cluster in pairs(clusters) do
        local clusterCopy = {
            id = cluster.id,
            centerX = cluster.centerX,
            centerY = cluster.centerY,
            radius = cluster.radius,
            maxAsteroids = cluster.maxAsteroids,
            respawnTimer = cluster.respawnTimer,
            asteroids = {},
            respawnQueue = {}
        }

        for _, asteroidId in ipairs(cluster.asteroids or {}) do
            table.insert(clusterCopy.asteroids, asteroidId)
        end

        for _, entry in ipairs(cluster.respawnQueue or {}) do
            table.insert(clusterCopy.respawnQueue, {
                clusterId = entry.clusterId,
                spawnTime = entry.spawnTime,
            })
        end

        data.clusters[id] = clusterCopy
    end

    return data
end

function AsteroidClusters.deserialize(data)
    AsteroidClusters.clear()
    if not data then return end

    nextClusterId = data.nextClusterId or nextClusterId

    for id, clusterData in pairs(data.clusters or {}) do
        local cluster = {
            id = clusterData.id or id,
            centerX = clusterData.centerX,
            centerY = clusterData.centerY,
            radius = clusterData.radius,
            maxAsteroids = clusterData.maxAsteroids,
            respawnTimer = clusterData.respawnTimer or 0,
            asteroids = {},
            respawnQueue = {}
        }

        for _, asteroidId in ipairs(clusterData.asteroids or {}) do
            table.insert(cluster.asteroids, asteroidId)
        end

        for _, entry in ipairs(clusterData.respawnQueue or {}) do
            table.insert(cluster.respawnQueue, {
                clusterId = entry.clusterId,
                spawnTime = entry.spawnTime,
            })
        end

        clusters[id] = cluster
    end
end

return AsteroidClusters
