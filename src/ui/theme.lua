-- UI Theme - Universal styling for all UI windows and components
-- Provides consistent colors, fonts, and styling across the game

local Theme = {
    -- Color palette
    colors = {
        -- Backgrounds
        bgDark = {0.1, 0.11, 0.13, 1},      -- Main window background
        bgMedium = {0.15, 0.16, 0.19, 1},   -- Secondary background (menus, etc)
        bgLight = {0.18, 0.19, 0.22, 1},    -- Slightly lighter background
        
        -- Borders and accents
        borderDark = {0.05, 0.06, 0.08, 1},      -- Dark shadow border
        borderMedium = {0.22, 0.24, 0.28, 1},    -- Medium border
        borderLight = {0.35, 0.38, 0.45, 1},     -- Light/highlight border
        
        -- Text
        textPrimary = {1, 1, 1, 1},              -- Main text (white)
        textSecondary = {0.9, 0.9, 0.9, 1},      -- Secondary text
        textAccent = {0.8, 0.9, 1, 1},           -- Accent text (light blue)
        textMuted = {0.6, 0.6, 0.6, 1},          -- Muted text
        
        -- Interactive elements
        buttonHover = {0.3, 0.4, 0.5, 0.8},      -- Button hover state
        buttonYes = {0.2, 0.5, 0.2, 1},          -- Confirmation yes button
        buttonYesHover = {0.4, 0.7, 0.4, 1},     -- Yes button hover
        buttonNo = {0.5, 0.2, 0.2, 1},           -- Confirmation no button
        buttonNoHover = {0.7, 0.3, 0.3, 1},      -- No button hover
        buttonClose = {0.85, 0.18, 0.18, 1},     -- Close button
        buttonCloseHover = {1, 0.3, 0.3, 1},     -- Close button hover
        
        -- Highlights and effects
        highlightBright = {0.35, 0.38, 0.45, 0.18},  -- Bright highlight (top of windows)
        shadowDark = {0.05, 0.06, 0.08, 0.18},       -- Dark shadow (bottom of windows)
        overlay = {0, 0, 0, 0.6},                     -- Modal overlay
    },
    
    -- Font sizes and paths
    fonts = {
        small = 11,      -- Tooltips, small text
        normal = 12,     -- Default UI text
        title = 14,      -- Window titles, headers
        fontPath = "assets/fonts/Orbitron-Regular.ttf",  -- Sci-fi font
        fontPathBold = "assets/fonts/Orbitron-Bold.ttf",  -- Sci-fi bold font
    },
    
    -- Dimensions and spacing
    spacing = {
        padding = 8,           -- Standard padding inside elements
        margin = 12,           -- Standard margin between elements
        windowBorder = 2,      -- Border thickness
        iconSize = 28,         -- Standard icon size
        iconGridPadding = 18,  -- Grid spacing for icon layout
    },
    
    -- Window styling
    window = {
        borderThickness = 2,        -- 3D effect: outer, medium, base
        topBarHeight = 24,          -- Top bar height
        bottomBarHeight = 24,       -- Bottom bar height
    },
}

-- Helper function to create a font with sci-fi styling
function Theme.getFont(size)
    size = size or Theme.fonts.normal
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

-- Helper function to create a 3D border effect
function Theme.draw3DBorder(x, y, w, h, depth)
    depth = depth or 4
    
    -- Outer shadow
    love.graphics.setColor(Theme.colors.bgDark)
    love.graphics.rectangle("fill", x - depth, y - depth, w + depth * 2, h + depth * 2)
    
    -- Medium border
    love.graphics.setColor(Theme.colors.borderMedium)
    love.graphics.rectangle("fill", x - depth + 2, y - depth + 2, w + depth * 2 - 4, h + depth * 2 - 4)
    
    -- Base background
    love.graphics.setColor(Theme.colors.bgDark)
    love.graphics.rectangle("fill", x, y, w, h)
    
    -- Top highlight
    love.graphics.setColor(Theme.colors.highlightBright)
    love.graphics.rectangle("fill", x, y, w, 8)
    
    -- Bottom shadow
    love.graphics.setColor(Theme.colors.shadowDark)
    love.graphics.rectangle("fill", x, y + h - 8, w, 8)
end

-- Helper function to draw a button with consistent styling
function Theme.drawButton(x, y, w, h, text, isHovered, buttonColor, buttonColorHover)
    local color = isHovered and buttonColorHover or buttonColor
    
    love.graphics.setColor(color)
    love.graphics.rectangle("fill", x, y, w, h)
    
    love.graphics.setColor(Theme.colors.textPrimary)
    love.graphics.printf(text, x, y + 6, w, "center")
end

return Theme
