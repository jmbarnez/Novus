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
        small = 10,      -- Tooltips, small text
        normal = 11,     -- Default UI text
        title = 13,      -- Window titles, headers
        tiny = 9,        -- Very small text (e.g., stat lines)
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
        topBarHeight = 32,          -- Standard title bar height
        bottomBarHeight = 40,       -- Clean bottom bar height
        cornerRadius = 0,           -- Sharp corners (no rounding)
        framePadding = 8,           -- Default padding between frame and content elements
    },
}

local Scaling = require('src.scaling')

-- Helper function to create a font with sci-fi styling
function Theme.getFont(size)
    size = size or Theme.fonts.normal
    size = Scaling and Scaling.scaleSize and Scaling.scaleSize(size) or size
    local fontPath = Theme.fonts.fontPath
    
    -- Check if font file exists, if not fall back to default
    if fontPath then
        local fontFile = love.filesystem.getInfo(fontPath)
        if fontFile then
            return love.graphics.newFont(fontPath, size)
        end
    end
    
    -- Fallback to default font
    return love.graphics.newFont(size)
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
            return love.graphics.newFont(fontPath, size)
        end
    end
    
    -- Fallback to default font
    return love.graphics.newFont(size)
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
    love.graphics.setFont(Theme.getFont(Theme.fonts.normal))
    love.graphics.printf(text, x, y + h / 2 - 12, w, "center")
end

-- Helper function to draw tab-style button (clean boxy style)
function Theme.drawTab(x, y, w, h, text, isActive, isHovered, alpha)
    alpha = alpha or 1

    -- Tab background (sharp corners)
    local baseColor = isActive and Theme.colors.bgMedium or Theme.colors.bgDark
    local hoverColor = Theme.colors.buttonHover

    if isActive then
        love.graphics.setColor(baseColor[1], baseColor[2], baseColor[3], alpha)
    elseif isHovered then
        love.graphics.setColor(hoverColor[1], hoverColor[2], hoverColor[3], alpha)
    else
        love.graphics.setColor(baseColor[1], baseColor[2], baseColor[3], alpha * 0.6)
    end
    love.graphics.rectangle("fill", x, y, w, h)

    -- Tab border (sharp corners)
    love.graphics.setColor(Theme.colors.borderDark)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", x, y, w, h)
    love.graphics.setLineWidth(1)

    -- Tab text (centered)
    love.graphics.setColor(Theme.colors.textPrimary[1], Theme.colors.textPrimary[2], Theme.colors.textPrimary[3], alpha)
    love.graphics.setFont(Theme.getFont(Theme.fonts.normal))
    love.graphics.printf(text, x, y + h / 2 - 12, w, "center")
end

return Theme
