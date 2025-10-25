---@diagnostic disable: undefined-global
function love.conf(t)
    t.title = "NOVUS"
    t.version = "11.3"
    t.console = true

    -- Window settings: always start in 1920x1080 windowed mode
    t.window.width = 1920
    t.window.height = 1080
    t.window.borderless = false
    t.window.fullscreen = false
    t.window.resizable = false

    -- Performance settings
    t.window.vsync = 1
    t.window.msaa = 0
end
