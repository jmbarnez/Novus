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
local PlasmaTheme = require('src.ui.plasma_theme')

-- Expose active theme globally for legacy modules that may prefer a central reference
rawset(_G, 'ActiveTheme', PlasmaTheme)

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
                ownerId = nil,
                segments = nil,
                chainSegments = nil,
                chainColor = nil
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
                laserComp.segments = nil
                laserComp.chainSegments = nil
                laserComp.chainColor = nil
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
                particle._owner = nil
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
    -- Event system: ECS-style transient events delivered into inboxes/global list
    local EventSystem = require('src.systems.event_system')
    EventSystem.priority = 50
    ECS.registerSystem("EventSystem", EventSystem)
    ECS.registerSystem("InputSystem", Systems.InputSystem)
    -- SkillSystem consumes SkillGain events and applies XP
    local SkillSystem = require('src.systems.skill_system')
    ECS.registerSystem("SkillSystem", SkillSystem)
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
    ECS.registerSystem("BehaviorTreeSystem", require('src.systems.behavior_tree_system'))
    ECS.registerSystem("AttackOrderSystem", require('src.systems.attack_order_system'))
    ECS.registerSystem("CollisionSystem", Systems.CollisionSystem)
    ECS.registerSystem("MagnetSystem", Systems.MagnetSystem)
    -- EnemyMiningSystem removed - mining logic now integrated into behavior tree
    ECS.registerSystem("DestructionSystem", Systems.DestructionSystem)
    ECS.registerSystem("DebrisSystem", Systems.DebrisSystem)
    ECS.registerSystem("AISystem", require('src.systems.ai'))
    ECS.registerSystem("TurretAISystem", require('src.systems.turret_ai'))
    ECS.registerSystem("TurretSystem", Systems.TurretSystem)
    ECS.registerSystem("HomingMissileSystem", Systems.MissileSystem)
    ECS.registerSystem("ProjectileSystem", Systems.ProjectileSystem)
    ECS.registerSystem("ShieldImpactSystem", Systems.ShieldImpactSystem)
    ECS.registerSystem("AsteroidClustersSystem", AsteroidClusters)
    -- CrystalFormationSystem removed
    ECS.registerSystem("EnergySystem", Systems.EnergySystem)
    -- ShieldSystem: Manages shield regeneration (depends on EnergySystem, priority 4)
    ECS.registerSystem("ShieldSystem", Systems.ShieldSystem)
    ECS.registerSystem("WorldTooltipsSystem", Systems.WorldTooltipsSystem)
    ECS.registerSystem("QuestSystem", require('src.systems.quest_system'))
    ECS.registerSystem("WreckageSystem", Systems.WreckageSystem)
    -- Ability system handles temporary ability entities (mirrors, shields, etc.)
    local AbilitySystem = require('src.systems.mirror')
    ECS.registerSystem("AbilitySystem", AbilitySystem)
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
        {count = 200, brightness = 0.4, parallaxFactor = 0.08},    -- Medium distant stars (brighter)
        {count = 0, brightness = 0.5, parallaxFactor = 0.95}      -- Very close background asteroids layer (no stars, just asteroids)
    }
    local parallaxObject = Parallax.new(starLayers, 10000)
    ECS.addComponent(starFieldId, "StarField", parallaxObject)

    -- Add an extra nebula cloud to layer 2 for visual variety (safe no-op if API unavailable)
    if Parallax and Parallax.addNebulaCloud then
        Parallax.addNebulaCloud(parallaxObject, 2, { x = 0, y = -500, scale = 0.7, opacity = 0.45 })
    end

    return pilotId
end

-- Set up player ship with default equipment
function GameInit.setupPlayerShip(pilotId)
    -- Give pilot (player) initial turret items in their ship's cargo
    local continuousBeamId = "continuous_beam_turret"
    local basicCannonId = "basic_cannon_turret"
    local arcCoilId = "arc_coil_turret"
    local missileLauncherId = "missile_launcher_turret"
    
    -- Load turret modules (including basic cannon)
    Systems.TurretSystem.loadTurretModules("src/turret_modules")

    -- Create player's starter drone using modular system (will be blue)
    -- Find a collision-safe spawn position around the station (not inside it)
    local SpawnCollisionUtils = require('src.spawn_collision_utils')
    local ECS = require('src.ecs')
    
    -- Find the station position
    local stationX, stationY = 0, 0  -- Default to center if no station found
    local stations = ECS.getEntitiesWith({"Station", "Position", "Collidable"})
    if #stations > 0 then
        local stationPos = ECS.getComponent(stations[1], "Position")
        if stationPos then
            stationX, stationY = stationPos.x, stationPos.y
        end
    end
    
    local playerRadius = 40 -- approximate collision radius for starter drone
    local stationRadius = 120 -- station collision radius
    local minDistanceFromStation = stationRadius + playerRadius + 100 -- Spawn outside station
    local spawnSearchRadius = 400 -- search radius around station for player spawn
    
    -- Spawn player around station, ensuring minimum distance from station
    local px, py, pfound
    local maxAttempts = 100
    
    for attempt = 1, maxAttempts do
        px, py, pfound = SpawnCollisionUtils.findSafePosition(
            stationX, stationY,  -- centerX, centerY (station position)
            spawnSearchRadius,    -- searchRadius
            playerRadius,         -- entityRadius
            150,                  -- minDistance from other objects
            1,                    -- 1 attempt per iteration
            {}                    -- excludeTypes
        )
        
        if pfound then
            -- Check if position is far enough from station
            local dx = px - stationX
            local dy = py - stationY
            local distFromStation = math.sqrt(dx * dx + dy * dy)
            if distFromStation >= minDistanceFromStation then
                break  -- Found good position
            end
            -- Otherwise continue searching
        end
    end

    if not pfound then
        -- Fallback: spawn at a fixed distance from station
        px = stationX + minDistanceFromStation
        py = stationY
    end

    local droneId = ShipLoader.createShip("starter_drone", px, py, "player", pilotId)
    
    -- Movement is now controlled by physics-based thrust (thrustForce in ship design)
    -- No need to set input.speed as physics system handles velocity automatically
    
    -- Add initial items to ship's cargo
    local shipCargo = ECS.getComponent(droneId, "Cargo")
    if shipCargo then
        shipCargo:addItem(continuousBeamId, 1)  -- Unified laser that can do combat, mining, and salvaging
        shipCargo:addItem(basicCannonId, 1)
        shipCargo:addItem(missileLauncherId, 1)
        shipCargo:addItem(arcCoilId, 1)  -- Add arc coil to starter cargo
        shipCargo:addItem("basic_shield_module", 1)  -- Add starting defensive module
        shipCargo:addItem("mirror_shield_module", 1)  -- Add mirror defensive module to starter cargo
        shipCargo:addItem("basic_generator", 1)  -- Add starting generator module
    end

    -- For testing: ensure starter turret items in cargo use instance copies with default level=1
    -- and clear levelRequirement so they don't show old hardcoded requirements
    do
        local ItemDefs = require('src.items.item_loader')
        local TurretModuleLoader = require('src.turret_module_loader')
        local starterModuleIds = {continuousBeamId, basicCannonId, missileLauncherId, arcCoilId}
        for _, iid in ipairs(starterModuleIds) do
            local def = ItemDefs[iid]
            if def and def.module then
                local oldReq = def.module.levelRequirement
                local inst = TurretModuleLoader.createInstance(def.module, {loot = false})
                if inst then
                    -- Instance already has levelRequirement cleared by createInstance
                    -- shallow-copy item def so we don't break other references
                    local newDef = {}
                    for k, v in pairs(def) do newDef[k] = v end
                    newDef.module = inst
                    ItemDefs[iid] = newDef
                    -- Debug: verify the change
                    if oldReq and ItemDefs[iid].module.levelRequirement then
                        print(string.format("[GameInit] WARNING: Failed to clear levelRequirement for %s (was %d, still %d)", 
                            iid, oldReq, ItemDefs[iid].module.levelRequirement))
                    elseif oldReq then
                        print(string.format("[GameInit] Cleared levelRequirement for %s (was %d, now nil)", iid, oldReq))
                    end
                else
                    print(string.format("[GameInit] WARNING: Failed to create instance for %s", iid))
                end
            else
                print(string.format("[GameInit] WARNING: Item %s not found or has no module", iid))
            end
        end
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

-- Main initialization function
function GameInit.bootstrapEnvironment(options)
    options = options or {}

    Scaling.update()
    ShaderManager.init()
    GameInit.initPools()
    Procedural.init()
    GameInit.registerSystems()
    WorldLoader.loadAllWorlds("src.worlds")

    -- Asteroid clusters are now initialized via WorldLoader.initWorld() from world configuration
    -- No random cluster initialization - clusters are defined in world files
    if AsteroidClusters.clear then
        AsteroidClusters.clear()
    end
end

function GameInit.init()
    print("=== NOVUS Loading ===")

    GameInit.bootstrapEnvironment()

    -- Load ship designs early so enemies can spawn with valid designs
    ShipLoader.loadAllDesigns("src.ship_designs")

    -- Initialize world/sector (loads asteroids, stations and enemies)
    -- Change this to any world name to load different sectors:
    -- "default_sector", "asteroid_field", "mining_zone", "combat_sector"
    WorldLoader.initWorld("default_sector")

    -- Create core entities AFTER world initialization so station and world objects exist
    local pilotId = GameInit.createCoreEntities()

    -- Show hotkey reference window on startup
    local UISystem = require('src.systems.ui')
    if UISystem and UISystem.setHotkeyWindowOpen then
        UISystem.setHotkeyWindowOpen(true)
    end

    -- Set up player ship (will spawn near station now that world is initialized)
    GameInit.setupPlayerShip(pilotId)

    -- Load sounds
    GameInit.loadSounds()
end

return GameInit

