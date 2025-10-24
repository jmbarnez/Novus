---@diagnostic disable: undefined-global
function love.conf(t)
    t.title = "NOVUS"
    t.version = "11.3"
    t.console = true
    
    -- Performance settings
    t.window.vsync = -1  -- Adaptive VSync (allows higher refresh rates up to monitor limit)
    t.window.msaa = 0   -- Disable MSAA antialiasing for performance
end
