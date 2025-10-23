-- World/Sector Loader
-- Loads world definitions from worlds/ directory and provides factory functions

local ECS = require('src.ecs')
local Components = require('src.components')
local Constants = require('src.constants')
local Procedural = require('src.procedural')
local ShipLoader = require('src.ship_loader')
local AsteroidClusters = require('src.systems.asteroid_clusters')

local WorldLoader = {
    worlds = {},
    currentWorld = nil
}

-- Load a single world definition file
function WorldLoader.loadWorld(worldId, filepath)
    local success, world = pcall(require, filepath)
    if success and world then
        WorldLoader.worlds[worldId] = world
        print(string.format("[WorldLoader] Loaded world: %s", worldId))
        return true
    else
        print(string.format("[WorldLoader] Failed to load world: %s", worldId))
        return false
    end
end

-- Load all world definitions from a directory
function WorldLoader.loadAllWorlds(directory)
    directory = directory or "src.worlds"
    
    -- Known worlds to load
    local knownWorlds = {
        "default_sector",
        "asteroid_field",
        "mining_zone",
        "combat_sector"
    }
    
    local loadedCount = 0
    for _, worldId in ipairs(knownWorlds) do
        local filepath = directory .. "." .. worldId
        if WorldLoader.loadWorld(worldId, filepath) then
            loadedCount = loadedCount + 1
        end
    end
    
    print(string.format("[WorldLoader] Loaded %d world definitions", loadedCount))
end

-- Get a world definition by ID
function WorldLoader.getWorld(worldId)
    return WorldLoader.worlds[worldId]
end

-- Initialize a world by ID
function WorldLoader.initWorld(worldId)
    local world = WorldLoader.getWorld(worldId)
    if not world then
        error("World not found: " .. worldId)
    end
    
    WorldLoader.currentWorld = world
    
    -- Set random seed if provided
    if world.seed then
        math.randomseed(world.seed)
    end
    
    -- Initialize asteroid clusters
    if world.asteroidClusters then
        WorldLoader.initAsteroidClusters(world.asteroidClusters)
    end
    
    -- Spawn initial enemies
    if world.enemies then
        WorldLoader.spawnEnemies(world.enemies)
    end
    
    print(string.format("[WorldLoader] Initialized world: %s - %s", world.name, world.description))
end

-- Initialize asteroid clusters for a world
function WorldLoader.initAsteroidClusters(config)
    -- Clear existing clusters
    local clusters = AsteroidClusters.getClusters()
    for id, _ in pairs(clusters) do
        clusters[id] = nil
    end
    
    local nextClusterId = 1
    
    -- Create clusters based on world configuration
    for i = 1, config.count do
        local clusterConfig = config.clusters[i] or {}
        
        local clusterId = nextClusterId
        nextClusterId = nextClusterId + 1
        
        -- Use configured position or random position
        local clusterX = clusterConfig.x or (Constants.world_min_x + math.random() * (Constants.world_max_x - Constants.world_min_x))
        local clusterY = clusterConfig.y or (Constants.world_min_y + math.random() * (Constants.world_max_y - Constants.world_min_y))
        
        local cluster = {
            id = clusterId,
            centerX = clusterX,
            centerY = clusterY,
            radius = clusterConfig.radius or Constants.asteroid_cluster_radius,
            maxAsteroids = clusterConfig.maxAsteroids or Constants.asteroids_per_cluster,
            asteroids = {},
            respawnTimer = 0,
            respawnQueue = {},
        }
        
        clusters[clusterId] = cluster
        
        -- Spawn initial asteroids in cluster manually
        local count = cluster.maxAsteroids
        for j = 1, count do
            -- Random position within cluster radius
            local angle = math.random() * 2 * math.pi
            local distance = math.random() * cluster.radius
            local x = cluster.centerX + math.cos(angle) * distance
            local y = cluster.centerY + math.sin(angle) * distance
            
            local asteroidId = AsteroidClusters.createAsteroid(x, y)
            if asteroidId then
                table.insert(cluster.asteroids, asteroidId)
            end
        end
    end
    
    print(string.format("[WorldLoader] Initialized %d asteroid clusters", config.count))
end

-- Spawn enemies based on world configuration
function WorldLoader.spawnEnemies(config)
    local spawnCount = 0
    
    for enemyType, count in pairs(config.types or {}) do
        for i = 1, count do
            local shipId = WorldLoader.spawnEnemy(enemyType, config)
            if shipId then
                spawnCount = spawnCount + 1
            end
        end
    end
    
    print(string.format("[WorldLoader] Spawned %d enemies", spawnCount))
end

-- Spawn a single enemy
function WorldLoader.spawnEnemy(enemyType, config)
    -- Get random position
    local x = Constants.world_min_x + math.random() * (Constants.world_max_x - Constants.world_min_x)
    local y = Constants.world_min_y + math.random() * (Constants.world_max_y - Constants.world_min_y)
    
    -- Make sure not too close to spawn point
    local distanceFromSpawn = math.sqrt(x * x + y * y)
    if distanceFromSpawn < 500 then
        -- Too close, push it away
        local angle = math.atan2(y, x)
        x = math.cos(angle) * 500
        y = math.sin(angle) * 500
    end
    
    local shipId = ShipLoader.createShip(enemyType, x, y, "ai")
    if shipId then
        -- Configure turret
        local turret = ECS.getComponent(shipId, "Turret")
        if turret then
            local weapon = config.weapons and config.weapons[enemyType] or "basic_cannon"
            turret.moduleName = weapon
        end
        
        -- Configure AI
        local ai = ECS.getComponent(shipId, "AI")
        if ai then
            ai.type = config.aiType or "combat"
            ai.state = config.aiState or "patrol"
            local design = ShipLoader.getDesign(enemyType)
            if design then
                if design.combatDetectionRange then
                    ai.detectionRadius = design.combatDetectionRange
                end
            end
        end
    end
    
    return shipId
end

-- Get the current world
function WorldLoader.getCurrentWorld()
    return WorldLoader.currentWorld
end

return WorldLoader

