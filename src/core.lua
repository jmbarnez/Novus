---@diagnostic disable: undefined-global
-- Space Drone Adventure - Core Game Logic
-- Handles game initialization, entity creation, and game state management

local Constants = require('src.constants')
local Core = {}


-- Dependencies
local ECS = require('src.ecs')
local Systems = require('src.systems')
local Components = require('src.components')
local Parallax = require('src.parallax')
local Constants = require('src.constants')
local Procedural = require('src.procedural')
local UISystem = require('src.systems.ui')
local Scaling = require('src.scaling')
local ShipLoader = require('src.ship_loader')
local AsteroidClusters = require('src.systems.asteroid_clusters')

-- Game initialization
function Core.init()
    print("=== Space Drone Adventure Loading ===")
    Scaling.update()

    -- Set windowed mode, matching start screen size
    local w, h = Constants.screen_width, Constants.screen_height
    love.window.setMode(w, h, {fullscreen = false, resizable = false})

    -- Initialize procedural generation system
    Procedural.init()

    -- Register all ECS systems
    ECS.registerSystem("PhysicsSystem", Systems.PhysicsSystem)
    ECS.registerSystem("PhysicsCollisionSystem", Systems.PhysicsCollisionSystem)
    ECS.registerSystem("BoundarySystem", Systems.BoundarySystem)
    ECS.registerSystem("InputSystem", Systems.InputSystem)
    ECS.registerSystem("RenderSystem", Systems.RenderSystem)
    ECS.registerSystem("CameraSystem", Systems.CameraSystem)
    ECS.registerSystem("UISystem", Systems.UISystem)
    ECS.registerSystem("HUDSystem", Systems.HUDSystem)
    ECS.registerSystem("TrailSystem", Systems.TrailSystem)
    ECS.registerSystem("CombatAlertSystem", require('src.systems.combat_alert'))
    ECS.registerSystem("AIArbiterSystem", Systems.AIArbiterSystem)
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

    -- Initialize asteroid cluster system
    AsteroidClusters.init()

    -- Create Canvas Entity
    local canvasId = ECS.createEntity()
    ECS.addComponent(canvasId, "Canvas", Components.Canvas(Constants.screen_width, Constants.screen_height))

    -- Create Pilot (Player) Entity
    local pilotId = ECS.createEntity()
    ECS.addComponent(pilotId, "InputControlled", Components.InputControlled())
    ECS.addComponent(pilotId, "Player", Components.Player())
    ECS.addComponent(pilotId, "Skills", Components.Skills())
    ECS.addComponent(pilotId, "Wallet", Components.Wallet(1000))  -- Start with 1000 credits

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
    local droneId = ShipLoader.createShip("starter_drone", 0, 0, "player", pilotId)
    
    -- Apply ship-specific thrust multiplier if defined
    local droneDesign = ShipLoader.getDesign("starter_drone")
    local inputComp = ECS.getComponent(pilotId, "InputControlled")
    if droneDesign and droneDesign.thrustMultiplier and inputComp then
        inputComp.speed = Constants.player_max_speed * droneDesign.thrustMultiplier
    end
    
    -- Add initial items to ship's cargo
    local shipCargo = ECS.getComponent(droneId, "Cargo")
    if shipCargo then
        shipCargo.items[miningLaserId] = 1
        shipCargo.items[basicCannonId] = 1
        shipCargo.items[combatLaserId] = 1
        shipCargo.items[salvageLaserId] = 1
        shipCargo.items[missileLauncherId] = 1
        shipCargo.items["basic_shield_module"] = 1  -- Add starting defensive module
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
            if droneTurret then
                print(string.format("[Core] Equipped default turret: itemId='%s', moduleName='%s'", basicCannonId, droneTurret.moduleName))
            end
        else
            -- If slot is empty, make sure moduleName is empty too
            if droneTurret then
                droneTurret.moduleName = nil
            end
            print("[Core] No turret module equipped at start")
        end
    end

    -- Load sound assets
    if Systems.SoundSystem and Systems.SoundSystem.loadAll then
        Systems.SoundSystem.loadAll("assets/sounds")
        -- Debug: list loaded sounds
        for k, _ in pairs(Systems.SoundSystem.sounds or {}) do
            -- Sound available: k
        end
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
    -- Start looping background music if available
    if Systems.SoundSystem and Systems.SoundSystem.playMusic then
        Systems.SoundSystem.playMusic("assets/music/adrift.mp3", {volume = 0.5})
    end

    -- Create Camera Entity
    local cameraId = ECS.createEntity()
    ECS.addComponent(cameraId, "Position", Components.Position(0, 0))
    ECS.addComponent(cameraId, "Camera", Components.Camera(Constants.screen_width, Constants.screen_height))

    -- Create UI Entity
    local uiId = ECS.createEntity()
    ECS.addComponent(uiId, "UI", Components.UI())
    ECS.addComponent(uiId, "UITag", Components.UITag())

    -- Create Starfield Entity (background) with static twinkling layer
    local starFieldId = ECS.createEntity()
    local starLayers = {
        {count = 40, brightness = 0.9, parallaxFactor = 0},      -- Static twinkling stars
        {count = 400, brightness = 0.7, parallaxFactor = 0.01},  -- Very far distant stars
        {count = 300, brightness = 0.5, parallaxFactor = 0.03},  -- Far distant stars
        {count = 200, brightness = 0.35, parallaxFactor = 0.08}  -- Medium distant stars
    }
    local parallaxObject = Parallax.new(starLayers, 10000)
    ECS.addComponent(starFieldId, "StarField", parallaxObject)

    -- Asteroid clusters are initialized via AsteroidClusters.init() above

    -- Spawn enemy ships in the asteroid cluster with 100% chance
    local function spawnEnemyInCluster(clusterX, clusterY)
        -- Random position within cluster area
        local angle = math.random() * 2 * math.pi
        local distance = math.random() * Constants.asteroid_cluster_radius * 0.8
        local x = clusterX + math.cos(angle) * distance
        local y = clusterY + math.sin(angle) * distance
        
        return x, y
    end
    
    -- Get cluster data to spawn enemies in them
    local clusters = AsteroidClusters.getClusters()
    for clusterId, cluster in pairs(clusters) do
        -- Spawn 1-2 miners in this cluster
        local minerCount = math.random(1, 2)
        for i = 1, minerCount do
            local x, y = spawnEnemyInCluster(cluster.centerX, cluster.centerY)
            
            local shipId = ShipLoader.createShip("red_scout", x, y, "ai")
            if shipId then
                local turret = ECS.getComponent(shipId, "Turret")
                if turret then
                    turret.moduleName = "mining_laser"
                end
                
                local ai = ECS.getComponent(shipId, "AIController")
                if ai then
                    ai.state = "mining"
                    ai.speed = 40
                    ai.detectionRadius = 600
                end
                
                ECS.addComponent(shipId, "MiningAI", Components.MiningAI())
            end
        end
        
        -- Spawn 4-5 combat drones in this cluster
        local combatCount = math.random(4, 5)
        for i = 1, combatCount do
            local x, y = spawnEnemyInCluster(cluster.centerX, cluster.centerY)
            
            local shipId = ShipLoader.createShip("red_scout", x, y, "ai")
            if shipId then
                -- Randomly choose between basic_cannon and combat_laser (50/50)
                local weaponChoice = math.random() < 0.5 and "basic_cannon" or "combat_laser"
                
                local turret = ECS.getComponent(shipId, "Turret")
                if turret then
                    turret.moduleName = weaponChoice
                end
                
                -- Configure AI for combat
                local ai = ECS.getComponent(shipId, "AIController")
                if ai then
                    ai.state = "patrol"  -- Start in patrol, will transition to chase/orbit when player detected
                    ai.speed = 80        -- Combat drone speed
                    ai.detectionRadius = 800  -- Larger detection radius for combat
                    ai.fireRange = 2500  -- Fallback fire range (will be overridden by turret)
                end
                
                ECS.addComponent(shipId, "CombatAI", Components.CombatAI())
            end
        end
    end

    print("Game entities created and systems initialized")
    print("Pilot and starting drone spawned at world center (0, 0)")
    print("Asteroid cluster spawned: 1 cluster with 30 asteroids and enemies")
    print("Player controls: WASD for thrust, ESC to quit")
end

-- Main game update loop
function Core.update(dt)
    -- Update all ECS systems
    ECS.update(dt)
end

-- Main game render loop
function Core.draw()
    love.graphics.clear(0, 0, 0)

    ECS.draw() -- Draw all world and UI systems
end


function Core.keypressed(key)
    if key == 'escape' then
        -- If a window is currently open, let UISystem handle closing it first
        if UISystem.isShipWindowOpen and UISystem.isShipWindowOpen() then
            UISystem.setShipWindowOpen(false)
            return
        elseif UISystem.isMapWindowOpen and UISystem.isMapWindowOpen() then
            UISystem.setMapWindowOpen(false)
            return
        elseif UISystem.isSettingsWindowOpen and UISystem.isSettingsWindowOpen() then
            UISystem.setSettingsWindowOpen(false)
            return
        end
        -- Otherwise, open the settings window
        UISystem.toggleSettingsWindow()
        return
    elseif key == 'tab' then
        UISystem.toggleShipWindow()
        return
    elseif key == 'f5' then
        local HUDSystem = require('src.systems.hud')
        if HUDSystem and HUDSystem.toggle then
            HUDSystem.toggle()
        end
        return
    end
    if UISystem.isSettingsWindowOpen and UISystem.isSettingsWindowOpen() then
        -- forward key event directly to settings window
        local SettingsWindow = require('src.ui.settings_window')
        if SettingsWindow.keypressed then
            SettingsWindow:keypressed(key)
        end
    end
    UISystem.keypressed = UISystem.keypressed or function(_) end
    UISystem.keypressed(key)
    Systems.InputSystem.keypressed(key)
end

function Core.mousepressed(x, y, button)
    print("Core.mousepressed called", x, y, button)
    if UISystem.mousepressed then
        local consumed = UISystem.mousepressed(x, y, button)
        if consumed then
            return
        end
    end
    if Systems.InputSystem.mousepressed then
        Systems.InputSystem.mousepressed(x, y, button)
    end
end

function Core.keyreleased(key)
    Systems.InputSystem.keyreleased(key)
end

function Core.mousemoved(x, y, dx, dy, isTouch)
    if UISystem.mousemoved then
        UISystem.mousemoved(x, y, dx, dy, isTouch)
    end
    if Systems.InputSystem.mousemoved then
        Systems.InputSystem.mousemoved(x, y, dx, dy, isTouch)
    end
end

function Core.mousereleased(x, y, button)
    if UISystem.mousereleased then
        UISystem.mousereleased(x, y, button)
    end
    if Systems.InputSystem.mousereleased then
        Systems.InputSystem.mousereleased(x, y, button)
    end
end

function Core.wheelmoved(x, y)
    Systems.InputSystem.wheelmoved(x, y)
end

-- Game cleanup (if needed)
function Core.quit()
    -- Any cleanup logic would go here
    print("Space Drone Adventure shutting down...")
end

function Core.onResize(w, h)
    Scaling.update()
    -- If you want systems (like ECS, HUD) to react, call them here
    -- Example: UISystem.onResize(w, h) (if such a method exists)
end

return Core
