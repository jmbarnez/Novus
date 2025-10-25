---@diagnostic disable: undefined-global
-- DisplayManager - centralized window and rendering resolution control
-- Handles switching between windowed, borderless, and fullscreen modes
-- while keeping a consistent off-screen render resolution for scaling.

local Scaling = require('src.scaling')

local DisplayManager = {}

-- Default state before initialization (matches conf.lua defaults)
DisplayManager._windowWidth = 1920
DisplayManager._windowHeight = 1080
DisplayManager._renderWidth = 1920
DisplayManager._renderHeight = 1080
DisplayManager._mode = "windowed"
DisplayManager._windowedResolution = {w = 1920, h = 1080}
DisplayManager._vsync = true
DisplayManager._msaa = 0
DisplayManager._baseFlags = {
    fullscreen = false,
    borderless = false,
    resizable = false,
    vsync = 1,
    msaa = 0
}

DisplayManager._resolutions = {
    {w = 1280, h = 720, label = "1280x720"},
    {w = 1366, h = 768, label = "1366x768"},
    {w = 1600, h = 900, label = "1600x900"},
    {w = 1920, h = 1080, label = "1920x1080"},
    {w = 2560, h = 1440, label = "2560x1440"},
}

local function copyFlags(flags)
    local result = {}
    if not flags then return result end
    for k, v in pairs(flags) do
        result[k] = v
    end
    return result
end

local function determineMode(flags)
    if not flags then return "windowed" end
    if flags.fullscreen then
        return "fullscreen"
    elseif flags.borderless then
        return "borderless"
    end
    return "windowed"
end

local function mergeFlags(overrides)
    local flags = copyFlags(DisplayManager._baseFlags)
    for k, v in pairs(overrides or {}) do
        flags[k] = v
    end
    flags.vsync = DisplayManager._vsync and 1 or 0
    flags.msaa = DisplayManager._msaa or flags.msaa or 0
    return flags
end

local function updateBaseFlags(flags)
    DisplayManager._baseFlags = copyFlags(flags)
    DisplayManager._vsync = (flags and flags.vsync or 1) ~= 0
    DisplayManager._msaa = (flags and flags.msaa) or 0
end

function DisplayManager.init(options)
    options = options or {}
    local w, h, flags = love.window.getMode()
    if w and h then
        DisplayManager._windowWidth = w
        DisplayManager._windowHeight = h
        DisplayManager._renderWidth = options.renderWidth or w
        DisplayManager._renderHeight = options.renderHeight or h
        DisplayManager._windowedResolution = {w = w, h = h}
    end

    updateBaseFlags(flags or DisplayManager._baseFlags)
    DisplayManager._mode = determineMode(flags)

    -- Ensure scaling reflects the actual window size on startup
    Scaling.update()
end

function DisplayManager.getMode()
    return DisplayManager._mode
end

function DisplayManager.getResolutions()
    return DisplayManager._resolutions
end

function DisplayManager.getWindowDimensions()
    return DisplayManager._windowWidth, DisplayManager._windowHeight
end

function DisplayManager.getRenderDimensions()
    return DisplayManager._renderWidth, DisplayManager._renderHeight
end

function DisplayManager.getWindowedResolution()
    return DisplayManager._windowedResolution.w, DisplayManager._windowedResolution.h
end

function DisplayManager.getDesktopDimensions(displayIndex)
    local ok, dw, dh = pcall(love.window.getDesktopDimensions, displayIndex or 1)
    if ok and dw and dh then
        return dw, dh
    end
    -- Fallback to current window size if desktop dimensions are unavailable
    return love.graphics.getDimensions()
end

function DisplayManager.refreshWindowSize()
    DisplayManager._windowWidth, DisplayManager._windowHeight = love.graphics.getDimensions()
end

function DisplayManager.onResize(w, h)
    DisplayManager._windowWidth = w
    DisplayManager._windowHeight = h
    Scaling.update()
end

function DisplayManager.setRenderResolution(width, height)
    if not width or not height then return false end
    if DisplayManager._renderWidth == width and DisplayManager._renderHeight == height then
        return false
    end
    DisplayManager._renderWidth = width
    DisplayManager._renderHeight = height
    return true
end

local function applyWindowMode(width, height, overrideFlags, mode)
    local flags = mergeFlags(overrideFlags)
    local success = love.window.setMode(width, height, flags)
    if success then
        updateBaseFlags(flags)
        DisplayManager.refreshWindowSize()
        DisplayManager._mode = mode or determineMode(overrideFlags)
    end
    return success
end

function DisplayManager.switchMode(mode, opts)
    opts = opts or {}
    local normalized = mode and mode:lower() or DisplayManager._mode
    if normalized ~= "windowed" and normalized ~= "borderless" and normalized ~= "fullscreen" then
        normalized = DisplayManager._mode
    end

    local resolution = opts.resolution
    if resolution and resolution.w and resolution.h then
        DisplayManager.setRenderResolution(resolution.w, resolution.h)
    end

    if normalized == "windowed" then
        local target = resolution or DisplayManager._windowedResolution or {
            w = DisplayManager._renderWidth,
            h = DisplayManager._renderHeight
        }
        DisplayManager._windowedResolution = {w = target.w, h = target.h}
        DisplayManager.setRenderResolution(target.w, target.h)
        return applyWindowMode(target.w, target.h, {
            fullscreen = false,
            borderless = false,
            resizable = false
        }, "windowed")
    elseif normalized == "borderless" then
        local dw, dh = DisplayManager.getDesktopDimensions(opts.display)
        return applyWindowMode(dw, dh, {
            fullscreen = false,
            borderless = true,
            resizable = false
        }, "borderless")
    elseif normalized == "fullscreen" then
        return applyWindowMode(0, 0, {
            fullscreen = true,
            fullscreentype = "desktop",
            resizable = false,
            borderless = false
        }, "fullscreen")
    end

    return false
end

return DisplayManager
