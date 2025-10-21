---@diagnostic disable: undefined-global
function love.conf(t)
    t.title = "Space Drone Adventure"
    t.version = "11.3"
    t.console = true
    
    -- Performance settings
    t.window.vsync = 0  -- Force VSync OFF (0 = off, 1 = on, -1 = adaptive)
    t.window.msaa = 0   -- Disable MSAA antialiasing for performance
end
