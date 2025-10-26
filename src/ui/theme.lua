---@diagnostic disable: undefined-global
-- UI Theme - Universal styling for all UI windows and components
-- Provides consistent colors, fonts, and styling across the game

local Theme = {
    -- Color palette (Plasma/Energy Style)
    colors = {
        -- Backgrounds
        bgDark = {0.05, 0.05, 0.05, 1},      -- Main window background (darker)
        bgMedium = {0.08, 0.08, 0.08, 1},    -- Secondary background (darker)
        bgLight = {0.12, 0.12, 0.12, 1},     -- Slightly lighter background
        
        -- Borders and accents (thick black with plasma glow)
        borderDark = {0, 0, 0, 1},              -- Pure black border
        borderMedium = {0, 0, 0, 1},            -- Pure black border
        borderLight = {0, 0, 0, 1},              -- Pure black border
        borderNeon = {0.2, 0.95, 1, 1},         -- Neon blue/cyan border (electric plasma)
        
        -- Text (high contrast with energy glow)
        textPrimary = {1, 1, 1, 1},              -- Main text (white)
        textSecondary = {0.95, 0.95, 0.95, 1},   -- Secondary text (brighter)
        textAccent = {0.4, 0.9, 1, 1},           -- Accent text (bright cyan plasma)
        textMuted = {0.7, 0.7, 0.7, 1},          -- Muted text (brighter)
        
        -- Interactive elements (vibrant plasma energy)
        buttonHover = {0.3, 0.5, 0.7, 1},        -- Button hover state (electric blue)
        buttonYes = {0.1, 0.8, 0.5, 1},          -- Confirmation yes button (plasma green)
        buttonYesHover = {0.2, 1, 0.6, 1},       -- Yes button hover (brighter plasma)
        buttonNo = {1, 0.2, 0.5, 1},             -- Confirmation no button (plasma pink)
        buttonNoHover = {1, 0.4, 0.6, 1},        -- No button hover (brighter plasma)
        buttonClose = {1, 0.2, 0.5, 1},          -- Close button (plasma pink)
        buttonCloseHover = {1, 0.4, 0.6, 1},    -- Close button hover (brighter plasma)
        
        -- Highlights and effects
        highlightBright = {0.4, 0.7, 1, 0.3},    -- Bright highlight (plasma blue glow)
        shadowDark = {0, 0, 0, 0.3},             -- Dark shadow (pure black)
        overlay = {0, 0, 0, 0.7},                 -- Modal overlay (darker)
    },
    
    -- Font sizes and paths
    fonts = {
        small = 11,      -- Tooltips, small text
        normal = 12,     -- Default UI text
        title = 14,      -- Window titles, headers
        tiny = 9,        -- Very small text (e.g., stat lines)
        fontPath = "assets/fonts/Orbitron-Regular.ttf",  -- Sci-fi font
        fontPathBold = "assets/fonts/Orbitron-Bold.ttf",  -- Sci-fi bold font
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
    
    -- Window styling (Plasma/Energy)
    window = {
        borderThickness = 3,        -- Thick plasma-style border
        topBarHeight = 28,          -- Top bar height
        bottomBarHeight = 50,       -- Bottom bar height
        cornerRadius = 14,          -- Rounded corners to match pause menu styling
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

-- Helper function to create plasma-style thick border with opaque background
function Theme.draw3DBorder(x, y, w, h, depth, opts)
    if type(depth) == "table" and opts == nil then
        opts = depth
        depth = opts.depth
    end

    depth = depth or Theme.window.borderThickness or 3
    opts = opts or {}

    local alpha = opts.alpha or 1
    local radius = opts.cornerRadius or Theme.window.cornerRadius or 12
    local rimInset = opts.rimInset or 2
    local highlightInset = opts.highlightInset or math.max(rimInset + 3, 6)
    local neonAlpha = (opts.neonAlpha ~= nil) and opts.neonAlpha or 0.45

    rimInset = math.min(rimInset, math.max((w - 2) * 0.5, 0))
    rimInset = math.min(rimInset, math.max((h - 2) * 0.5, 0))
    highlightInset = math.min(highlightInset, math.max((w - 2) * 0.5, 0))
    highlightInset = math.min(highlightInset, math.max((h - 2) * 0.5, 0))

    local function setColor(color, multiplier)
        love.graphics.setColor(color[1], color[2], color[3], (color[4] or 1) * alpha * (multiplier or 1))
    end

    -- Background fill with rounded corners
    setColor(Theme.colors.bgDark)
    love.graphics.rectangle("fill", x, y, w, h, radius, radius)

    -- Exterior frame
    setColor(Theme.colors.borderDark)
    love.graphics.setLineWidth(depth)
    love.graphics.rectangle("line", x, y, w, h, radius, radius)

    -- Neon inner rim
    if w > rimInset * 2 and h > rimInset * 2 then
        setColor(Theme.colors.borderNeon, neonAlpha)
        love.graphics.setLineWidth(2)
        love.graphics.rectangle(
            "line",
            x + rimInset,
            y + rimInset,
            w - rimInset * 2,
            h - rimInset * 2,
            math.max(0, radius - rimInset),
            math.max(0, radius - rimInset)
        )
    end

    -- Subtle inner highlight to sell the plasma sheen
    if w > highlightInset * 2 and h > highlightInset * 2 then
        setColor(Theme.colors.highlightBright)
        love.graphics.setLineWidth(1)
        love.graphics.rectangle(
            "line",
            x + highlightInset,
            y + highlightInset,
            w - highlightInset * 2,
            h - highlightInset * 2,
            math.max(0, radius - highlightInset),
            math.max(0, radius - highlightInset)
        )
    end

    love.graphics.setLineWidth(1)
end

-- Helper function to draw a button with plasma-style consistent styling
function Theme.drawButton(x, y, w, h, text, isHovered, buttonColor, buttonColorHover)
    local color = isHovered and buttonColorHover or buttonColor
    
    -- Background
    love.graphics.setColor(color)
    love.graphics.rectangle("fill", x, y, w, h)
    
    -- Thick black border
    love.graphics.setColor(Theme.colors.borderDark)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", x, y, w, h)
    love.graphics.setLineWidth(1)
    
    -- Text
    love.graphics.setColor(Theme.colors.textPrimary)
    love.graphics.printf(text, x, y + 6, w, "center")
end

return Theme
