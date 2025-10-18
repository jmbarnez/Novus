---@diagnostic disable: undefined-global
-- Space Drone Adventure - Love2D Entry Point
-- Minimal Love2D main file that delegates to core game logic

local Core = require('src.core')
local Scaling = require('src.scaling')

-- Love2D callback functions - delegate to core module
function love.load()
    love.window.setVSync(1) -- lock to vsync, usually 60Hz
    Core.init()
    Scaling.update()
end

function love.update(dt)
    Core.update(dt)
end

function love.draw()
    Core.draw()
end

function love.keypressed(key)
    if key == "f9" then
        local ECS = require('src.ecs')
        ECS.debugCanvasEntities()
    end
    Core.keypressed(key)
end

function love.keyreleased(key)
    Core.keyreleased(key)
end

function love.mousemoved(x, y, dx, dy, isTouch)
    Core.mousemoved(x, y, dx, dy, isTouch)
end

function love.mousereleased(x, y, button)
    Core.mousereleased(x, y, button)
end

function love.wheelmoved(x, y)
    Core.wheelmoved(x, y)
end


function love.mousepressed(x, y, button)
    print("love.mousepressed called (top-level)", x, y, button)
    Core.mousepressed(x, y, button)
end

function love.quit()
    Core.quit()
end

function love.resize(w, h)
    Scaling.update()
    -- Optional: If your HUD or UI needs to reset
    if Core.onResize then Core.onResize(w, h) end
end
