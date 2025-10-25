---@diagnostic disable: undefined-global
function love.conf(t)
    t.title = "NOVUS"
    t.version = "11.3"
    t.console = true
    
    -- Window settings - default to common 1080p while allowing in-game changes
    t.window.width = 1920
    t.window.height = 1080
    t.window.borderless = false  -- Start in windowed mode
    t.window.fullscreen = false
    t.window.resizable = false  -- Disable resizing
    
    -- Performance settings
    t.window.vsync = 1  -- Enable VSync to sync with monitor refresh rate
    t.window.msaa = 0   -- Disable MSAA antialiasing for performance
end
