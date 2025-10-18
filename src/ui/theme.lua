-- UI Theme - Universal styling for all UI windows and components
-- Provides consistent colors, fonts, and styling across the game

local Theme = {
    -- Color palette
    colors = {
        -- Backgrounds
        bgDark = {0.08, 0.08, 0.08, 1},      -- Main window background
        bgMedium = {0.12, 0.12, 0.12, 1},    -- Secondary background (menus, etc)
        bgLight = {0.16, 0.16, 0.16, 1},     -- Slightly lighter background
        
        -- Borders and accents
        borderDark = {0.05, 0.05, 0.05, 1},      -- Dark shadow border
        borderMedium = {0.25, 0.25, 0.25, 1},    -- Medium border
        borderLight = {0.4, 0.4, 0.4, 1},        -- Light/highlight border
        borderNeon = {0.2, 0.95, 1, 0.85},       -- Neon blue/cyan border
        
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
        padding = 6,           -- Standard padding inside elements
        margin = 8,            -- Standard margin between elements
        windowBorder = 1,      -- Border thickness
        iconSize = 48,         -- Standard icon size (2x larger)
        iconGridPadding = 12,  -- Grid spacing for icon layout
    },
    
    -- Window styling
    window = {
        borderThickness = 1,        -- Minimal border thickness
        topBarHeight = 20,          -- Top bar height
        bottomBarHeight = 20,       -- Bottom bar height
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

-- Helper function to create a sleek minimal border with opaque background
function Theme.draw3DBorder(x, y, w, h, depth)
    depth = depth or 1

    -- Single clean border
    love.graphics.setColor(Theme.colors.borderLight)
    love.graphics.rectangle("fill", x - depth, y - depth, w + depth * 2, h + depth * 2)

    -- Opaque background
    love.graphics.setColor(Theme.colors.bgDark)
    love.graphics.rectangle("fill", x, y, w, h)
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
