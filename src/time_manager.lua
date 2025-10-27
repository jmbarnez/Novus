---@diagnostic disable: undefined-global
-- Time Manager
-- Handles fixed timestep for game logic updates
-- Decouples rendering from game logic for deterministic updates

local TimeManager = {}

-- Configuration
TimeManager.config = {
    -- Fixed timestep for game logic (60 Hz)
    fixedDt = 1 / 60,
    
    -- Maximum frame time to prevent spiral of death
    -- If a frame takes longer than this, we'll skip updates
    maxFrameTime = 0.25,
    
    -- FPS cap (nil = unlimited, number = capped FPS)
    -- Currently unlimited to see max performance
    targetFps = nil,
    
    -- Accumulator for fixed timestep
    accumulator = 0,
    
    -- Frame timing for FPS display
    frameCount = 0,
    frameTimer = 0,
    currentFps = 0,
    
    -- Interpolation alpha (for smooth rendering between updates)
    alpha = 0,

    -- Timestamp for current frame (used for manual frame limiting)
    frameStartTime = nil,
}

-- Initialize time manager
function TimeManager.init()
    TimeManager.config.accumulator = 0
    TimeManager.config.frameCount = 0
    TimeManager.config.frameTimer = 0
    TimeManager.config.currentFps = 0
    TimeManager.config.alpha = 0
    TimeManager.config.frameStartTime = nil
end

-- Update with fixed timestep
-- Returns: number of fixed updates to perform, interpolation alpha
function TimeManager.step(dt)
    -- Clamp dt to prevent spiral of death
    dt = math.min(dt, TimeManager.config.maxFrameTime)
    
    -- Add to accumulator
    TimeManager.config.accumulator = TimeManager.config.accumulator + dt
    
    -- Count updates performed this frame
    local updateCount = 0
    
    -- Perform fixed timestep updates
    while TimeManager.config.accumulator >= TimeManager.config.fixedDt do
        updateCount = updateCount + 1
        TimeManager.config.accumulator = TimeManager.config.accumulator - TimeManager.config.fixedDt
    end
    
    -- Calculate interpolation alpha for smooth rendering
    TimeManager.config.alpha = TimeManager.config.accumulator / TimeManager.config.fixedDt
    
    -- Update FPS counter
    TimeManager.config.frameCount = TimeManager.config.frameCount + 1
    TimeManager.config.frameTimer = TimeManager.config.frameTimer + dt
    
    if TimeManager.config.frameTimer >= 1.0 then
        TimeManager.config.currentFps = TimeManager.config.frameCount
        TimeManager.config.frameCount = 0
        TimeManager.config.frameTimer = TimeManager.config.frameTimer - 1.0
    end
    
    return updateCount, TimeManager.config.alpha
end

-- Get current FPS
function TimeManager.getFps()
    return TimeManager.config.currentFps
end

-- Get fixed delta time
function TimeManager.getFixedDt()
    return TimeManager.config.fixedDt
end

-- Get interpolation alpha
function TimeManager.getAlpha()
    return TimeManager.config.alpha
end

-- Set target FPS (nil for unlimited)
function TimeManager.setTargetFps(fps)
    TimeManager.config.targetFps = fps
end

-- Get target FPS
function TimeManager.getTargetFps()
    return TimeManager.config.targetFps
end

-- Set fixed timestep rate
function TimeManager.setUpdateRate(hz)
    TimeManager.config.fixedDt = 1 / hz
end

local function isVsyncActive()
    local ok, DisplayManager = pcall(require, 'src.display_manager')
    if ok and DisplayManager and DisplayManager.isVsyncEnabled then
        return DisplayManager.isVsyncEnabled()
    end
    return false
end

function TimeManager.markFrameStart()
    if love and love.timer and love.timer.getTime then
        TimeManager.config.frameStartTime = love.timer.getTime()
    else
        TimeManager.config.frameStartTime = nil
    end
end

function TimeManager.sleepIfNeeded()
    local targetFps = TimeManager.config.targetFps
    if not targetFps or targetFps <= 0 then
        return
    end

    if isVsyncActive() then
        return
    end

    if not (love and love.timer and love.timer.getTime and love.timer.sleep) then
        return
    end

    local startTime = TimeManager.config.frameStartTime
    if not startTime then
        return
    end

    local frameDuration = 1 / targetFps
    local elapsed = love.timer.getTime() - startTime
    local remaining = frameDuration - elapsed
    if remaining > 0 then
        love.timer.sleep(remaining)
    end
end

function TimeManager.serialize()
    local data = {}
    for k, v in pairs(TimeManager.config) do
        if k ~= "frameStartTime" then
            data[k] = v
        end
    end
    return data
end

function TimeManager.deserialize(data)
    if type(data) ~= "table" then
        TimeManager.init()
        return
    end

    for k, v in pairs(TimeManager.config) do
        if k ~= "frameStartTime" and data[k] ~= nil then
            TimeManager.config[k] = data[k]
        else
            TimeManager.config[k] = v
        end
    end
    TimeManager.config.frameStartTime = nil
end

return TimeManager

