---@diagnostic disable: undefined-global
-- UI Theme - Clean Boxy theme for all UI windows and components
-- Provides sharp corners, clean borders, and professional styling

local Theme = {
    -- Color palette (Clean Boxy style)
    colors = {
        -- Backgrounds (neutral gray for professional look)
        bgDark = {0.25, 0.25, 0.25, 1},         -- Main window background (medium gray)
        bgMedium = {0.30, 0.30, 0.30, 1},       -- Secondary background (lighter gray)
        bgLight = {0.35, 0.35, 0.35, 1},        -- Slightly lighter background

        -- Borders (clean gray borders)
        borderDark = {0.15, 0.15, 0.15, 1},     -- Dark gray border
        borderMedium = {0.20, 0.20, 0.20, 1},   -- Medium gray border
        borderLight = {0.40, 0.40, 0.40, 1},    -- Light gray border
        borderNeon = {0.50, 0.50, 0.50, 1},     -- Subtle accent border

        -- Text (high contrast, clean)
        textPrimary = {0.95, 0.95, 0.95, 1},    -- Main text (near white)
        textSecondary = {0.80, 0.80, 0.80, 1},  -- Secondary text (light gray)
        textAccent = {0.60, 0.80, 1.0, 1},      -- Accent text (subtle blue)
        textMuted = {0.60, 0.60, 0.60, 1},      -- Muted text (medium gray)

        -- Interactive elements (subtle, professional)
        buttonHover = {0.40, 0.60, 0.80, 1},    -- Button hover (subtle blue)
        buttonYes = {0.20, 0.70, 0.30, 1},      -- Yes button (subtle green)
        buttonYesHover = {0.30, 0.85, 0.40, 1}, -- Yes hover (brighter green)
        buttonNo = {0.80, 0.30, 0.30, 1},       -- No button (subtle red)
        buttonNoHover = {0.95, 0.40, 0.40, 1},  -- No hover (brighter red)
        buttonClose = {0.15, 0.15, 0.15, 1},    -- Close button (minimal dark)
        buttonCloseHover = {0.80, 0.30, 0.30, 1}, -- Close hover (red)

        -- Highlights and effects (minimal)
        highlightBright = {0.60, 0.80, 1.0, 0.2}, -- Subtle highlight
        shadowDark = {0.10, 0.10, 0.10, 0.5},     -- Subtle shadow
        overlay = {0.05, 0.05, 0.05, 0.8},        -- Dark overlay
    },
    
    -- Font sizes and paths (clean, readable sizes)
    fonts = {
        small = 14,      -- Tooltips, small text
        normal = 16,     -- Default UI text
        title = 22,      -- Window titles, headers
        tiny = 12,       -- Very small text (e.g., stat lines)
        fontPath = "assets/fonts/Orbitron-Regular.ttf",  -- Clean sci-fi font
        fontPathBold = "assets/fonts/Orbitron-Bold.ttf",  -- Clean sci-fi bold font
    },
    
    -- Dimensions and spacing
    spacing = {
        padding = 6,           -- Standard padding inside elements
        margin = 8,            -- Standard margin between elements
        windowBorder = 1,      -- Border thickness
        slotSize = 72,         -- Cargo/turret/defensive slot size
        iconSize = 48,         -- Base icon size (icons are scaled 1x to fit 48px slots)
        iconGridPadding = 12,  -- Grid spacing for icon layout
    },
    
    -- Window styling (Clean Boxy style)
    window = {
        borderThickness = 1,        -- Thin, clean border
        topBarHeight = 44,          -- Standard title bar height
        bottomBarHeight = 56,       -- Clean bottom bar height
        tabHeight = 72,             -- Default tab button height (matches pause buttons)
        cornerRadius = 0,           -- Sharp corners (no rounding)
        framePadding = 8,           -- Default padding between frame and content elements
    },
}

local Scaling = require('src.scaling')

Theme._fontCache = {
    regular = {},
    bold = {},
    fallback = {}
}

local function cacheKey(path, size)
    return string.format("%s:%d", path or "__default__", size)
end

local function configureFont(font)
    if font and font.setFilter then
        font:setFilter("nearest", "nearest")
    end
    return font
end

-- Helper function to create a font with sci-fi styling
function Theme.getFont(size)
    size = size or Theme.fonts.normal
    size = Scaling and Scaling.scaleSize and Scaling.scaleSize(size) or size
    local fontPath = Theme.fonts.fontPath

    -- Check if font file exists, if not fall back to default
    if fontPath then
        local fontFile = love.filesystem.getInfo(fontPath)
        if fontFile then
            local key = cacheKey(fontPath, size)
            if not Theme._fontCache.regular[key] then
                Theme._fontCache.regular[key] = configureFont(love.graphics.newFont(fontPath, size))
            end
            return Theme._fontCache.regular[key]
        end
    end

    -- Fallback to default font
    local key = cacheKey("__fallback__", size)
    if not Theme._fontCache.fallback[key] then
        Theme._fontCache.fallback[key] = configureFont(love.graphics.newFont(size))
    end
    return Theme._fontCache.fallback[key]
end

-- Helper function to create a bold sci-fi font
function Theme.getFontBold(size)
    size = size or Theme.fonts.normal
    size = Scaling and Scaling.scaleSize and Scaling.scaleSize(size) or size
    local fontPath = Theme.fonts.fontPathBold

    -- Check if font file exists, if not fall back to default
    if fontPath then
        local fontFile = love.filesystem.getInfo(fontPath)
        if fontFile then
            local key = cacheKey(fontPath, size)
            if not Theme._fontCache.bold[key] then
                Theme._fontCache.bold[key] = configureFont(love.graphics.newFont(fontPath, size))
            end
            return Theme._fontCache.bold[key]
        end
    end

    -- Fallback to default font
    local key = cacheKey("__fallback_bold__", size)
    if not Theme._fontCache.bold[key] then
        Theme._fontCache.bold[key] = configureFont(love.graphics.newFont(size))
    end
    return Theme._fontCache.bold[key]
end

-- Helper function to draw clean, flat border (boxy style)
function Theme.draw3DBorder(x, y, w, h, depth, opts)
    if type(depth) == "table" and opts == nil then
        opts = depth
        depth = opts.depth
    end

    depth = depth or Theme.window.borderThickness or 1
    opts = opts or {}

    local alpha = opts.alpha or 1
    local radius = opts.cornerRadius or Theme.window.cornerRadius or 0

    local function setColor(color, multiplier)
        love.graphics.setColor(color[1], color[2], color[3], (color[4] or 1) * alpha * (multiplier or 1))
    end

    -- Background fill (sharp corners)
    setColor(Theme.colors.bgDark)
    love.graphics.rectangle("fill", x, y, w, h)

    -- Simple flat border (sharp corners)
    setColor(Theme.colors.borderDark)
    love.graphics.setLineWidth(depth)
    love.graphics.rectangle("line", x, y, w, h)

    love.graphics.setLineWidth(1)
end

-- Helper function to draw standard button (clean boxy style)
function Theme.drawButton(x, y, w, h, text, isHovered, buttonColor, buttonColorHover)
    -- Use standard button colors as defaults if none provided
    local baseColor = buttonColor or Theme.colors.bgMedium
    local hoverColor = buttonColorHover or Theme.colors.buttonHover

    -- Background (sharp corners for boxy look)
    if isHovered then
        love.graphics.setColor(hoverColor[1], hoverColor[2], hoverColor[3], hoverColor[4])
    else
        love.graphics.setColor(baseColor[1], baseColor[2], baseColor[3], baseColor[4])
    end
    love.graphics.rectangle("fill", x, y, w, h)

    -- Border (sharp corners for boxy look)
    love.graphics.setColor(Theme.colors.borderDark)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", x, y, w, h)
    love.graphics.setLineWidth(1)

    -- Text (centered)
    love.graphics.setColor(Theme.colors.textPrimary)
    local font = Theme.getFont(Theme.fonts.normal)
    love.graphics.setFont(font)
    local textHeight = font:getHeight()
    local textYOffset = (h - textHeight) / 2
    love.graphics.printf(text, x, y + textYOffset, w, "center")
end

-- Helper function to draw menu/pause style buttons that tabs can also use
function Theme.drawPanelButton(x, y, w, h, text, state)
    state = state or {}
    local alpha = state.alpha or 1
    local isActive = not not state.isActive
    local isHovered = not not state.isHovered

    local baseColor = state.baseColor or Theme.colors.bgMedium
    local hoverColor = state.hoverColor or Theme.colors.buttonHover
    local activeColor = state.activeColor or hoverColor
    local borderColor = state.borderColor or Theme.colors.borderDark
    local textColor = state.textColor or Theme.colors.textPrimary
    local radius = state.cornerRadius or Theme.window.cornerRadius or 0
    local borderWidth = state.borderWidth or 2
    local idleAlpha = state.idleAlpha or 0.9
    local hoverAlpha = state.hoverAlpha or 1.0
    local activeAlpha = state.activeAlpha or 1.0

    local function setColor(color, multiplier)
        multiplier = multiplier or 1
        love.graphics.setColor(color[1], color[2], color[3], (color[4] or 1) * alpha * multiplier)
    end

    if isActive then
        setColor(activeColor, activeAlpha)
    elseif isHovered then
        setColor(hoverColor, hoverAlpha)
    else
        setColor(baseColor, idleAlpha)
    end
    love.graphics.rectangle("fill", x, y, w, h, radius, radius)

    setColor(borderColor)
    love.graphics.setLineWidth(borderWidth)
    love.graphics.rectangle("line", x, y, w, h, radius, radius)
    love.graphics.setLineWidth(1)

    local font = state.font or Theme.getFont(Theme.fonts.normal)
    love.graphics.setFont(font)
    setColor(textColor)
    local textHeight = font:getHeight()
    local textYOffset = state.textYOffset or (h - textHeight) / 2
    love.graphics.printf(text, x, y + textYOffset, w, state.textAlign or "center")
end

-- Helper function to draw tab-style button (clean boxy style)
function Theme.drawTab(x, y, w, h, text, isActive, isHovered, alpha)
    Theme.drawPanelButton(x, y, w, h, text, {
        isActive = isActive,
        isHovered = isHovered,
        alpha = alpha,
        font = Theme.getFontBold(Theme.fonts.normal),
        idleAlpha = 0.85,
        hoverAlpha = 0.95,
        activeAlpha = 1.0,
    })
end

return Theme
