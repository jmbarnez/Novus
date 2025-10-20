---@diagnostic disable: undefined-global
-- Space Drone Adventure - Love2D Entry Point
-- Minimal Love2D main file that delegates to core game logic

local Core = require('src.core')
local Scaling = require('src.scaling')
local StartScreen = require('src.start_screen')
local LoadingScreen = require('src.loading_screen')

local gameState = "start" -- Possible values: "start", "loading", "game"
local loadingTimer = 0
local loadingDuration = 0.8 -- seconds

-- Love2D callback functions - delegate to core module

function love.load()
    love.window.setVSync(0)
    local Constants = require('src.constants')
    love.window.setMode(Constants.screen_width, Constants.screen_height, {fullscreen = false, resizable = false})
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
        Core.update(dt)
    end
end


function love.draw()
    if gameState == "start" then
        StartScreen.draw()
    elseif gameState == "loading" then
        LoadingScreen.draw()
    else
        Core.draw()
    end
end


function love.keypressed(key)
    -- Only allow mouse click or Escape to start/close game from start screen
    if gameState == "start" then
        if StartScreen.keypressed then StartScreen.keypressed(key) end
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
    -- ...existing code...
    end

function love.resize(w, h)
    Scaling.update()
    if gameState == "game" and Core.onResize then
        Core.onResize(w, h)
    end
end
