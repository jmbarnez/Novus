---@diagnostic disable: undefined-global
-- NOVUS - Core Game Logic
-- Coordinates game initialization, update loop, and input handling

local Core = {}

-- Dependencies
local ECS = require('src.ecs')
local Systems = require('src.systems')
local UISystem = require('src.systems.ui')
local GameInit = require('src.game_init')
local GameInput = require('src.game_input')
local Scaling = require('src.scaling')
local DisplayManager = require('src.display_manager')

-- Game initialization
function Core.init()
    GameInit.init()
end

-- Main game update loop
function Core.update(dt)
    -- Check if settings window is open to pause the game
    if UISystem.isSettingsWindowOpen and UISystem.isSettingsWindowOpen() then
        -- Pause the game when settings window is open
        return
    end
    
    -- Update all ECS systems
    ECS.update(dt)
end

-- Main game render loop
function Core.draw()
    love.graphics.clear(0.01, 0.01, 0.02)

    ECS.draw() -- Draw all world and UI systems
end


function Core.keypressed(key)
    GameInput.keypressed(key)
end

function Core.mousepressed(x, y, button)
    GameInput.mousepressed(x, y, button)
end

function Core.keyreleased(key)
    GameInput.keyreleased(key)
end

function Core.mousemoved(x, y, dx, dy, isTouch)
    GameInput.mousemoved(x, y, dx, dy, isTouch)
end

function Core.mousereleased(x, y, button)
    GameInput.mousereleased(x, y, button)
end

function Core.wheelmoved(x, y)
    GameInput.wheelmoved(x, y)
end

-- Game cleanup - completely reset all game state
function Core.quit()
    print("NOVUS shutting down...")
    
    -- Close all UI windows
    if UISystem then
        -- Close all windows
        if UISystem.setShipWindowOpen then UISystem.setShipWindowOpen(false) end
        if UISystem.setMapWindowOpen then UISystem.setMapWindowOpen(false) end
        if UISystem.setSettingsWindowOpen then UISystem.setSettingsWindowOpen(false) end
        
        -- Reset UI state
        if UISystem.releaseMouse then UISystem.releaseMouse() end
        if UISystem.setWindowFocus then UISystem.setWindowFocus(nil) end
    end
    
    -- Release canvas resources before clearing ECS
    local canvasEntities = ECS.getEntitiesWith({"Canvas"})
    for _, canvasId in ipairs(canvasEntities) do
        local canvasComp = ECS.getComponent(canvasId, "Canvas")
        if canvasComp then
            canvasComp.canvas = nil
        end
    end

    DisplayManager.shutdown()
    
    -- Clear all entity pools before clearing ECS
    local EntityPool = require('src.entity_pool')
    EntityPool.clearAll()
    -- Clear all ECS entities, components, and systems
    ECS.clear()
    
    -- Reset global debug flags
    if _G.canvasDebugPrinted then
        _G.canvasDebugPrinted = nil
    end
    
    -- Reset any other global state that might persist
    -- This ensures a completely fresh start when the game is restarted
    print("Game state completely cleared")
end

function Core.onResize(w, h)
    Scaling.update()

    -- Update UI system
    if UISystem and UISystem.onResize then
        UISystem.onResize(w, h)
    end

    -- Update camera system
    local CameraSystem = require('src.systems.camera')
    if CameraSystem and CameraSystem.onResize then
        CameraSystem.onResize(w, h)
    end

    -- Update any other systems that have onResize functions
    local Systems = require('src.systems')
    for systemName, system in pairs(Systems) do
        if system.onResize and systemName ~= "UISystem" and systemName ~= "CameraSystem" then
            system.onResize(w, h)
        end
    end
end

return Core
