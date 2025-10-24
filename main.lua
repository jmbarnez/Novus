---@diagnostic disable: undefined-global
-- NOVUS - Love2D Entry Point
-- Minimal Love2D main file that delegates to core game logic

local Core = require('src.core')
local Constants = require('src.constants')
local Scaling = require('src.scaling')
local StartScreen = require('src.start_screen')
local LoadingScreen = require('src.loading_screen')
local TimeManager = require('src.time_manager')
local Profiler = require('src.profiler')

local gameState = "start" -- Possible values: "start", "loading", "game"
local loadingTimer = 0
local loadingDuration = 0.8 -- seconds

-- Global function to return to main menu
function returnToMainMenu()
    if gameState == "game" then
        Core.quit()
        gameState = "start"
    end
end

-- Love2D callback functions - delegate to core module

function love.load()
    -- Initialize time manager with unlocked FPS
    TimeManager.init()
    TimeManager.setTargetFps(nil)  -- nil = unlimited FPS
    
    love.window.setMode(Constants.screen_width, Constants.screen_height, {
        fullscreen = false, 
        resizable = false,
        vsync = 0,  -- Force VSync OFF
        borderless = true  -- Enable borderless windowed mode
    })
    
    -- Verify VSync is off
    print("=== Display Settings ===")
    print("VSync enabled:", love.window.getVSync())
    print("Display count:", love.window.getDisplayCount())
    if love.window.getDisplayName then
        local name = love.window.getDisplayName(1)
        print("Primary display:", name)
    end
    -- Get desktop dimensions
    local _, _, flags = love.window.getMode()
    print("Window VSync flag:", flags.vsync or 0)

    -- Check monitor refresh rate
    local displayModes = love.window.getFullscreenModes(1)
    if displayModes and #displayModes > 0 then
        print("Available display modes:")
        for i, mode in ipairs(displayModes) do
            if i <= 3 then  -- Show first 3 modes
                local refresh = mode.refreshrate or mode.refreshRate or "unknown"
                print(string.format("  %dx%d @ %sHz", mode.width, mode.height, tostring(refresh)))
            end
        end
    else
        print("No display modes available")
    end
    
    Scaling.update()
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
    Scaling.update()
    if gameState == "game" and Core.onResize then
        Core.onResize(w, h)
    end
end
