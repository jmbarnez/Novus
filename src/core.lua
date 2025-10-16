-- Space Drone Adventure - Core Game Logic
-- Handles game initialization, entity creation, and game state management

local Core = {}

-- Dependencies
local ECS = require('src.ecs')
local Systems = require('src.systems')
local Components = require('src.components')
local Parallax = require('src.parallax')
local Constants = require('src.constants')
local Procedural = require('src.procedural')
local UISystem = require('src.systems.ui')

-- Game initialization
function Core.init()
    print("=== Space Drone Adventure Loading ===")

    -- Set fullscreen mode
    local w, h = love.window.getDesktopDimensions()
    love.window.setMode(w, h, {fullscreen = true, fullscreentype = "desktop"})

    -- Initialize procedural generation system
    Procedural.init()

    -- Register all ECS systems
    ECS.registerSystem("PhysicsSystem", Systems.PhysicsSystem)
    ECS.registerSystem("BoundarySystem", Systems.BoundarySystem)
    ECS.registerSystem("InputSystem", Systems.InputSystem)
    ECS.registerSystem("RenderSystem", Systems.RenderSystem)
    ECS.registerSystem("CameraSystem", Systems.CameraSystem)
    ECS.registerSystem("UISystem", Systems.UISystem)
    ECS.registerSystem("TrailSystem", Systems.TrailSystem)
    ECS.registerSystem("CollisionSystem", Systems.CollisionSystem)
    ECS.registerSystem("MagnetSystem", Systems.MagnetSystem)
    ECS.registerSystem("DestructionSystem", Systems.DestructionSystem)
    ECS.registerSystem("DebrisSystem", Systems.DebrisSystem)
    ECS.registerSystem("TurretSystem", Systems.TurretSystem)

    -- Create Canvas Entity
    local canvasId = ECS.createEntity()
    ECS.addComponent(canvasId, "Canvas", Components.Canvas(Constants.screen_width, Constants.screen_height))

    -- Create Player Entity
    local playerId = ECS.createEntity()

    -- Add player components
    ECS.addComponent(playerId, "Position", Components.Position(0, 0))
    ECS.addComponent(playerId, "Velocity", Components.Velocity(0, 0))
    ECS.addComponent(playerId, "Acceleration", Components.Acceleration(0, 0))
    ECS.addComponent(playerId, "Physics", Components.Physics(Constants.player_friction, Constants.player_max_speed, 1))
    ECS.addComponent(playerId, "InputControlled", Components.InputControlled())
    ECS.addComponent(playerId, "Boundary", Components.Boundary(-5000, 5000, -5000, 5000))
    ECS.addComponent(playerId, "CameraTarget", Components.CameraTarget())
    ECS.addComponent(playerId, "PolygonShape", Components.PolygonShape({
        -- Main hexagonal body
        {x = 0, y = -10}, {x = 8.66, y = -5}, {x = 8.66, y = 5}, 
        {x = 0, y = 10}, {x = -8.66, y = 5}, {x = -8.66, y = -5}
    }, 0))
    -- The main Renderable for the hexagonal drone
    ECS.addComponent(playerId, "Renderable", Components.Renderable("polygon", nil, nil, nil, {0.5, 0.5, 0.5, 1}))
    ECS.addComponent(playerId, "TrailEmitter", Components.TrailEmitter(Constants.trail_emit_rate, Constants.trail_max_particles, Constants.trail_particle_life, Constants.trail_spread_angle, Constants.trail_speed_multiplier))
    ECS.addComponent(playerId, "Health", Components.Health(100, 100))
    ECS.addComponent(playerId, "Collidable", Components.Collidable(10)) -- Bounding radius for hexagon is approx 10
    ECS.addComponent(playerId, "Turret", Components.Turret("mining_laser", 0.2)) -- Add Turret component to player, renamed module
    ECS.addComponent(playerId, "Cargo", Components.Cargo({}, 10))
    ECS.addComponent(playerId, "Magnet", Components.Magnet(200, 120, 24)) -- Attract items within 200 units

    -- Load turret modules
    Systems.TurretSystem.loadTurretModules("src/turret_modules")

    -- Create Camera Entity
    local cameraId = ECS.createEntity()
    ECS.addComponent(cameraId, "Position", Components.Position(0, 0))
    ECS.addComponent(cameraId, "Camera", Components.Camera(Constants.screen_width, Constants.screen_height))

    -- Create UI Entity
    local uiId = ECS.createEntity()
    ECS.addComponent(uiId, "UI", Components.UI())
    ECS.addComponent(uiId, "UITag", Components.UITag())

    -- Create Starfield Entity (background)
    local starFieldId = ECS.createEntity()
    local starLayers = {
        {count = 200, brightness = 0.9, parallaxFactor = 0.01},  -- Very far distant stars
        {count = 150, brightness = 1.0, parallaxFactor = 0.03},  -- Far distant stars
        {count = 100, brightness = 1.0, parallaxFactor = 0.08}   -- Medium distant stars
    }
    -- Create the actual parallax object with generated stars
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
    print("Player spawned at world center (0, 0)")
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
    ECS.draw()
end


function Core.keypressed(key)
    if key == 'escape' then
        love.event.quit()
    elseif key == 'tab' then
        UISystem.toggleCargoWindow()
        return
    end
    UISystem.keypressed = UISystem.keypressed or function(_) end
    UISystem.keypressed(key)
    Systems.InputSystem.keypressed(key)
end

function Core.mousepressed(x, y, button)
    print("Core.mousepressed called", x, y, button)
    if UISystem.mousepressed then
        UISystem.mousepressed(x, y, button)
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

return Core