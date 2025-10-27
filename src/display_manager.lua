---@diagnostic disable: undefined-global
-- Display Manager - Centralized window, resolution, and canvas management
-- Provides a single authority for render resolution, window mode, and render targets

local DisplayManager = {}

-- Supported internal render resolutions (reference coordinates for the game canvas)
DisplayManager.renderResolutions = {
    { w = 1280, h = 720, label = "1280x720" },
    { w = 1366, h = 768, label = "1366x768" },
    { w = 1600, h = 900, label = "1600x900" },
    { w = 1920, h = 1080, label = "1920x1080" },
    { w = 2560, h = 1440, label = "2560x1440" },
}

DisplayManager.windowMode = "windowed" -- Only windowed mode supported
DisplayManager.scalingMode = "fit"     -- 'fit' maintains aspect ratio with letterboxing

DisplayManager.renderWidth = 1920
DisplayManager.renderHeight = 1080
DisplayManager.windowWidth = 1920
DisplayManager.windowHeight = 1080
DisplayManager.desktopWidth = 1920
DisplayManager.desktopHeight = 1080

DisplayManager._worldCanvas = nil
DisplayManager._worldCanvasW = 0
DisplayManager._worldCanvasH = 0
DisplayManager._postCanvas = nil
DisplayManager._postCanvasW = 0
DisplayManager._postCanvasH = 0
DisplayManager.vsyncEnabled = true

local function copyFlags(flags)
    local newFlags = {}
    if not flags then return newFlags end
    for k, v in pairs(flags) do
        newFlags[k] = v
    end
    return newFlags
end

local function hasWindowApi()
    return love and love.window and love.window.getMode and love.window.setMode
end

local function normalizeVsyncFlag(value)
    if type(value) == "number" then
        return value ~= 0
    end
    return not not value
end

local function detectDesktopResolution()
    if not (love and love.window and love.window.getDesktopDimensions) then
        return
    end

    local ok, w, h = pcall(love.window.getDesktopDimensions)
    if ok and type(w) == "number" and type(h) == "number" then
        DisplayManager.desktopWidth = w
        DisplayManager.desktopHeight = h
    end
end

function DisplayManager.init()
    detectDesktopResolution()
    DisplayManager.updateWindowSize()

    -- Default render resolution to current window size on startup
    DisplayManager.renderWidth = DisplayManager.windowWidth
    DisplayManager.renderHeight = DisplayManager.windowHeight
    DisplayManager.ensureWorldCanvas()

    -- Cache current window mode
    if hasWindowApi() then
        local _, _, flags = love.window.getMode()
        if flags then
            DisplayManager.vsyncEnabled = normalizeVsyncFlag(flags.vsync)
            if flags.fullscreen then
                DisplayManager.windowMode = "fullscreen"
            elseif flags.borderless then
                DisplayManager.windowMode = "borderless"
            else
                DisplayManager.windowMode = "windowed"
            end
        end
    end

    -- Small init confirmation print (helpful to diagnose conf.lua vs runtime overrides)
    if hasWindowApi() then
        local w, h, f = love.window.getMode()
        local fs = f and f.fullscreen or false
        local br = f and f.borderless or false
        local vs = f and normalizeVsyncFlag(f.vsync) or DisplayManager.vsyncEnabled
        print(string.format("[DisplayManager] init mode: %s (fullscreen=%s, borderless=%s, vsync=%s) size=%dx%d", DisplayManager.windowMode, tostring(fs), tostring(br), tostring(vs), w or 0, h or 0))
    end

    -- At startup we respect the current Love window flags (which are set from conf.lua).
    -- Do not force a specific window mode here so the game's configuration is preserved.
end

function DisplayManager.updateWindowSize()
    if love and love.graphics and love.graphics.getDimensions then
        DisplayManager.windowWidth, DisplayManager.windowHeight = love.graphics.getDimensions()
    end
end

function DisplayManager.onResize(w, h)
    DisplayManager.windowWidth = w
    DisplayManager.windowHeight = h
end

function DisplayManager.getWindowSize()
    return DisplayManager.windowWidth, DisplayManager.windowHeight
end

function DisplayManager.getWindowMode()
    return DisplayManager.windowMode
end

function DisplayManager.ensureWorldCanvas()
    if DisplayManager._worldCanvas
        and DisplayManager._worldCanvasW == DisplayManager.renderWidth
        and DisplayManager._worldCanvasH == DisplayManager.renderHeight then
        return DisplayManager._worldCanvas
    end

    if DisplayManager._worldCanvas then
        DisplayManager._worldCanvas:release()
        DisplayManager._worldCanvas = nil
    end

    DisplayManager._worldCanvas = love.graphics.newCanvas(DisplayManager.renderWidth, DisplayManager.renderHeight)
    DisplayManager._worldCanvas:setFilter('linear', 'linear')
    DisplayManager._worldCanvasW = DisplayManager.renderWidth
    DisplayManager._worldCanvasH = DisplayManager.renderHeight
    return DisplayManager._worldCanvas
end

function DisplayManager.releaseWorldCanvas()
    if DisplayManager._worldCanvas then
        DisplayManager._worldCanvas:release()
        DisplayManager._worldCanvas = nil
        DisplayManager._worldCanvasW = 0
        DisplayManager._worldCanvasH = 0
    end
end

function DisplayManager.getWorldCanvas()
    return DisplayManager.ensureWorldCanvas()
end

function DisplayManager.getRenderDimensions()
    return DisplayManager.renderWidth, DisplayManager.renderHeight
end

function DisplayManager.getRenderResolution()
    return { w = DisplayManager.renderWidth, h = DisplayManager.renderHeight }
end

function DisplayManager.getRenderResolutionIndex()
    for index, res in ipairs(DisplayManager.renderResolutions) do
        if res.w == DisplayManager.renderWidth and res.h == DisplayManager.renderHeight then
            return index
        end
    end
    return 1
end

function DisplayManager.setRenderResolution(width, height)
    width = math.floor(width or DisplayManager.renderWidth)
    height = math.floor(height or DisplayManager.renderHeight)

    if width <= 0 or height <= 0 then
        return false
    end

    if width == DisplayManager.renderWidth and height == DisplayManager.renderHeight then
        return false
    end

    DisplayManager.renderWidth = width
    DisplayManager.renderHeight = height
    DisplayManager.ensureWorldCanvas()
    return true
end

function DisplayManager.setRenderResolutionByIndex(index)
    local res = DisplayManager.renderResolutions[index]
    if not res then return false end
    return DisplayManager.setRenderResolution(res.w, res.h)
end

function DisplayManager.getPostProcessCanvas(width, height)
    width = math.floor(width)
    height = math.floor(height)

    if DisplayManager._postCanvas
        and DisplayManager._postCanvasW == width
        and DisplayManager._postCanvasH == height then
        return DisplayManager._postCanvas
    end

    if DisplayManager._postCanvas then
        DisplayManager._postCanvas:release()
        DisplayManager._postCanvas = nil
    end

    DisplayManager._postCanvas = love.graphics.newCanvas(width, height)
    DisplayManager._postCanvas:setFilter('linear', 'linear')
    DisplayManager._postCanvasW = width
    DisplayManager._postCanvasH = height
    return DisplayManager._postCanvas
end

function DisplayManager.releasePostProcessCanvas()
    if DisplayManager._postCanvas then
        DisplayManager._postCanvas:release()
        DisplayManager._postCanvas = nil
        DisplayManager._postCanvasW = 0
        DisplayManager._postCanvasH = 0
    end
end

function DisplayManager.computeDrawParameters(canvasWidth, canvasHeight)
    local windowW, windowH = DisplayManager.getWindowSize()
    if windowW == 0 or windowH == 0 then
        windowW = DisplayManager.windowWidth
        windowH = DisplayManager.windowHeight
    end

    local scaleX = windowW / canvasWidth
    local scaleY = windowH / canvasHeight

    local drawScaleX, drawScaleY = scaleX, scaleY
    local offsetX, offsetY = 0, 0

    if DisplayManager.scalingMode == "fit" then
        local scale = math.min(scaleX, scaleY)
        drawScaleX = scale
        drawScaleY = scale
        local drawW = canvasWidth * scale
        local drawH = canvasHeight * scale
        offsetX = (windowW - drawW) / 2
        offsetY = (windowH - drawH) / 2
    end

    return drawScaleX, drawScaleY, offsetX, offsetY
end

local function applyMode(width, height, flags)
    if not hasWindowApi() then return end
    flags = flags or {}
    local currentW, currentH = love.window.getMode()
    local sizeChanged = (width ~= currentW) or (height ~= currentH)

    if love.window.updateMode then
        love.window.updateMode(width, height, flags)
    else
        love.window.setMode(width, height, flags)
    end

    if sizeChanged and love.window.setPosition and love.window.getDesktopDimensions then
        local desktopW, desktopH = love.window.getDesktopDimensions()
        local posX = math.floor((desktopW - width) / 2)
        local posY = math.floor((desktopH - height) / 2)
        love.window.setPosition(posX, posY)
    end

    DisplayManager.windowMode = "windowed"
    DisplayManager.updateWindowSize()
    detectDesktopResolution()
end

function DisplayManager.applyWindowMode(_, options)
    if not hasWindowApi() then return end
    options = options or {}
    local width = options.width or DisplayManager.renderWidth
    local height = options.height or DisplayManager.renderHeight
    local _, _, existingFlags = love.window.getMode()
    local flags = copyFlags(existingFlags)
    flags.fullscreen = false
    flags.borderless = false
    flags.resizable = false
    flags.centered = true
    flags.highdpi = flags.highdpi ~= false
    flags.vsync = DisplayManager.vsyncEnabled and 1 or 0
    flags.msaa = flags.msaa or 0
    applyMode(width, height, flags)
end

function DisplayManager.setWindowResolution(width, height)
    DisplayManager.applyWindowMode("windowed", { width = width, height = height })
end

function DisplayManager.refreshWindowFlags()
    if not hasWindowApi() then return end
    local width, height, flags = love.window.getMode()
    flags = copyFlags(flags)
    flags.vsync = DisplayManager.vsyncEnabled and 1 or 0
    applyMode(width, height, flags)
end

function DisplayManager.setVsyncEnabled(enabled)
    local newValue = not not enabled
    if DisplayManager.vsyncEnabled == newValue then
        return false
    end
    DisplayManager.vsyncEnabled = newValue
    DisplayManager.refreshWindowFlags()
    return true
end

function DisplayManager.isVsyncEnabled()
    return DisplayManager.vsyncEnabled
end

function DisplayManager.shutdown()
    DisplayManager.releaseWorldCanvas()
    DisplayManager.releasePostProcessCanvas()
end

return DisplayManager
