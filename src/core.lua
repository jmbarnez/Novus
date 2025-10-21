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
    ECS.registerSystem("ProjectileSystem", Systems.ProjectileSystem)
    ECS.registerSystem("ShieldImpactSystem", Systems.ShieldImpactSystem)

    -- Create Canvas Entity
    local canvasId = ECS.createEntity()
    ECS.addComponent(canvasId, "Canvas", Components.Canvas(Constants.screen_width, Constants.screen_height))

    -- Create Pilot (Player) Entity
    local pilotId = ECS.createEntity()
    ECS.addComponent(pilotId, "InputControlled", Components.InputControlled())
    ECS.addComponent(pilotId, "Player", Components.Player())
    ECS.addComponent(pilotId, "Skills", Components.Skills())

    -- Give pilot (player) initial turret items in their ship's cargo
    local miningLaserId = "mining_laser_turret"
    local basicCannonId = "basic_cannon_turret"
    local combatLaserId = "combat_laser_turret"
    local salvageLaserId = "salvage_laser_turret"
    
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
            print("[Core] Sound available:", k)
        end
        -- Fallback: ensure item_pickup is loaded (some environments may not list files)
        if not Systems.SoundSystem.sounds["item_pickup"] then
            local pickupPath = "assets/sounds/item_pickup.ogg"
            local ok, src = pcall(love.audio.newSource, pickupPath, "static")
            if ok and src then
                Systems.SoundSystem.sounds["item_pickup"] = src
                print("[Core] Manually loaded pickup sound from: " .. pickupPath)
            else
                print("[Core] Failed to manually load pickup sound: " .. tostring(pickupPath))
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

    -- Create thick asteroid field band extending across the world boundaries
    local asteroidFieldDensity = Constants.asteroid_field_density
    local fieldCenterY = 0
    local fieldThickness = Constants.asteroid_field_thickness  -- Y-axis thickness of the field (±1500 from center)
    
    for i = 1, asteroidFieldDensity do
        -- Randomly distribute asteroids across X and Y within the band
        local x = Constants.world_min_x + math.random() * (Constants.world_max_x - Constants.world_min_x)
        local y = fieldCenterY + (math.random() - 0.5) * fieldThickness
        
        -- Constrain to world bounds
        x = math.max(Constants.world_min_x, math.min(Constants.world_max_x, x))
        y = math.max(Constants.world_min_y, math.min(Constants.world_max_y, y))
        
        local size = Procedural.randomRange(Constants.asteroid_size_min, Constants.asteroid_size_max)
        local vertexCount = math.random(Constants.asteroid_vertices_min, Constants.asteroid_vertices_max)
        local vertices = Procedural.generatePolygonVertices(vertexCount, size / 2)
        
        local asteroidMass = size * size * 0.5
        
        local asteroidId = ECS.createEntity()
        ECS.addComponent(asteroidId, "Position", Components.Position(x, y))
        ECS.addComponent(asteroidId, "Velocity", Components.Velocity(0, 0))
        ECS.addComponent(asteroidId, "Physics", Components.Physics(0.999, asteroidMass))
        ECS.addComponent(asteroidId, "PolygonShape", Components.PolygonShape(vertices, math.random() * 2 * math.pi))
        ECS.addComponent(asteroidId, "AngularVelocity", Components.AngularVelocity(0))
        ECS.addComponent(asteroidId, "Collidable", Components.Collidable(size / 2))
        ECS.addComponent(asteroidId, "Durability", Components.Durability(size * 2, size * 2))
        ECS.addComponent(asteroidId, "Asteroid", Components.Asteroid())
        ECS.addComponent(asteroidId, "Renderable", Components.Renderable("polygon", nil, nil, nil, {0.6, 0.4, 0.2, 1}))
    end

    -- Spawn enemy ships across the map
    -- 5 mining laser drones + 10 cannon drones = 15 total
    local miningCount = 5
    local cannonCount = 10
    local totalEnemies = miningCount + cannonCount
    local enemySpacing = (Constants.world_max_x - Constants.world_min_x) / (totalEnemies + 1)
    
    local enemyIndex = 1
    
    -- Spawn mining laser drones first
    for i = 1, miningCount do
        local x = Constants.world_min_x + enemyIndex * enemySpacing + (math.random() - 0.5) * 500
        local y = (math.random() - 0.5) * 4000  -- Random Y position
        x = math.max(Constants.world_min_x, math.min(Constants.world_max_x, x))
        y = math.max(Constants.world_min_y, math.min(Constants.world_max_y, y))
        
        local designId = "red_scout"
        local turretModule = "mining_laser"
        
        local shipId = ShipLoader.createShip(designId, x, y, "ai")
        
        if shipId then
            -- Set turret module
            local turret = ECS.getComponent(shipId, "Turret")
            if turret then
                turret.moduleName = turretModule
            end
            
            -- Mining AI ships get slower speed and mining state
            local ai = ECS.getComponent(shipId, "AIController")
            if ai then
                ai.state = "mining"
                ai.speed = 40
                ai.detectionRadius = 600
            end
            
            -- Mark as mining AI for ECS queries
            ECS.addComponent(shipId, "MiningAI", Components.MiningAI())
        end
        
        enemyIndex = enemyIndex + 1
    end
    
    -- Spawn cannon drones second
    for i = 1, cannonCount do
        local x = Constants.world_min_x + enemyIndex * enemySpacing + (math.random() - 0.5) * 500
        local y = (math.random() - 0.5) * 4000  -- Random Y position
        x = math.max(Constants.world_min_x, math.min(Constants.world_max_x, x))
        y = math.max(Constants.world_min_y, math.min(Constants.world_max_y, y))
        
        local designId = "red_scout"
        local turretModule = "basic_cannon"
        
        local shipId = ShipLoader.createShip(designId, x, y, "ai")
        
        if shipId then
            -- Set turret module
            local turret = ECS.getComponent(shipId, "Turret")
            if turret then
                turret.moduleName = turretModule
            end
            
            -- Mark as combat AI for ECS queries
            ECS.addComponent(shipId, "CombatAI", Components.CombatAI())
        end
        
        enemyIndex = enemyIndex + 1
    end

    -- Spawn pure collector scouts (no weapons, just magnetic fields)
    local collectorCount = 3
    for i = 1, collectorCount do
        local x = Constants.world_min_x + math.random() * (Constants.world_max_x - Constants.world_min_x)
        local y = Constants.world_min_y + math.random() * (Constants.world_max_y - Constants.world_min_y)
        
        local designId = "red_scout"
        local shipId = ShipLoader.createShip(designId, x, y, "ai")
        
        if shipId then
            -- Don't equip a turret - these are pure collectors
            -- The ShipLoader already added Cargo and MagneticField for red_scout
            local ai = ECS.getComponent(shipId, "AIController")
            if ai then
                ai.state = "patrol"
                ai.speed = 80  -- Slower roaming
                ai.detectionRadius = 0  -- Don't detect anything
            end
        end
    end

    print("Game entities created and systems initialized")
    print("Pilot and starting drone spawned at world center (0, 0)")
    print("Asteroid field spawned: 150 asteroids in thick band across world")
    print("Enemy ships spawned: 5 mining lasers + 10 cannons = 15 total enemies distributed across the map")
    print("Collector scouts spawned: 3 autonomous bit collectors with magnetic fields")
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
        love.event.quit()
    elseif key == 'tab' then
        UISystem.toggleCargoWindow()
        return
    elseif key == 'f5' then
        local HUDSystem = require('src.systems.hud')
        if HUDSystem and HUDSystem.toggle then
            HUDSystem.toggle()
        end
        return
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