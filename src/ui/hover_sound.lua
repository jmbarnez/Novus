-- HoverSound helper: plays UI hover and click SFX when interacting with buttons

local SoundSystem = require('src.systems.sound')
local Scaling = require('src.scaling')

local HoverSound = {
    _states = {},
    defaultVolume = nil, -- when nil, rely on SoundSystem's master/sfx volumes
    _staleTimeout = 0.35, -- seconds before cached hover data is discarded
}

local soundDefs = {
    hover = {
        name = "button_hover",
        assetPath = "assets/sounds/button_hover.wav",
        attempted = false,
    },
    click = {
        name = "button_click",
        assetPath = "assets/sounds/button_click.wav",
        attempted = false,
    }
}

local function ensureLoaded(kind)
    local def = soundDefs[kind]
    if not def or def.attempted then
        return
    end
    def.attempted = true

    if not SoundSystem or not SoundSystem.load then
        return
    end

    if SoundSystem.sounds and SoundSystem.sounds[def.name] then
        return
    end

    if love and love.filesystem and def.assetPath and love.filesystem.getInfo(def.assetPath) then
        SoundSystem.load(def.name, def.assetPath)
    end
end

local function playSound(kind, opts)
    local def = soundDefs[kind]
    if not def or not SoundSystem or not SoundSystem.play then
        return
    end

    ensureLoaded(kind)

    if not SoundSystem.sounds or not SoundSystem.sounds[def.name] then
        return
    end

    SoundSystem.play(def.name, opts)
end

local function applyDefaultVolume(opts)
    if HoverSound.defaultVolume and opts.volume == nil then
        opts.volume = HoverSound.defaultVolume
    end
end

local function cloneOpts(src)
    if not src then return nil end
    local copy = {}
    for k, v in pairs(src) do
        copy[k] = v
    end
    return copy
end

local function normalizeBounds(bounds)
    if not bounds then
        return nil
    end

    local x = bounds.x or bounds[1] or 0
    local y = bounds.y or bounds[2] or 0
    local w = bounds.w or bounds.width or bounds[3] or 0
    local h = bounds.h or bounds.height or bounds[4] or 0

    return {
        x = x,
        y = y,
        w = w,
        h = h,
    }
end

local function playHoverSound(opts)
    local settings = cloneOpts(opts)
    settings = settings or {}
    applyDefaultVolume(settings)
    playSound("hover", settings)
end

local function playClickSound(opts)
    local settings = cloneOpts(opts)
    settings = settings or {}
    applyDefaultVolume(settings)
    playSound("click", settings)
end

local function currentTime()
    if love and love.timer and love.timer.getTime then
        return love.timer.getTime()
    end
    return os.clock()
end

local function pruneStale(now)
    local timeout = HoverSound._staleTimeout or 0
    local states = HoverSound._states
    for id, state in pairs(states) do
        if not state.hovered then
            states[id] = nil
        elseif timeout > 0 and state.lastUpdate and (now - state.lastUpdate) > timeout then
            states[id] = nil
        end
    end
end

local function pointInRect(px, py, rect)
    if not rect then
        return true
    end
    local function asNumber(value, fallback)
        if type(value) == "number" then
            return value
        elseif type(value) == "string" then
            local parsed = tonumber(value)
            if parsed ~= nil then
                return parsed
            end
        end
        return fallback
    end

    local x = asNumber(rect.x, asNumber(rect[1], 0))
    local y = asNumber(rect.y, asNumber(rect[2], 0))
    local w = asNumber(rect.w, asNumber(rect.width, asNumber(rect[3], 0)))
    local h = asNumber(rect.h, asNumber(rect.height, asNumber(rect[4], 0)))
    local pxn = asNumber(px, nil)
    local pyn = asNumber(py, nil)

    if not pxn or not pyn then
        return false
    end

    return pxn >= x and pxn <= x + w and pyn >= y and pyn <= y + h
end

--- Update hover sound state for a given control
-- @param id string Unique identifier for the control (stable across frames)
-- @param isHovered boolean Whether the control is currently hovered
-- @param opts table|nil Optional settings:
--        bounds = {x, y, w, h}
--        space = "screen" | "ui"   (defaults to "screen")
--        hoverSoundOpts = table passed to SoundSystem.play for hover
--        clickSoundOpts = table passed to SoundSystem.play for click
function HoverSound.update(id, isHovered, opts)
    if not id then
        return
    end

    opts = opts or {}
    local states = HoverSound._states
    local record = states[id]
    local now = currentTime()

    local currentlyHovered = not not isHovered
    if not record then
        record = {}
        states[id] = record
    end

    if currentlyHovered and not record.hovered then
        playHoverSound(opts.hoverSoundOpts)
    end

    record.hovered = currentlyHovered
    local newBounds = normalizeBounds(opts.bounds)
    if newBounds then
        record.bounds = newBounds
    end
    record.space = opts.space or record.space or "screen"
    if opts.clickSoundOpts then
        record.clickSoundOpts = cloneOpts(opts.clickSoundOpts)
    end
    record.lastUpdate = now

    if not record.hovered then
        states[id] = nil
    end
end

--- Clear the cached hover state for a control (useful when tearing down UI)
-- @param id string Identifier used in `update`
function HoverSound.clear(id)
    HoverSound._states[id] = nil
end

--- Reset all cached hover states (e.g., when switching screens)
function HoverSound.reset()
    for key in pairs(HoverSound._states) do
        HoverSound._states[key] = nil
    end
end

--- Play the click sound directly (e.g., keyboard activation)
function HoverSound.playClick(opts)
    playClickSound(opts)
end

--- Handle a mouse click event and play the click sound if any hovered control is clicked.
-- @param button number Mouse button identifier
-- @param screenX number Screen-space X coordinate of the click
-- @param screenY number Screen-space Y coordinate of the click
-- @param opts table|nil Optional overrides for the click sound
-- @return boolean true if a click sound was played
function HoverSound.onClick(button, screenX, screenY, opts)
    if button ~= 1 then
        return false
    end

    local states = HoverSound._states
    if not states or next(states) == nil then
        return false
    end

    local now = currentTime()
    pruneStale(now)
    if next(states) == nil then
        return false
    end

    local uiX, uiY
    for _, state in pairs(states) do
        if state.hovered then
            local inside = true
            if state.bounds then
                if state.space == "ui" then
                    uiX, uiY = uiX or Scaling.toUI(screenX or 0, screenY or 0)
                    inside = pointInRect(uiX, uiY, state.bounds)
                else
                    inside = pointInRect(screenX or 0, screenY or 0, state.bounds)
                end
            end

            if inside then
                playClickSound(opts or state.clickSoundOpts)
                return true
            end
        end
    end

    return false
end

-- Reapply stored master/sfx volume levels once to avoid stale audio state
if SoundSystem and SoundSystem.getVolume and SoundSystem.setVolume then
    for _, channel in ipairs({"master", "sfx"}) do
        local current = SoundSystem.getVolume(channel)
        if current then
            SoundSystem.setVolume(channel, current)
        end
    end
end

return HoverSound
