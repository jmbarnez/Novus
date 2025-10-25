---@diagnostic disable: undefined-global
function love.conf(t)
    t.title = "NOVUS"
    t.version = "11.3"
    t.console = true
    
    -- Window settings - single resolution to avoid scaling issues
    t.window.width = 1600
    t.window.height = 900
    t.window.borderless = false  -- Start in windowed mode
    t.window.fullscreen = false
    t.window.resizable = false  -- Disable resizing
    
    -- Performance settings
    t.window.vsync = 1  -- Enable VSync to sync with monitor refresh rate
    t.window.msaa = 0   -- Disable MSAA antialiasing for performance
end
