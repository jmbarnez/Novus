---@diagnostic disable: undefined-global
-- World/Sector Loader
-- Loads world definitions from worlds/ directory and provides factory functions

local ECS = require('src.ecs')
local Components = require('src.components')
local Constants = require('src.constants')
local Procedural = require('src.procedural')
local ShipLoader = require('src.ship_loader')
local AsteroidClusters = require('src.systems.asteroid_clusters')
local QuestSystem = require('src.systems.quest_system')
local WorldObjects = require('src.world_objects')

local WorldLoader = {
    worlds = {},
    currentWorld = nil,
    currentWorldId = nil
}
local WorldChunkManager = require('src.world_chunk_manager')

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

    local modulePrefix = directory:gsub("/", ".")
    local fsPath = directory:gsub("%.", "/")
    local loadedCount = 0

    local lfs = love and love.filesystem
    if lfs and lfs.getDirectoryItems then
        local entries = lfs.getDirectoryItems(fsPath)
        table.sort(entries)

        for _, entry in ipairs(entries) do
            if entry:sub(-4) == ".lua" then
                local info = lfs.getInfo(fsPath .. "/" .. entry, "file")
                if info and info.type == "file" then
                    local worldId = entry:sub(1, -5)
                    if worldId ~= "init" and worldId ~= "" then
                        local filepath = modulePrefix .. "." .. worldId
                        if WorldLoader.loadWorld(worldId, filepath) then
                            loadedCount = loadedCount + 1
                        end
                    end
                end
            end
        end

        return loadedCount
    end

    -- Fallback to known worlds when love.filesystem is unavailable
    local knownWorlds = {
        "default_sector",
        "asteroid_field",
        "mining_zone",
        "combat_sector"
    }

    for _, worldId in ipairs(knownWorlds) do
        local filepath = modulePrefix .. "." .. worldId
        if WorldLoader.loadWorld(worldId, filepath) then
            loadedCount = loadedCount + 1
        end
    end

    return loadedCount
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
    -- Initialize chunk manager for this world
    if WorldChunkManager and WorldChunkManager.init then
        WorldChunkManager.init(world)
        -- Preload chunks around world center (station)
        local centerX = (Constants.world_min_x + Constants.world_max_x) / 2
        local centerY = (Constants.world_min_y + Constants.world_max_y) / 2
        WorldChunkManager.ensureLoadedAround(centerX, centerY, 1)
    end

    -- Backwards-compatibility: convert legacy world coordinates (centered at 0) to new 0..world_width range
    -- Only run once per world definition
    if not world._coordsConverted then
        local offsetX = Constants.world_width / 2
        local offsetY = Constants.world_height / 2

        -- Convert asteroid cluster centers if present
        if world.asteroidClusters and world.asteroidClusters.clusters then
            for _, c in ipairs(world.asteroidClusters.clusters) do
                if c.x then c.x = c.x + offsetX end
                if c.y then c.y = c.y + offsetY end
            end
        end

        -- Convert station coordinates if present
        if world.stations then
            for _, s in ipairs(world.stations) do
                if s.x then s.x = s.x + offsetX end
                if s.y then s.y = s.y + offsetY end
            end
        end

        -- Mark converted so we don't shift twice
        world._coordsConverted = true
    end
    
    -- Initialize asteroid clusters
    if world.asteroidClusters then
        WorldLoader.initAsteroidClusters(world.asteroidClusters)
    end
    
    -- Spawn initial enemies
    if world.enemies then
        WorldLoader.spawnEnemies(world.enemies)
    end
    
    -- Spawn warp gate randomly within sector bounds, avoiding overlaps
    local SpawnCollisionUtils = require('src.spawn_collision_utils')
    local ECS = require('src.ecs')
    
    -- Register existing entities (enemies, asteroids) in collision system
    SpawnCollisionUtils.clearRegistry()
    local existingEntities = ECS.getEntitiesWith({"Position", "Collidable"})
    for _, entityId in ipairs(existingEntities) do
        local pos = ECS.getComponent(entityId, "Position")
        local coll = ECS.getComponent(entityId, "Collidable")
        if pos and coll then
            SpawnCollisionUtils.registerEntity(entityId, pos.x, pos.y, coll.radius, "existing")
        end
    end
    
    -- Find safe position for warp gate within world bounds
    -- Reserve space at world center for station - don't spawn warpgate too close
    local gateRadius = 80  -- Warpgate collision radius
    local stationRadius = 120  -- Station collision radius
    local minDistanceFromCenter = stationRadius + gateRadius + 200  -- Keep warpgate away from center
    
    local gateX, gateY, gateFound
    local maxAttempts = 150
    
    -- Try to find a position that's not too close to center (where station will be)
    for attempt = 1, maxAttempts do
        gateX, gateY, gateFound = SpawnCollisionUtils.findSafePositionInWorld(
            gateRadius,
            200,  -- minDistance from other entities
            1,    -- 1 attempt per iteration
            {}    -- no excluded types
        )
        
        if gateFound then
            -- Check if position is far enough from world center (where station will be)
            local centerX = (Constants.world_min_x + Constants.world_max_x) / 2
            local centerY = (Constants.world_min_y + Constants.world_max_y) / 2
            local dx = gateX - centerX
            local dy = gateY - centerY
            local distFromCenter = math.sqrt(dx * dx + dy * dy)
            if distFromCenter >= minDistanceFromCenter then
                break  -- Found good position
            end
            -- Otherwise continue searching
        end
    end
    
    -- Fallback if no safe position found (should be rare)
    if not gateFound then
        -- Place fallback gate offset from world center
        local centerX = (Constants.world_min_x + Constants.world_max_x) / 2
        local centerY = (Constants.world_min_y + Constants.world_max_y) / 2
        gateX = centerX + 1000
        gateY = centerY + 1000
    end
    
    local gateComponents = require('src.procedural').generateEntity('warp_gate', {x = gateX, y = gateY, active = false})
    local gateId = ECS.createEntity()
    for componentType, componentData in pairs(gateComponents) do
        ECS.addComponent(gateId, componentType, componentData)
    end
    
    -- Register warpgate in collision system
    local gatePos = ECS.getComponent(gateId, "Position")
    local gateColl = ECS.getComponent(gateId, "Collidable")
    if gatePos and gateColl then
        SpawnCollisionUtils.registerEntity(gateId, gatePos.x, gatePos.y, gateColl.radius, "warpgate")
        -- Register ownership to chunk manager
        if WorldChunkManager and WorldChunkManager.registerEntityToChunk then
            local cx, cy = WorldChunkManager.worldToChunk(gatePos.x, gatePos.y)
            WorldChunkManager.registerEntityToChunk(gateId, cx, cy)
        end
    end
    
    QuestSystem.registerMainQuestTarget(gateId)
    
    -- Spawn stations if specified in world
    if world.stations then
        local stationDef = world.stations[1]  -- Only one station for now
        local stationRadius = 120  -- Station collision radius
        
        -- Station always spawns at world center
        local centerX = (Constants.world_min_x + Constants.world_max_x) / 2
        local centerY = (Constants.world_min_y + Constants.world_max_y) / 2
        -- Check if center is safe (should be since we kept warpgate away)
        local centerSafe = SpawnCollisionUtils.isPositionSafe(centerX, centerY, stationRadius, 200, {})
        
        if centerSafe then
            stationDef.x, stationDef.y = centerX, centerY
        else
            -- Fallback: try small area around center if center is blocked
            local x, y, success = SpawnCollisionUtils.findSafePosition(
                centerX, centerY,         -- centerX, centerY -> world center
                100,          -- searchRadius: very small radius around center
                stationRadius, 
                200,          -- minDistance
                50,              -- max attempts
                {}             -- no excluded types
            )
            if success then
                stationDef.x, stationDef.y = x, y
            else
                -- Last resort: place at center anyway
                stationDef.x, stationDef.y = centerX, centerY
            end
        end
        
        local stationComponents
        -- Prefer world_objects prefabs when a prefab is specified
        if stationDef.prefab and WorldObjects and WorldObjects.getPrefab then
            local prefab = WorldObjects.getPrefab(stationDef.prefab)
            if prefab and prefab.generate then
                stationComponents = prefab.generate(stationDef)
            end
        end

        -- Fallback to procedural station template if no prefab generated components
        if not stationComponents then
            stationComponents = Procedural.generateEntity('station', stationDef)
        end

        local stationId = ECS.createEntity()
        for compType, compData in pairs(stationComponents) do
            ECS.addComponent(stationId, compType, compData)
        end
        
        -- Register the new station in collision system
        local stationPos = ECS.getComponent(stationId, "Position")
        local stationColl = ECS.getComponent(stationId, "Collidable")
        if stationPos and stationColl then
            SpawnCollisionUtils.registerEntity(stationId, stationPos.x, stationPos.y, stationColl.radius, "station")
            if WorldChunkManager and WorldChunkManager.registerEntityToChunk then
                local cx, cy = WorldChunkManager.worldToChunk(stationPos.x, stationPos.y)
                WorldChunkManager.registerEntityToChunk(stationId, cx, cy)
            end
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
    
    print("[WorldLoader] Initializing", config.count, "asteroid cluster(s)")
    
    -- Create clusters based on world configuration
    for i = 1, config.count do
        local clusterConfig = config.clusters[i] or {}
        
        local clusterId = nextClusterId
        nextClusterId = nextClusterId + 1
        
        -- Use configured position or random position, but clamp to world bounds so clusters don't sit outside the world
        local proposedX = clusterConfig.x
        local proposedY = clusterConfig.y
        local maxRadius = clusterConfig.radius or Constants.asteroid_cluster_radius
        -- If no explicit coords, pick randomly but keep entire cluster inside world bounds
        if not proposedX then
            proposedX = Constants.world_min_x + maxRadius + math.random() * (Constants.world_max_x - Constants.world_min_x - 2 * maxRadius)
        end
        if not proposedY then
            proposedY = Constants.world_min_y + maxRadius + math.random() * (Constants.world_max_y - Constants.world_min_y - 2 * maxRadius)
        end

        -- Clamp to ensure cluster circle (center +/- radius) stays inside world bounds
        local clusterX = math.max(Constants.world_min_x + maxRadius, math.min(proposedX, Constants.world_max_x - maxRadius))
        local clusterY = math.max(Constants.world_min_y + maxRadius, math.min(proposedY, Constants.world_max_y - maxRadius))
        
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
        
        print(string.format("[WorldLoader] Created cluster %d at (%.0f, %.0f) with radius %.0f", 
            clusterId, clusterX, clusterY, cluster.radius))
        
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
    
    -- Add decorative parallax asteroids around clusters (close background layer)
    local Parallax = require('src.parallax')
    local ECS = require('src.ecs')
    local starFieldEntities = ECS.getEntitiesWith({"StarField"})
    if #starFieldEntities > 0 then
        local starFieldId = starFieldEntities[1]
        local starFieldComp = ECS.getComponent(starFieldId, "StarField")
        if starFieldComp and Parallax.addAsteroidsNearClusters then
            Parallax.addAsteroidsNearClusters(starFieldComp)
        end
    end
end

-- Spawn enemies based on world configuration
function WorldLoader.spawnEnemies(config)
    local spawnCount = 0
    local SpawnCollisionUtils = require('src.spawn_collision_utils')

    -- Get asteroid clusters for enemy spawning
    local clusters = AsteroidClusters.getClusters()
    local clusterList = {}
    if clusters then
        for _, c in pairs(clusters) do
            if c and c.centerX and c.centerY then
                table.insert(clusterList, c)
            end
        end
    end
    
    -- Debug: warn if no clusters found
    if #clusterList == 0 then
        local clusterCount = 0
        if clusters then
            for _ in pairs(clusters) do clusterCount = clusterCount + 1 end
        end
        print("[WorldLoader] WARNING: No asteroid clusters found for enemy spawning. Enemies will not spawn.")
        print("[WorldLoader] Total clusters in table:", clusterCount)
        return 0  -- Early return if no clusters
    end
    
    print("[WorldLoader] Found", #clusterList, "asteroid cluster(s) for enemy spawning")

    -- Support both old single-group format and new multi-group format
    local enemyGroups = config.groups or {config}

    for _, groupConfig in ipairs(enemyGroups) do
        for enemyType, count in pairs(groupConfig.types or {}) do
            for i = 1, count do
                local shipId = nil
                local enemyRadius = 25
                -- Reduce minDistance - clusters are dense, we need enemies close to asteroids but not overlapping
                local minDistance = 50  -- Reduced from 150 to allow enemies to spawn closer together

                -- Try cluster-based spawn first (prefer spawning near asteroid clusters)
                if #clusterList > 0 then
                    local cluster = clusterList[math.random(1, #clusterList)]
                    local radius = cluster.radius or Constants.asteroid_cluster_radius
                    -- Spawn enemies in a ring around clusters (outside dense asteroid area but nearby)
                    -- Use radius + 300 to 500 range for enemy spawn ring
                    local innerRadius = radius + 300
                    local outerRadius = radius + 500
                    
                    -- Try multiple attempts to find a position in the ring
                    local maxAttempts = 30
                    local attempts = 0
                    local x, y, success = nil, nil, false
                    
                    while attempts < maxAttempts and not success do
                        -- Random position in the ring
                        local angle = math.random() * 2 * math.pi
                        local distance = innerRadius + math.random() * (outerRadius - innerRadius)
                        x = cluster.centerX + math.cos(angle) * distance
                        y = cluster.centerY + math.sin(angle) * distance
                        
                        -- Check if position is safe
                        success = SpawnCollisionUtils.isPositionSafe(x, y, enemyRadius, minDistance, {})
                        attempts = attempts + 1
                    end

                    if success then
                        -- Generate level before creating ship so scaling can use it
                        local levelValue = math.random(1, 3)
                        shipId = ShipLoader.createShip(enemyType, x, y, "ai", nil, levelValue)
                        -- Set turret weapon after creation
                        if shipId then
                            local turret = ECS.getComponent(shipId, "Turret")
                            local weapon = "basic_cannon"
                            if turret then
                                local weaponConf = groupConfig.weapons and groupConfig.weapons[enemyType]
                                if type(weaponConf) == "table" then
                                    weapon = weaponConf[math.random(1, #weaponConf)] or "basic_cannon"
                                elseif type(weaponConf) == "string" then
                                    weapon = weaponConf
                                end
                                turret.moduleName = weapon
                                -- Ensure AI type/state and behavior tree are set according to group config
                                local ai = ECS.getComponent(shipId, "AI")
                                if ai then
                                    -- Determine mining weapon special-case (legacy)
                                    local isMiningWeapon = (weapon == "continuous_beam")
                                    if isMiningWeapon then
                                        ai.type = "mining"
                                        ai.state = "mining"
                                    else
                                        ai.type = groupConfig.aiType or ai.type or "combat"
                                        ai.state = groupConfig.aiState or ai.state or "patrol"
                                    end

                                    -- Set detection range based on AI type from design
                                    local design = ShipLoader.getDesign(enemyType)
                                    if design then
                                        if ai.type == "mining" and design.miningDetectionRange then
                                            ai.detectionRadius = design.miningDetectionRange
                                        elseif ai.type == "combat" and design.combatDetectionRange then
                                            ai.detectionRadius = design.combatDetectionRange
                                        end
                                    end
                                end

                                -- Attach the appropriate behavior tree component
                                local trees = require('src.ai.trees')
                                if groupConfig.aiType == "mining" then
                                    ECS.addComponent(shipId, "BehaviorTree", { root = trees.mining })
                                elseif groupConfig.aiType == "combat" then
                                    ECS.addComponent(shipId, "BehaviorTree", { root = trees.combat })
                                end
                            end

                            -- Register enemy ship in collision system so other enemies don't spawn on top of it
                            local shipPos = ECS.getComponent(shipId, "Position")
                            local shipColl = ECS.getComponent(shipId, "Collidable")
                            if shipPos and shipColl then
                                SpawnCollisionUtils.registerEntity(shipId, shipPos.x, shipPos.y, shipColl.radius, "enemy")
                                -- Register ownership to chunk manager
                                if WorldChunkManager and WorldChunkManager.registerEntityToChunk then
                                    local cx, cy = WorldChunkManager.worldToChunk(shipPos.x, shipPos.y)
                                    WorldChunkManager.registerEntityToChunk(shipId, cx, cy)
                                end
                            end
                        end
                    else
                        -- Debug: findSafePosition failed
                        -- This happens when no valid position can be found within the cluster
                    end
                end

                -- Only spawn enemies within asteroid clusters
                -- If cluster spawn failed, skip this enemy (no world-wide spawning)
                if shipId then
                    spawnCount = spawnCount + 1
                end
            end
        end
    end
    
    print("[WorldLoader] Spawned", spawnCount, "enemy ship(s)")
    return spawnCount
end

-- Get the current world
function WorldLoader.getCurrentWorld()
    return WorldLoader.currentWorld
end

return WorldLoader
