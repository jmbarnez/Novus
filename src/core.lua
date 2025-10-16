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
    ECS.registerSystem("MiningSystem", Systems.MiningSystem)
    ECS.registerSystem("DestructionSystem", Systems.DestructionSystem)
    ECS.registerSystem("DebrisSystem", Systems.DebrisSystem)

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
    ECS.addComponent(playerId, "Renderable", Components.Renderable("polygon", nil, nil, nil, {0.5, 0.5, 0.5, 1})) -- Changed to polygon
    ECS.addComponent(playerId, "InputControlled", Components.InputControlled())
    ECS.addComponent(playerId, "Boundary", Components.Boundary(-5000, 5000, -5000, 5000))
    ECS.addComponent(playerId, "CameraTarget", Components.CameraTarget())
    ECS.addComponent(playerId, "PolygonShape", Components.PolygonShape({
        {x = -4, y = -4}, {x = 4, y = -4}, {x = 4, y = 4}, {x = -4, y = 4} -- 8x8 square for drone body
    }, 0))
    ECS.addComponent(playerId, "TrailEmitter", Components.TrailEmitter(Constants.trail_emit_rate, Constants.trail_max_particles, Constants.trail_particle_life, Constants.trail_spread_angle, Constants.trail_speed_multiplier))
    ECS.addComponent(playerId, "Health", Components.Health(100, 100))
    ECS.addComponent(playerId, "Collidable", Components.Collidable(6)) -- Bounding radius for 8x8 square polygon is approx 6

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

-- Input handling
function Core.keypressed(key)
    if key == 'escape' then
        love.event.quit()
    end
    Systems.InputSystem.keypressed(key)
end

function Core.keyreleased(key)
    Systems.InputSystem.keyreleased(key)
end

function Core.mousemoved(x, y, dx, dy, isTouch)
    Systems.InputSystem.mousemoved(x, y, dx, dy, isTouch)
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