---@diagnostic disable: undefined-global
-- Game Initialization Module
-- Handles all game initialization logic including entity pools, systems, and entity creation

local Constants = require('src.constants')
local DisplayManager = require('src.display_manager')
local GameInit = {}

-- Dependencies
local ECS = require('src.ecs')
local Systems = require('src.systems')
local Components = require('src.components')
local Parallax = require('src.parallax')
local Procedural = require('src.procedural')
local Scaling = require('src.scaling')
local ShipLoader = require('src.ship_loader')
local AsteroidClusters = require('src.systems.asteroid_clusters')
local ShaderManager = require('src.shader_manager')
local EntityPool = require('src.entity_pool')
local WorldLoader = require('src.world_loader')

-- Initialize entity pools
function GameInit.initPools()
    -- Laser beam pool: used for combat, mining, and salvage laser beams
    EntityPool.registerPool(
        "laser_beam",
        -- Factory function: creates a new laser beam entity
        function()
            local laserEntity = ECS.createEntity()
            ECS.addComponent(laserEntity, "Position", Components.Position(0, 0))
            ECS.addComponent(laserEntity, "Collidable", Components.Collidable(50))
            ECS.addComponent(laserEntity, "LaserBeam", {
                start = {x = 0, y = 0},
                endPos = {x = 0, y = 0},
                color = {1, 1, 1, 1},
                ownerId = nil
            })
            return laserEntity
        end,
        -- Reset function: clears laser state for reuse
        function(laserEntity)
            local posComp = ECS.getComponent(laserEntity, "Position")
            if posComp then
                posComp.x = 0
                posComp.y = 0
            end
            local laserComp = ECS.getComponent(laserEntity, "LaserBeam")
            if laserComp then
                laserComp.start = {x = 0, y = 0}
                laserComp.endPos = {x = 0, y = 0}
                laserComp.ownerId = nil
                laserComp.color = {1, 1, 1, 1}
            end
        end,
        64  -- maxSize: pool up to 64 laser beam entities
    )

    -- Trail particle pool: used for particle trails behind moving entities
    EntityPool.registerPool(
        "trail_particle",
        -- Factory function: creates a new trail particle entity
        function()
            local particleEntity = ECS.createEntity()
            ECS.addComponent(particleEntity, "TrailParticle", Components.TrailParticle(
                0, 0,           -- x, y position
                0, 0,           -- vx, vy velocity
                1.0,            -- life
                2,              -- size
                {0.5, 0.8, 1.0, 0.8}  -- color (light blue default)
            ))
            return particleEntity
        end,
        -- Reset function: clears particle state for reuse
        function(particleEntity)
            local particle = ECS.getComponent(particleEntity, "TrailParticle")
            if particle then
                particle.x = 0
                particle.y = 0
                particle.vx = 0
                particle.vy = 0
                particle.life = 1.0
                particle.maxLife = 1.0
                particle.size = 2
                particle.color = {0.5, 0.8, 1.0, 0.8}
            end
        end,
        512  -- maxSize: pool up to 512 trail particles (trails are frequent)
    )
end

-- Register all ECS systems
function GameInit.registerSystems()
    ECS.registerSystem("PhysicsSystem", Systems.PhysicsSystem)
    ECS.registerSystem("PhysicsCollisionSystem", Systems.PhysicsCollisionSystem)
    ECS.registerSystem("BoundarySystem", Systems.BoundarySystem)
    ECS.registerSystem("InputSystem", Systems.InputSystem)
    Systems.RenderSystem.priority = 100
    ECS.registerSystem("RenderSystem", Systems.RenderSystem)
    ECS.registerSystem("CameraSystem", Systems.CameraSystem)
    -- UI and HUD systems are now handled only by RenderCanvas, not registered with ECS
    Systems.UISystem.priority = 300
    ECS.registerSystem("UISystem", Systems.UISystem)
    Systems.HUDSystem.priority = 200
    ECS.registerSystem("HUDSystem", Systems.HUDSystem)
    ECS.registerSystem("TrailSystem", Systems.TrailSystem)
    ECS.registerSystem("CombatAlertSystem", require('src.systems.combat_alert'))
    ECS.registerSystem("AISystem", Systems.AISystem)
    ECS.registerSystem("CollisionSystem", Systems.CollisionSystem)
    ECS.registerSystem("MagnetSystem", Systems.MagnetSystem)
    ECS.registerSystem("EnemyMiningSystem", require('src.systems.enemy_mining'))
    ECS.registerSystem("DestructionSystem", Systems.DestructionSystem)
    ECS.registerSystem("DebrisSystem", Systems.DebrisSystem)
    ECS.registerSystem("TurretSystem", Systems.TurretSystem)
    ECS.registerSystem("HomingMissileSystem", Systems.MissileSystem)
    ECS.registerSystem("ProjectileSystem", Systems.ProjectileSystem)
    ECS.registerSystem("ShieldImpactSystem", Systems.ShieldImpactSystem)
    ECS.registerSystem("AsteroidClustersSystem", AsteroidClusters)
    -- CrystalFormationSystem removed
    ECS.registerSystem("AsteroidHotspotSystem", Systems.AsteroidHotspotSystem)
    ECS.registerSystem("EnergySystem", Systems.EnergySystem)
    ECS.registerSystem("WorldTooltipsSystem", Systems.WorldTooltipsSystem)
    ECS.registerSystem("QuestSystem", require('src.systems.quest_system'))
    ECS.registerSystem("WreckageSystem", Systems.WreckageSystem)
    -- NebulaCloudSystem is called explicitly from RenderSystem
end

-- Create core entities (Canvas, Pilot, Camera, UI, Starfield)
function GameInit.createCoreEntities()
    -- Create Canvas Entity
    local canvasId = ECS.createEntity()
    local renderWidth, renderHeight = DisplayManager.getRenderDimensions()
    ECS.addComponent(canvasId, "Canvas", Components.Canvas(renderWidth, renderHeight))

    -- Create Pilot (Player) Entity
    local pilotId = ECS.createEntity()
    ECS.addComponent(pilotId, "InputControlled", Components.InputControlled())
    ECS.addComponent(pilotId, "Player", Components.Player())
    ECS.addComponent(pilotId, "Skills", Components.Skills())
    ECS.addComponent(pilotId, "Wallet", Components.Wallet(1000))  -- Start with 1000 credits
    -- Add Level component to player (start at level 1)
    ECS.addComponent(pilotId, "Level", Components.Level(1))

    -- Create Camera Entity
    local cameraId = ECS.createEntity()
    -- Create camera component first so we can read width/zoom when calculating initial position
    local cameraComp = Components.Camera(renderWidth, renderHeight)
    ECS.addComponent(cameraId, "Camera", cameraComp)
    -- Try to center camera on the player's ship if it exists so the camera doesn't "slide" on first frames
    local initialCamX, initialCamY = -1500, 0
    local controlledShips = ECS.getEntitiesWith({"ControlledBy"})
    if #controlledShips > 0 then
        local playerShipId = controlledShips[1]
        local playerPos = ECS.getComponent(playerShipId, "Position")
        if playerPos then
            initialCamX = playerPos.x - (cameraComp.width / (cameraComp.zoom or 1)) / 2
            initialCamY = playerPos.y - (cameraComp.height / (cameraComp.zoom or 1)) / 2
        end
    end
    ECS.addComponent(cameraId, "Position", Components.Position(initialCamX, initialCamY))

    -- Create UI Entity
    local uiId = ECS.createEntity()
    ECS.addComponent(uiId, "UI", Components.UI())
    ECS.addComponent(uiId, "UITag", Components.UITag())

    -- Create Starfield Entity (background) with static twinkling layer
    -- Much brighter stars for better visibility in dark space
    local starFieldId = ECS.createEntity()
    local starLayers = {
        {count = 40, brightness = 0.85, parallaxFactor = 0},      -- Static twinkling stars (much brighter)
        {count = 400, brightness = 0.65, parallaxFactor = 0.01},  -- Very far distant stars (brighter)
        {count = 300, brightness = 0.5, parallaxFactor = 0.03},   -- Far distant stars (brighter)
        {count = 200, brightness = 0.4, parallaxFactor = 0.08}    -- Medium distant stars (brighter)
    }
    local parallaxObject = Parallax.new(starLayers, 10000)
    ECS.addComponent(starFieldId, "StarField", parallaxObject)

    return pilotId
end

-- Set up player ship with default equipment
function GameInit.setupPlayerShip(pilotId)
    -- Give pilot (player) initial turret items in their ship's cargo
    local miningLaserId = "mining_laser_turret"
    local basicCannonId = "basic_cannon_turret"
    local combatLaserId = "combat_laser_turret"
    local salvageLaserId = "salvage_laser_turret"
    local missileLauncherId = "missile_launcher_turret"
    
    -- Load turret modules (including basic cannon)
    Systems.TurretSystem.loadTurretModules("src/turret_modules")
    
    -- Load ship designs
    ShipLoader.loadAllDesigns("src.ship_designs")

    -- Create player's starter drone using modular system (will be blue)
    -- Find a collision-safe spawn position near world center so player doesn't overlap station/gate
    local SpawnCollisionUtils = require('src.spawn_collision_utils')
    local playerRadius = 40 -- approximate collision radius for starter drone
    local minDistance = 220 -- keep some buffer from other objects
    local spawnSearchRadius = 300 -- search radius around center for player spawn
    local px, py, pfound = SpawnCollisionUtils.findSafePosition(
        0, 0,               -- centerX, centerY (world center)
        spawnSearchRadius,  -- searchRadius
        playerRadius,       -- entityRadius
        minDistance,        -- minDistance
        50,                 -- maxAttempts
        {}                  -- excludeTypes
    )

    if not pfound then
        px, py = 0, 0
    end

    local droneId = ShipLoader.createShip("starter_drone", px, py, "player", pilotId)
    
    -- Apply ship-specific movement parameters if defined
    local droneDesign = ShipLoader.getDesign("starter_drone")
    local inputComp = ECS.getComponent(pilotId, "InputControlled")
    if droneDesign and inputComp then
        -- Prefer an explicit per-design maxSpeed when present (designer-controlled)
        if droneDesign.maxSpeed then
            inputComp.speed = droneDesign.maxSpeed
        elseif droneDesign.thrustMultiplier then
            -- Back-compat: support legacy thrustMultiplier which scaled the global max
            inputComp.speed = Constants.player_max_speed * droneDesign.thrustMultiplier
        end
    end
    
    -- Add initial items to ship's cargo
    local shipCargo = ECS.getComponent(droneId, "Cargo")
    if shipCargo then
        shipCargo:addItem(miningLaserId, 1)
        shipCargo:addItem(basicCannonId, 1)
        shipCargo:addItem("railgun", 1) -- Add a railgun to starter cargo (powerful but slow)
        shipCargo:addItem(combatLaserId, 1)
        shipCargo:addItem(salvageLaserId, 1)
        shipCargo:addItem(missileLauncherId, 1)
        shipCargo:addItem("basic_shield_module", 1)  -- Add starting defensive module
        shipCargo:addItem("basic_generator", 1)  -- Add starting generator module
    end

    -- Debug: print starter cargo contents so we can verify item addition at runtime
    if shipCargo then
    end
    
    -- Equip default turret on the drone (Basic Cannon!)
    local droneId = ECS.getEntitiesWith({"ControlledBy"})[1]
    if droneId then
        local droneTurret = ECS.getComponent(droneId, "Turret")
        local turretSlots = ECS.getComponent(droneId, "TurretSlots")
        if turretSlots and turretSlots.slots[1] then
            -- If slot is filled, equip the module
            if droneTurret then
                droneTurret.moduleName = "basic_cannon"
            end
            turretSlots.slots[1] = basicCannonId
        else
            -- If slot is empty, make sure moduleName is empty too
            if droneTurret then
                droneTurret.moduleName = nil
            end
            print("[Core] No turret module equipped at start")
        end
    end
end

-- Load sound assets
function GameInit.loadSounds()
    if Systems.SoundSystem and Systems.SoundSystem.loadAll then
        Systems.SoundSystem.loadAll("assets/sounds")
        -- Fallback: ensure item_pickup is loaded (some environments may not list files)
        if not Systems.SoundSystem.sounds["item_pickup"] then
            local pickupPath = "assets/sounds/item_pickup.ogg"
            local ok, src = pcall(love.audio.newSource, pickupPath, "static")
            if ok and src then
                Systems.SoundSystem.sounds["item_pickup"] = src
                -- Manually loaded pickup sound
            else
                -- Failed to manually load pickup sound
            end
        end
    end
        -- Start playing background music immediately if available
        if Systems.SoundSystem and Systems.SoundSystem.playMusic then
            Systems.SoundSystem.playMusic("assets/music/adrift.mp3", {volume = 100})
    end
end

-- Spawn enemy ships in asteroid clusters
function GameInit.spawnEnemies()
    local function spawnEnemyInCluster(clusterX, clusterY, clusterRadius)
        -- Random position within cluster area. Prefer clusterRadius if provided.
        local radius = clusterRadius or Constants.asteroid_cluster_radius
        local angle = math.random() * 2 * math.pi
        local distance = math.random() * (radius * 0.8)
        local x = clusterX + math.cos(angle) * distance
        local y = clusterY + math.sin(angle) * distance

        return x, y
    end
    
    -- Get cluster data to spawn enemies in them
    local clusters = AsteroidClusters.getClusters()
    for clusterId, cluster in pairs(clusters) do
        -- 50% chance (configurable) to spawn an enemy group at this cluster
        local spawnChance = Constants.cluster_enemy_spawn_chance or 0.5
        if math.random() < spawnChance then
            local radius = cluster.radius or Constants.asteroid_cluster_radius

            -- Spawn miners (miners are red_scouts with mining laser)
            local minerCount = math.random(Constants.cluster_miner_count_min or 1, Constants.cluster_miner_count_max or 2)
            for i = 1, minerCount do
                local x, y = spawnEnemyInCluster(cluster.centerX, cluster.centerY, radius)
                local shipId = ShipLoader.createShip("red_scout", x, y, "ai")
                if shipId then
                    local turret = ECS.getComponent(shipId, "Turret")
                    if turret then
                        turret.moduleName = "mining_laser"
                    end
                    local ai = ECS.getComponent(shipId, "AI")
                    local design = ShipLoader.getDesign("red_scout")
                    if ai and design then
                        ai.type = "mining"
                        ai.state = "mining"
                        if design.miningDetectionRange then
                            ai.detectionRadius = design.miningDetectionRange
                        end
                    end
                    local level = math.random(1, 3)
                    ECS.addComponent(shipId, "Level", {level = level})
                end
            end

            -- Spawn combat red_scouts
            local combatCount = math.random(Constants.cluster_combat_count_min or 3, Constants.cluster_combat_count_max or 5)
            for i = 1, combatCount do
                local x, y = spawnEnemyInCluster(cluster.centerX, cluster.centerY, radius)
                local shipId = ShipLoader.createShip("red_scout", x, y, "ai")
                if shipId then
                    -- Choose combat weapons for these scouts
                    local weaponChoice = math.random() < 0.5 and "basic_cannon" or "combat_laser"
                    local turret = ECS.getComponent(shipId, "Turret")
                    if turret then
                        turret.moduleName = weaponChoice
                    end
                    local ai = ECS.getComponent(shipId, "AI")
                    local design = ShipLoader.getDesign("red_scout")
                    if ai and design then
                        ai.type = "combat"
                        ai.state = "patrol"
                        if design.combatDetectionRange then
                            ai.detectionRadius = design.combatDetectionRange
                        end
                    end
                    local level = math.random(1, 3)
                    ECS.addComponent(shipId, "Level", {level = level})
                end
            end
        end
    end
end

-- Main initialization function
function GameInit.bootstrapEnvironment(options)
    options = options or {}

    Scaling.update()
    ShaderManager.init()
    GameInit.initPools()
    Procedural.init()
    GameInit.registerSystems()
    WorldLoader.loadAllWorlds("src.worlds")

    if options.skipAsteroidInit then
        if AsteroidClusters.clear then
            AsteroidClusters.clear()
        end
    else
        AsteroidClusters.init()
    end
end

function GameInit.init()
    print("=== NOVUS Loading ===")

    GameInit.bootstrapEnvironment()

    -- Create core entities
    local pilotId = GameInit.createCoreEntities()

    -- Set up player ship
    GameInit.setupPlayerShip(pilotId)

    -- Load sounds
    GameInit.loadSounds()

    -- Initialize world/sector (loads asteroids and enemies)
    -- Change this to any world name to load different sectors:
    -- "default_sector", "asteroid_field", "mining_zone", "combat_sector"
    WorldLoader.initWorld("default_sector")
end

return GameInit

