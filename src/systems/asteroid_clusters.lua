-- Asteroid Cluster Respawning System
-- Manages asteroid clusters with automatic respawning when asteroids are destroyed

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
    
    print(string.format("[AsteroidClusters] Initialized %d clusters", numClusters))
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
    local size = Procedural.randomRange(Constants.asteroid_size_min, Constants.asteroid_size_max)
    local vertexCount = math.random(Constants.asteroid_vertices_min, Constants.asteroid_vertices_max)
    local vertices = Procedural.generatePolygonVertices(vertexCount, size / 2)
    
    local asteroidMass = size * size * 0.5
    local rotationalInertia = Components.calculatePolygonInertia(vertices, asteroidMass) * 2
    
    local asteroidId = ECS.createEntity()
    ECS.addComponent(asteroidId, "Position", Components.Position(x, y))
    ECS.addComponent(asteroidId, "Velocity", Components.Velocity(0, 0))
    ECS.addComponent(asteroidId, "Physics", Components.Physics(0.999, asteroidMass, 0.985))
    ECS.addComponent(asteroidId, "PolygonShape", Components.PolygonShape(vertices, 0))
    ECS.addComponent(asteroidId, "AngularVelocity", Components.AngularVelocity(0))
    ECS.addComponent(asteroidId, "RotationalMass", Components.RotationalMass(rotationalInertia))
    ECS.addComponent(asteroidId, "Collidable", Components.Collidable(size / 2))
    ECS.addComponent(asteroidId, "Durability", Components.Durability(size * 2, size * 2))
    
    -- Determine asteroid type
    -- Change: no standalone "crystal" asteroid. Instead iron asteroids can rarely have crystal formations.
    local asteroidType = "stone"
    local rand = math.random()
    if rand < 0.55 then
        asteroidType = "iron"
    else
        asteroidType = "stone"
    end

    -- Small chance (e.g. 5%) that an iron asteroid has crystal formations
    local crystalFormation = false
    if asteroidType == "iron" and math.random() < 0.05 then
        crystalFormation = true
    end

    -- Set XP reward based on asteroid type
    local xpReward = nil  -- Default (uses SkillXP calculation)
    if asteroidType == "iron" then
        xpReward = 18  -- Iron asteroids give 18 XP
    end

    ECS.addComponent(asteroidId, "Asteroid", Components.Asteroid(asteroidType, crystalFormation, xpReward))
    
    -- Different colors for different asteroid types
    local color
    if asteroidType == "iron" then
        color = {0.6, 0.4, 0.2, 1}  -- Brown iron asteroid
    else
        color = {0.5, 0.5, 0.5, 1}  -- Gray stone asteroid
    end
    ECS.addComponent(asteroidId, "Renderable", Components.Renderable("polygon", nil, nil, nil, color))
    
    -- If this asteroid has a crystal formation flag, spawn an attached formation at one of its outer vertices
    if crystalFormation then
        -- Pick a random vertex from the polygon (vertices are local to asteroid)
        local poly = ECS.getComponent(asteroidId, "PolygonShape")
        if poly and poly.vertices and #poly.vertices > 0 then
            local v = poly.vertices[math.random(#poly.vertices)]
            print(string.format("[CrystalFormation] Creating formation at asteroid (%f, %f), vertex offset (%f, %f)", x, y, v.x, v.y))
            -- Create formation entity
            local formId = ECS.createEntity()
            -- Compute an initial world position for the formation
            local posComp = Components.Position(x + v.x, y + v.y)
            ECS.addComponent(formId, "Position", posComp)
            ECS.addComponent(formId, "Collidable", Components.Collidable(6))
            ECS.addComponent(formId, "Durability", Components.Durability(8, 8)) -- small HP to mine off
            -- Add CrystalFormation marker with visual params
            ECS.addComponent(formId, "CrystalFormation", Components.CrystalFormation(12, 5, {0.7, 0.5, 1, 1}))
            -- Add small polygon shape so mining lasers (which check polygons) can hit the formation
            local formVerts = Procedural.generatePolygonVertices(6, 8)
            ECS.addComponent(formId, "PolygonShape", Components.PolygonShape(formVerts, 0))
            ECS.addComponent(formId, "Attached", Components.Attached(asteroidId, v.x, v.y))
            print(string.format("[CrystalFormation] Formation entity created with ID %d", formId))
        end
    end
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

return AsteroidClusters
