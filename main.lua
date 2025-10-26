---@diagnostic disable: undefined-global
-- NOVUS - Love2D Entry Point
-- Minimal Love2D main file that delegates to core game logic

local Core = require('src.core')
local Constants = require('src.constants')
local Scaling = require('src.scaling')
local DisplayManager = require('src.display_manager')
local StartScreen = require('src.start_screen')
local LoadingScreen = require('src.loading_screen')
local TimeManager = require('src.time_manager')
local Profiler = require('src.profiler')

local gameState = "start" -- Possible values: "start", "loading", "game"
local loadingTimer = 0
local loadingDuration = 0.8 -- seconds

-- Game state management module (exposed for UI)
_G.Game = _G.Game or {}

function _G.Game.returnToMainMenu()
    if gameState == "game" then
        Core.quit()
        gameState = "start"
    end
end

function _G.Game.save(slotName)
    return Core.saveGame(slotName)
end

function _G.Game.load(slotName)
    local ok, err = Core.loadGame(slotName)
    if ok then
        gameState = "game"
    end
    return ok, err
end

function _G.Game.loadSnapshot(snapshot)
    local ok, err = Core.loadSnapshot(snapshot)
    if ok then
        gameState = "game"
    end
    return ok, err
end

-- Love2D callback functions - delegate to core module

function love.load()
    -- Initialize time manager with unlocked FPS
    TimeManager.init()
    TimeManager.setTargetFps(nil)  -- nil = unlimited FPS
    
    -- Display settings confirmation (window already set by conf.lua)
    print("=== Display Settings ===")
    print("VSync enabled:", love.window.getVSync())
    print("Display count:", love.window.getDisplayCount())
    
    DisplayManager.init()
    Scaling.update()
    
    -- Initialize shader manager early so start screen can use aurora shader
    print("=== Initializing ShaderManager ===")
    local ShaderManager = require('src.shader_manager')
    ShaderManager.init()
    print("=== ShaderManager initialization complete ===")
    
    -- Only initialize game when leaving start screen
end

function love.update(dt)
    if gameState == "start" then
        if StartScreen.update then StartScreen.update(dt) end
    elseif gameState == "loading" then
        loadingTimer = loadingTimer + dt
        if loadingTimer >= loadingDuration then
            Core.init()
            gameState = "game"
        end
    elseif gameState == "game" then
        Profiler.start("update_total")
        
        -- Fixed timestep update
        local updateCount, alpha = TimeManager.step(dt)
        
        -- Perform fixed timestep updates
        Profiler.start("update_logic")
        for i = 1, updateCount do
            Core.update(TimeManager.getFixedDt())
        end
        Profiler.stop("update_logic")
        
        Profiler.stop("update_total")
    end
end


function love.draw()
    if gameState == "start" then
        StartScreen.draw()
    elseif gameState == "loading" then
        LoadingScreen.draw()
    else
        Profiler.start("draw_total")
        Core.draw()
        -- Ensure death overlay renders above everything drawn by Core
        local DeathOverlay = require('src.ui.death_overlay')
        DeathOverlay.draw()
        Profiler.stop("draw_total")
        Profiler.frame()
        -- FPS cap enforcement (software sleep)
        local fps = TimeManager.getTargetFps and TimeManager.getTargetFps() or nil
        if fps and fps > 0 then
            local frame_time = 1 / fps
            local used_time = love.timer.getDelta()
            if used_time < frame_time then
                love.timer.sleep(frame_time - used_time)
            end
        end
    end
end


function love.keypressed(key)
    -- Only allow mouse click or Escape to start/close game from start screen
    if gameState == "start" then
        if StartScreen.keypressed then StartScreen.keypressed(key) end
        return
    end
    
    -- Profiler controls (available anywhere)
    if key == "f10" then
        -- Toggle profiler
        if Profiler.enabled then
            Profiler.print()
            Profiler.disable()
            print("Profiler DISABLED")
        else
            Profiler.reset()
            Profiler.enable()
            print("Profiler ENABLED - Press F10 again to see results")
        end
        return
    end
    
    if key == "f9" then
        local ECS = require('src.ecs')
        ECS.debugCanvasEntities()
    end
    Core.keypressed(key)
end


function love.keyreleased(key)
    if gameState == "game" then
        Core.keyreleased(key)
    end
end


function love.mousemoved(x, y, dx, dy, isTouch)
    if gameState == "game" then
        Core.mousemoved(x, y, dx, dy, isTouch)
    end
end


function love.mousereleased(x, y, button)
    if gameState == "game" then
        Core.mousereleased(x, y, button)
    end
end


function love.wheelmoved(x, y)
    if gameState == "game" then
        Core.wheelmoved(x, y)
    end
end




function love.mousepressed(x, y, button)
    if gameState == "start" then
        if StartScreen.mousepressed and StartScreen.mousepressed(x, y, button) then
            gameState = "loading"
            loadingTimer = 0
            return
        end
    elseif gameState == "game" then
        print("love.mousepressed called (top-level)", x, y, button)
        Core.mousepressed(x, y, button)
    end
end


function love.quit()
    if gameState == "game" then
        Core.quit()
    end
end

function love.resize(w, h)
    DisplayManager.onResize(w, h)
    Scaling.update()

    -- Always sync render targets so the next frame draws correctly
    local RenderCanvas = require('src.systems.render.canvas')
    RenderCanvas.resizeCanvas()

    if gameState == "game" and Core.onResize then
        Core.onResize(w, h)
    end
end
