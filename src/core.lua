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
    ECS.registerSystem("AISystem", Systems.AISystem)
    ECS.registerSystem("CollisionSystem", Systems.CollisionSystem)
    ECS.registerSystem("MagnetSystem", Systems.MagnetSystem)
    ECS.registerSystem("DestructionSystem", Systems.DestructionSystem)
    ECS.registerSystem("DebrisSystem", Systems.DebrisSystem)
    ECS.registerSystem("TurretSystem", Systems.TurretSystem)
    ECS.registerSystem("ProjectileSystem", Systems.ProjectileSystem)

    -- Create Canvas Entity
    local canvasId = ECS.createEntity()
    ECS.addComponent(canvasId, "Canvas", Components.Canvas(Constants.screen_width, Constants.screen_height))

    -- Create Pilot (Player) Entity
    local pilotId = ECS.createEntity()
    ECS.addComponent(pilotId, "InputControlled", Components.InputControlled())
    ECS.addComponent(pilotId, "Player", Components.Player())
    ECS.addComponent(pilotId, "Cargo", Components.Cargo({}, 10))
    ECS.addComponent(pilotId, "Skills", Components.Skills())

    -- Give pilot (player) initial turret items in their cargo
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
    
    -- Add initial items to pilot cargo
    local pilotCargo = ECS.getComponent(pilotId, "Cargo")
    if pilotCargo then
        pilotCargo.items[miningLaserId] = 1
        pilotCargo.items[basicCannonId] = 1
        pilotCargo.items[combatLaserId] = 1
        pilotCargo.items[salvageLaserId] = 1
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
        {count = 80, brightness = 0.9, parallaxFactor = 0},      -- Static twinkling stars
        {count = 800, brightness = 0.7, parallaxFactor = 0.01},  -- Very far distant stars
        {count = 600, brightness = 0.5, parallaxFactor = 0.03},  -- Far distant stars
        {count = 400, brightness = 0.35, parallaxFactor = 0.08}  -- Medium distant stars
    }
    local parallaxObject = Parallax.new(starLayers, 10000)
    ECS.addComponent(starFieldId, "StarField", parallaxObject)

    -- Create enemy ship using red_scout design (will be red)
    local enemyId = ShipLoader.createShip("red_scout", 300, -200, "ai")

    -- Spawn asteroid cluster around the start area
    local asteroidCluster = Procedural.spawnMultiple("asteroid", Constants.asteroid_cluster_count, "cluster", {
        centerX = 0,
        centerY = 0,
        radius = Constants.asteroid_cluster_radius
    })
    
    -- Create asteroid entities from generated data
    for _, asteroidData in ipairs(asteroidCluster) do
        local asteroidId = ECS.createEntity()
        for componentType, componentData in pairs(asteroidData) do
            ECS.addComponent(asteroidId, componentType, componentData)
        end
    end

    -- Create asteroid field line extending across the map
    local asteroidLineCount = 80
    local lineStartX = Constants.world_min_x
    local lineEndX = Constants.world_max_x
    local lineY = 0  -- Y position of the line
    
    for i = 1, asteroidLineCount do
        local x = lineStartX + ((i - 1) / (asteroidLineCount - 1)) * (lineEndX - lineStartX)
        -- Add some vertical variation to make it less perfectly straight
        local y = lineY + math.sin(i * 0.5) * 200 + (math.random() - 0.5) * 300
        
        local size = Procedural.randomRange(Constants.asteroid_size_min, Constants.asteroid_size_max)
        local vertexCount = math.random(Constants.asteroid_vertices_min, Constants.asteroid_vertices_max)
        local vertices = Procedural.generatePolygonVertices(vertexCount, size / 2)
        local velocity = Procedural.randomVelocity(5, 15)  -- Slower movement for line asteroids
        local angularVelocity = Procedural.randomRange(Constants.asteroid_rotation_min, Constants.asteroid_rotation_max)
        
        local asteroidMass = size * size * 0.5
        local rotationalInertia = size * size * size * 2
        
        local asteroidId = ECS.createEntity()
        ECS.addComponent(asteroidId, "Position", Components.Position(x, y))
        ECS.addComponent(asteroidId, "Velocity", Components.Velocity(velocity.vx, velocity.vy))
        ECS.addComponent(asteroidId, "Physics", Components.Physics(0.999, asteroidMass))
        ECS.addComponent(asteroidId, "PolygonShape", Components.PolygonShape(vertices, math.random() * 2 * math.pi))
        ECS.addComponent(asteroidId, "AngularVelocity", Components.AngularVelocity(angularVelocity))
        ECS.addComponent(asteroidId, "RotationalMass", Components.RotationalMass(rotationalInertia))
        ECS.addComponent(asteroidId, "Collidable", Components.Collidable(size / 2))
        ECS.addComponent(asteroidId, "Durability", Components.Durability(size * 2, size * 2))
        ECS.addComponent(asteroidId, "Asteroid", Components.Asteroid())
        ECS.addComponent(asteroidId, "Renderable", Components.Renderable("polygon", nil, nil, nil, {0.6, 0.4, 0.2, 1}))
    end

    -- Spawn enemy ships across the map
    local enemyCount = 12
    local enemySpacing = (Constants.world_max_x - Constants.world_min_x) / (enemyCount + 1)
    
    for i = 1, enemyCount do
        local x = Constants.world_min_x + i * enemySpacing + (math.random() - 0.5) * 500
        local y = (math.random() - 0.5) * 4000  -- Random Y position
        
        -- Vary enemy designs
        local designChoice = math.random(1, 3)
        local designId = "red_scout"
        if designChoice == 2 then
            designId = "standard_combat"
        elseif designChoice == 3 then
            designId = "starter_hexagon"
        end
        
        ShipLoader.createShip(designId, x, y, "ai")
    end

    print("Game entities created and systems initialized")
    print("Pilot and starting drone spawned at world center (0, 0)")
    print("Asteroids spawned: " .. Constants.asteroid_cluster_count .. " in cluster around center")
    print("Asteroid field line spawned: 80 asteroids extending across map")
    print("Enemy ships spawned: 12 enemies distributed across the map")
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
    -- Minimap is now drawn as part of HUD, not separately
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