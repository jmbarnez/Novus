-- Space Drone Adventure - Love2D Entry Point
-- Minimal Love2D main file that delegates to core game logic

local Core = require('src.core')

-- Love2D callback functions - delegate to core module
function love.load()
    Core.init()
end

function love.update(dt)
    Core.update(dt)
end

function love.draw()
    Core.draw()
end

function love.keypressed(key)
    Core.keypressed(key)
end

function love.keyreleased(key)
    Core.keyreleased(key)
end

function love.quit()
    Core.quit()
end
