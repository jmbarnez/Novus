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
    currentWorld = nil,
    currentWorldId = nil
}

-- Load a single world definition file
function WorldLoader.loadWorld(worldId, filepath)
    local success, world = pcall(require, filepath)
    if success and world then
        WorldLoader.worlds[worldId] = world
        return true
    else
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
    WorldLoader.currentWorldId = worldId
    
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
    
    -- Spawn warp gate at left boundary (visible in every world; use for demo)
    local gateX = Constants.world_min_x + 120
    local gateY = 0
    local gateComponents = require('src.procedural').generateEntity('warp_gate', {x = gateX, y = gateY, active = false})
    local ecs = require('src.ecs')
    local gateId = ecs.createEntity()
    for componentType, componentData in pairs(gateComponents) do
        ecs.addComponent(gateId, componentType, componentData)
    end
    
    -- Spawn stations if specified in world
    if world.stations then
        local SpawnCollisionUtils = require('src.spawn_collision_utils')
        
        -- Clear collision registry for fresh start
        SpawnCollisionUtils.clearRegistry()
        
        -- Register existing entities in collision system
        local existingEntities = ECS.getEntitiesWith({"Position", "Collidable"})
        for _, entityId in ipairs(existingEntities) do
            local pos = ECS.getComponent(entityId, "Position")
            local coll = ECS.getComponent(entityId, "Collidable")
            if pos and coll then
                SpawnCollisionUtils.registerEntity(entityId, pos.x, pos.y, coll.radius, "existing")
            end
        end
        
        -- Find safe position for station using universal collision detection
        local stationDef = world.stations[1]  -- Only one station for now
        local stationRadius = 120  -- Station collision radius
        local minDistance = 350   -- Minimum distance from other objects
        
        local x, y, success = SpawnCollisionUtils.findSafePositionInWorld(
            stationRadius, 
            minDistance, 
            100,  -- max attempts
            {}    -- no excluded types
        )
        
        if success then
            stationDef.x, stationDef.y = x, y
        else
            -- fallback: place at world center if no safe position found
            stationDef.x, stationDef.y = 0, 0
        end
        
        local stationComponents = require('src.procedural').generateEntity('station', stationDef)
        local stationId = ECS.createEntity()
        for compType, compData in pairs(stationComponents) do
            ECS.addComponent(stationId, compType, compData)
        end
        
        -- Register the new station in collision system
        local stationPos = ECS.getComponent(stationId, "Position")
        local stationColl = ECS.getComponent(stationId, "Collidable")
        if stationPos and stationColl then
            SpawnCollisionUtils.registerEntity(stationId, stationPos.x, stationPos.y, stationColl.radius, "station")
        end
    end
end

function WorldLoader.getCurrentWorldId()
    return WorldLoader.currentWorldId
end

function WorldLoader.setCurrentWorld(worldId)
    if not worldId then
        WorldLoader.currentWorld = nil
        WorldLoader.currentWorldId = nil
        return
    end
    local world = WorldLoader.getWorld(worldId)
    WorldLoader.currentWorld = world
    WorldLoader.currentWorldId = worldId
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
        
        -- Spawn initial asteroids in cluster using universal collision detection
        local count = cluster.maxAsteroids
        local SpawnCollisionUtils = require('src.spawn_collision_utils')
        local minDistance = 150  -- Minimum distance between asteroid centers
        local asteroidRadius = 30  -- Typical asteroid collision radius
        
        for j = 1, count do
            -- Find safe position within cluster using universal collision detection
            local x, y, success = SpawnCollisionUtils.findSafePosition(
                cluster.centerX, 
                cluster.centerY, 
                cluster.radius, 
                asteroidRadius, 
                minDistance, 
                20,  -- max attempts
                {}   -- no excluded types
            )
            
            -- Only spawn if we found a valid position
            if success then
                local asteroidId = AsteroidClusters.createAsteroid(x, y)
                if asteroidId then
                    table.insert(cluster.asteroids, asteroidId)
                    
                    -- Register asteroid in collision system
                    local asteroidPos = ECS.getComponent(asteroidId, "Position")
                    local asteroidColl = ECS.getComponent(asteroidId, "Collidable")
                    if asteroidPos and asteroidColl then
                        SpawnCollisionUtils.registerEntity(asteroidId, asteroidPos.x, asteroidPos.y, asteroidColl.radius, "asteroid")
                    end
                end
            end
        end
    end
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
end

-- Spawn a single enemy
function WorldLoader.spawnEnemy(enemyType, config)
    local SpawnCollisionUtils = require('src.spawn_collision_utils')
    local enemyRadius = 25  -- Typical enemy ship collision radius
    local minDistance = 200  -- Minimum distance from other objects
    
    -- Find safe position using universal collision detection
    local x, y, success = SpawnCollisionUtils.findSafePositionInWorld(
        enemyRadius, 
        minDistance, 
        50,  -- max attempts
        {}   -- no excluded types
    )
    
    -- If no safe position found, use fallback with distance check from spawn
    if not success then
        x = Constants.world_min_x + math.random() * (Constants.world_max_x - Constants.world_min_x)
        y = Constants.world_min_y + math.random() * (Constants.world_max_y - Constants.world_min_y)
        
        -- Make sure not too close to spawn point
        local distanceFromSpawn = math.sqrt(x * x + y * y)
        if distanceFromSpawn < 500 then
            local angle = math.atan2(y, x)
            x = math.cos(angle) * 500
            y = math.sin(angle) * 500
        end
    end

    local shipId = ShipLoader.createShip(enemyType, x, y, "ai")
    if shipId then
        -- Set up turret weapon (random choice if weapons table is a list)
        local turret = ECS.getComponent(shipId, "Turret")
        local weapon = "basic_cannon"
        if turret then
            local weaponConf = config.weapons and config.weapons[enemyType]
            if type(weaponConf) == "table" then
                -- Table of options; randomly choose
                weapon = weaponConf[math.random(1, #weaponConf)] or "basic_cannon"
            elseif type(weaponConf) == "string" then
                weapon = weaponConf
            end
            turret.moduleName = weapon
        end

        -- Automatically set AI type based on weapon (mining lasers = mining AI)
        local ai = ECS.getComponent(shipId, "AI")
        if ai then
            local isMiningWeapon = (weapon == "mining_laser" or weapon == "salvage_laser")
            if isMiningWeapon then
                ai.type = "mining"
                ai.state = "mining"
            else
                ai.type = config.aiType or "combat"
                ai.state = config.aiState or "patrol"
            end
        end

        -- Ensure Wreckage sourceShip is assigned (enables design lookup in AI)
        local wreckage = ECS.getComponent(shipId, "Wreckage")
        if wreckage then
            wreckage.sourceShip = enemyType
        end

        -- Add level component (random level 1-5 for now)
        local level = math.random(1, 5)
        ECS.addComponent(shipId, "Level", {level = level})
        
        -- Register enemy in collision system
        local enemyPos = ECS.getComponent(shipId, "Position")
        local enemyColl = ECS.getComponent(shipId, "Collidable")
        if enemyPos and enemyColl then
            SpawnCollisionUtils.registerEntity(shipId, enemyPos.x, enemyPos.y, enemyColl.radius, "enemy")
        end
    end

    return shipId
end

-- Get the current world
function WorldLoader.getCurrentWorld()
    return WorldLoader.currentWorld
end

return WorldLoader

