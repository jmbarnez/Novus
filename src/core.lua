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
    local pilotCargo = ECS.getComponent(pilotId, "Cargo")
    if pilotCargo then
        pilotCargo.items[miningLaserId] = 1
        pilotCargo.items[basicCannonId] = 1
        pilotCargo.items[combatLaserId] = 1
    end

    -- Create Drone Entity (starter ship)
    local droneId = ECS.createEntity()
    ECS.addComponent(droneId, "Position", Components.Position(0, 0))
    ECS.addComponent(droneId, "Velocity", Components.Velocity(0, 0))
    ECS.addComponent(droneId, "Acceleration", Components.Acceleration(0, 0))
    ECS.addComponent(droneId, "Physics", Components.Physics(Constants.player_friction, Constants.player_max_speed, 1))
    ECS.addComponent(droneId, "Boundary", Components.Boundary(-5000, 5000, -5000, 5000))
    ECS.addComponent(droneId, "CameraTarget", Components.CameraTarget())
    ECS.addComponent(droneId, "PolygonShape", Components.PolygonShape({
        -- Main hexagonal body
        {x = 0, y = -10}, {x = 8.66, y = -5}, {x = 8.66, y = 5}, 
        {x = 0, y = 10}, {x = -8.66, y = 5}, {x = -8.66, y = -5}
    }, 0))
    -- The main Renderable for the hexagonal drone
    ECS.addComponent(droneId, "Renderable", Components.Renderable("polygon", nil, nil, nil, {0.5, 0.5, 0.5, 1}))
    ECS.addComponent(droneId, "TrailEmitter", Components.TrailEmitter(Constants.trail_emit_rate, Constants.trail_max_particles, Constants.trail_particle_life, Constants.trail_spread_angle, Constants.trail_speed_multiplier))
    ECS.addComponent(droneId, "Health", Components.Health(100, 100))
    ECS.addComponent(droneId, "Collidable", Components.Collidable(10)) -- Bounding radius for hexagon is approx 10
    ECS.addComponent(droneId, "Turret", Components.Turret("", 0.2)) -- Turret starts empty, only operational when module equipped
    ECS.addComponent(droneId, "TurretSlots", Components.TurretSlots(1)) -- Add TurretSlots component, max 1 slot for drone
    ECS.addComponent(droneId, "Magnet", Components.Magnet(200, 120, 24)) -- Attract items within 200 units
    -- Mark that this drone is controlled by the pilot
    ECS.addComponent(droneId, "ControlledBy", Components.ControlledBy(pilotId))

    -- Link pilot InputControlled to the drone
    local inputComp = ECS.getComponent(pilotId, "InputControlled")
    if inputComp then
        inputComp.targetEntity = droneId
    end

    -- Load turret modules (including basic cannon)
    Systems.TurretSystem.loadTurretModules("src/modules")

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
        {count = 800, brightness = 0.9, parallaxFactor = 0.01},  -- Very far distant stars
        {count = 600, brightness = 1.0, parallaxFactor = 0.03},  -- Far distant stars
        {count = 400, brightness = 1.0, parallaxFactor = 0.08}   -- Medium distant stars
    }
    local parallaxObject = Parallax.new(starLayers, 10000)
    ECS.addComponent(starFieldId, "StarField", parallaxObject)

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

    print("Game entities created and systems initialized")
    print("Pilot and starting drone spawned at world center (0, 0)")
    print("Asteroids spawned: " .. Constants.asteroid_cluster_count .. " in cluster around center")
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