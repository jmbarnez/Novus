---@diagnostic disable: undefined-global

-- Ensure compatibility with Lua 5.1 / LuaJIT where `table.unpack` may not exist
if not table.unpack and unpack then table.unpack = unpack end
-- UI Theme - Clean Boxy theme for all UI windows and components
-- Provides sharp corners, clean borders, and professional styling

local Theme = {
    -- Base palette (raw colors for semantic mapping)
    palette = {
        primary = {0.60, 0.80, 1.0, 1},      -- Main accent color (blue)
        secondary = {0.80, 0.80, 0.80, 1},   -- Secondary color (gray)
        success = {0.20, 0.70, 0.30, 1},     -- Success/positive (green)
        danger = {0.80, 0.30, 0.30, 1},      -- Danger/error (red)
        warning = {0.90, 0.70, 0.20, 1},     -- Warning (orange)
        neutrals = {
            black = {0.05, 0.05, 0.05, 1},   -- Very dark
            dark = {0.10, 0.10, 0.10, 1},    -- Dark gray
            medium = {0.15, 0.15, 0.15, 1},  -- Medium gray
            light = {0.20, 0.20, 0.20, 1},   -- Light gray
            white = {0.95, 0.95, 0.95, 1},   -- Near white
        }
    },

    -- Semantic color tokens (use these instead of raw colors)
    colors = {
        -- Surfaces (background layers)
        surface = {0.06, 0.06, 0.06, 1},      -- Main surface (darker gray)
        surfaceAlt = {0.08, 0.08, 0.08, 1},   -- Alternative surface (slightly lighter)
        surfaceLight = {0.10, 0.10, 0.10, 1}, -- Light surface
        backdrop = {0.03, 0.03, 0.03, 0.8},   -- Backdrop/overlay

        -- Borders
        border = {0.04, 0.04, 0.04, 1},       -- Default border
        borderAlt = {0.06, 0.06, 0.06, 1},    -- Alternative border
        borderLight = {0.15, 0.15, 0.15, 1},  -- Light border
        borderAccent = {0.25, 0.25, 0.25, 1}, -- Accent border

        -- Text
        text = {0.90, 0.90, 0.90, 1},         -- Primary text
        textSecondary = {0.75, 0.75, 0.75, 1}, -- Secondary text
        textMuted = {0.55, 0.55, 0.55, 1},    -- Muted text
        accent = {0.60, 0.80, 1.0, 1},        -- Accent text/color

        -- Interactive
        hover = {0.40, 0.60, 0.80, 1},        -- Hover state
        success = {0.20, 0.70, 0.30, 1},      -- Success state
        successHover = {0.30, 0.85, 0.40, 1}, -- Success hover
        danger = {0.80, 0.30, 0.30, 1},       -- Danger state
        dangerHover = {0.95, 0.40, 0.40, 1},  -- Danger hover
        close = {0.15, 0.15, 0.15, 1},        -- Close button
        closeHover = {0.80, 0.30, 0.30, 1},   -- Close hover

        -- Effects
        highlight = {0.60, 0.80, 1.0, 0.2},   -- Highlight effect
        shadow = {0.10, 0.10, 0.10, 0.5},     -- Shadow effect
        overlay = {0.05, 0.05, 0.05, 0.8},    -- Overlay effect
    },

    -- Backwards compatibility (deprecated - use semantic colors above)
    _legacy = {
        bgDark = {0.10, 0.10, 0.10, 1},
        bgMedium = {0.12, 0.12, 0.12, 1},
        bgLight = {0.15, 0.15, 0.15, 1},
        borderDark = {0.06, 0.06, 0.06, 1},
        borderMedium = {0.08, 0.08, 0.08, 1},
        borderLight = {0.20, 0.20, 0.20, 1},
        borderNeon = {0.30, 0.30, 0.30, 1},
        textPrimary = {0.95, 0.95, 0.95, 1},
        textSecondary = {0.80, 0.80, 0.80, 1},
        textAccent = {0.60, 0.80, 1.0, 1},
        textMuted = {0.60, 0.60, 0.60, 1},
        buttonHover = {0.40, 0.60, 0.80, 1},
        buttonYes = {0.20, 0.70, 0.30, 1},
        buttonYesHover = {0.30, 0.85, 0.40, 1},
        buttonNo = {0.80, 0.30, 0.30, 1},
        buttonNoHover = {0.95, 0.40, 0.40, 1},
        buttonClose = {0.15, 0.15, 0.15, 1},
        buttonCloseHover = {0.80, 0.30, 0.30, 1},
        highlightBright = {0.60, 0.80, 1.0, 0.2},
        shadowDark = {0.10, 0.10, 0.10, 0.5},
        overlay = {0.05, 0.05, 0.05, 0.8},
    },
    
    -- Scalable typography system
    typography = {
        baseScale = 1.0,      -- Global font scale multiplier
        sizes = {
            xs = 10,          -- Extra small (stat lines, tooltips)
            sm = 12,          -- Small (secondary text)
            md = 14,          -- Medium (body text)
            lg = 18,          -- Large (headings)
            xl = 24,          -- Extra large (titles)
            xxl = 32,         -- Extra extra large (major titles)
            huge = 48,        -- Huge (hero text)
        },
        fonts = {
            regular = "assets/fonts/Orbitron-Regular.ttf",
            bold = "assets/fonts/Orbitron-Bold.ttf",
        }
    },

    -- Backwards compatibility (deprecated - use typography above)
    fonts = {
        tiny = 10,
        small = 12,
        normal = 14,
        title = 18,
        fontPath = "assets/fonts/Orbitron-Regular.ttf",
        fontPathBold = "assets/fonts/Orbitron-Bold.ttf",
    },

    -- Centralized spacing and elevation system
    spacing = {
        -- Size tokens
        xs = 4,               -- Extra small spacing
        sm = 6,               -- Small spacing (padding)
        md = 8,               -- Medium spacing (margin)
        lg = 12,             -- Large spacing
        xl = 16,             -- Extra large spacing
        xxl = 24,            -- Extra extra large spacing

        -- Specific use cases
        windowBorder = 1,    -- Border thickness
        slotSize = 72,       -- Cargo/turret/defensive slot size
        iconSize = 48,       -- Base icon size
        iconGridPadding = 12, -- Grid spacing for icon layout
    },

    -- Elevation system for shadows and depth
    elevation = {
        none = 0,            -- No elevation
        low = 2,             -- Subtle shadows (buttons)
        medium = 4,          -- Medium shadows (panels)
        high = 8,            -- High shadows (modals)
        maximum = 12,        -- Maximum shadows (tooltips)
    },

    -- Animation and effect tokens
    effects = {
        transitionMs = 150,    -- Default transition duration (ms)
        hoverLift = 2,         -- Pixels to lift on hover
        focusGlow = 2,         -- Glow radius for focus states
        shadowBlur = 4,        -- Default shadow blur
    },

    -- Theme variants for easy switching
    variants = {
        -- Current active theme (can be switched at runtime)
        current = "dark",

        -- Predefined variants
        dark = {
            name = "Dark",
            colors = {
                surface = {0.06, 0.06, 0.06, 1},
                surfaceAlt = {0.08, 0.08, 0.08, 1},
                surfaceLight = {0.10, 0.10, 0.10, 1},
                text = {0.90, 0.90, 0.90, 1},
                textSecondary = {0.75, 0.75, 0.75, 1},
                textMuted = {0.55, 0.55, 0.55, 1},
            }
        },
        light = {
            name = "Light",
            colors = {
                surface = {0.70, 0.70, 0.70, 1},
                surfaceAlt = {0.65, 0.65, 0.65, 1},
                surfaceLight = {0.60, 0.60, 0.60, 1},
                text = {0.15, 0.15, 0.15, 1},
                textSecondary = {0.25, 0.25, 0.25, 1},
                textMuted = {0.35, 0.35, 0.35, 1},
            }
        }
    },
    
    -- Window styling (Clean Boxy style)
    window = {
        borderThickness = 1,        -- Thin, clean border
        topBarHeight = 28,          -- Standard title bar height
        bottomBarHeight = 40,       -- Clean bottom bar height
        tabHeight = 72,             -- Default tab button height (matches pause buttons)
        cornerRadius = 0,           -- Sharp corners (no rounding)
        framePadding = 8,           -- Default padding between frame and content elements
    },
}

local Scaling = require('src.scaling')
local HoverSound = require('src.ui.hover_sound')

-- Color utility functions
function Theme.lerpColor(color1, color2, t)
    -- Linear interpolation between two colors
    local r = color1[1] + (color2[1] - color1[1]) * t
    local g = color1[2] + (color2[2] - color1[2]) * t
    local b = color1[3] + (color2[3] - color1[3]) * t
    local a = color1[4] + (color2[4] - color1[4]) * t
    return {r, g, b, a}
end

function Theme.withAlpha(color, alpha)
    -- Return color with modified alpha
    return {color[1], color[2], color[3], alpha}
end

function Theme.darken(color, amount)
    -- Darken color by amount (0-1, where 1 is completely black)
    local factor = 1 - amount
    return {
        color[1] * factor,
        color[2] * factor,
        color[3] * factor,
        color[4] or 1
    }
end

function Theme.lighten(color, amount)
    -- Lighten color by amount (0-1, where 1 is completely white)
    return Theme.lerpColor(color, {1, 1, 1, color[4] or 1}, amount)
end

-- Contrast and accessibility helpers
function Theme.getLuminance(color)
    -- Calculate relative luminance (WCAG formula)
    local r = color[1] <= 0.03928 and color[1]/12.92 or math.pow((color[1]+0.055)/1.055, 2.4)
    local g = color[2] <= 0.03928 and color[2]/12.92 or math.pow((color[2]+0.055)/1.055, 2.4)
    local b = color[3] <= 0.03928 and color[3]/12.92 or math.pow((color[3]+0.055)/1.055, 2.4)
    return 0.2126 * r + 0.7152 * g + 0.0722 * b
end

function Theme.getContrastRatio(color1, color2)
    -- Calculate contrast ratio between two colors
    local lum1 = Theme.getLuminance(color1)
    local lum2 = Theme.getLuminance(color2)
    local lighter = math.max(lum1, lum2)
    local darker = math.min(lum1, lum2)
    return (lighter + 0.05) / (darker + 0.05)
end

function Theme.ensureContrast(fg, bg, minRatio)
    -- Ensure foreground color has sufficient contrast against background
    -- Returns adjusted foreground color if needed
    minRatio = minRatio or 4.5  -- WCAG AA standard
    local currentRatio = Theme.getContrastRatio(fg, bg)

    if currentRatio >= minRatio then
        return fg
    end

    -- Try darkening or lightening the foreground color
    local darkened = Theme.darken(fg, 0.3)
    local lightened = Theme.lighten(fg, 0.3)

    local darkRatio = Theme.getContrastRatio(darkened, bg)
    local lightRatio = Theme.getContrastRatio(lightened, bg)

    if darkRatio > lightRatio and darkRatio >= minRatio then
        return darkened
    elseif lightRatio >= minRatio then
        return lightened
    end

    -- Fallback: return a high contrast color
    return bg[1] > 0.5 and {0.1, 0.1, 0.1, fg[4] or 1} or {0.9, 0.9, 0.9, fg[4] or 1}
end

-- Theme variant switching
function Theme.setVariant(variantName)
    -- Switch to a different theme variant
    if Theme.variants[variantName] then
        Theme.variants.current = variantName
        local variant = Theme.variants[variantName]

        -- Apply variant colors to main theme
        for key, color in pairs(variant.colors) do
            if Theme.colors[key] then
                Theme.colors[key] = color
            end
        end

        -- Clear font cache to force re-rendering with new theme
        Theme._fontCache = {
            regular = {},
            bold = {},
            fallback = {}
        }

        return true
    end
    return false
end

function Theme.getCurrentVariant()
    return Theme.variants[Theme.variants.current]
end

Theme._fontCache = {
    regular = {},
    bold = {},
    fallback = {}
}

local function cacheKey(path, size)
    return string.format("%s:%d", path or "__default__", size)
end

local function makeHoverId(prefix, x, y, w, h, extra)
    local fx = math.floor(x or 0)
    local fy = math.floor(y or 0)
    local fw = math.floor(w or 0)
    local fh = math.floor(h or 0)
    return string.format("%s:%d:%d:%d:%d:%s", prefix, fx, fy, fw, fh, extra or "")
end

local function configureFont(font)
    if font and font.setFilter then
        font:setFilter("nearest", "nearest")
    end
    return font
end

-- Helper function to create a font with sci-fi styling (scalable)
function Theme.getFont(size)
    -- Allow size to be a key from typography.sizes or a number
    if type(size) == "string" then
        size = Theme.typography.sizes[size] or Theme.typography.sizes.md
    end
    size = size or Theme.typography.sizes.md

    -- Apply global scale and external scaling
    size = size * Theme.typography.baseScale
    size = Scaling and Scaling.scaleSize and Scaling.scaleSize(size) or size

    local fontPath = Theme.typography.fonts.regular

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

-- Helper function to create a bold sci-fi font (scalable)
function Theme.getFontBold(size)
    -- Allow size to be a key from typography.sizes or a number
    if type(size) == "string" then
        size = Theme.typography.sizes[size] or Theme.typography.sizes.md
    end
    size = size or Theme.typography.sizes.md

    -- Apply global scale and external scaling
    size = size * Theme.typography.baseScale
    size = Scaling and Scaling.scaleSize and Scaling.scaleSize(size) or size

    local fontPath = Theme.typography.fonts.bold

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

-- Helper to set global font scale
function Theme.setFontScale(scale)
    Theme.typography.baseScale = scale
    -- Clear cache to force re-rendering
    Theme._fontCache = {
        regular = {},
        bold = {},
        fallback = {}
    }
end

-- Helper to get font size by semantic name
function Theme.getFontSize(name)
    return Theme.typography.sizes[name] or Theme.typography.sizes.md
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
    setColor(Theme.colors.surface)
    love.graphics.rectangle("fill", x, y, w, h)

    -- Simple flat border (sharp corners)
    setColor(Theme.colors.border)
    love.graphics.setLineWidth(depth)
    love.graphics.rectangle("line", x, y, w, h)

    love.graphics.setLineWidth(1)
end

-- Helper function to draw standard button (clean boxy style)
function Theme.drawButton(x, y, w, h, text, isHovered, buttonColor, buttonColorHover, opts)
    -- Use standard button colors as defaults if none provided
    local baseColor = buttonColor or Theme.colors.surfaceAlt
    local hoverColor = buttonColorHover or Theme.colors.hover
    opts = opts or {}
    HoverSound.update(makeHoverId("button", x, y, w, h, text), isHovered, {
        bounds = opts.bounds or {x = x, y = y, w = w, h = h},
        space = opts.space or "screen",
        clickSoundOpts = opts.clickSoundOpts,
        hoverSoundOpts = opts.hoverSoundOpts,
    })

    -- Background (sharp corners for boxy look)
    if isHovered then
        love.graphics.setColor(hoverColor[1], hoverColor[2], hoverColor[3], hoverColor[4])
    else
        love.graphics.setColor(baseColor[1], baseColor[2], baseColor[3], baseColor[4])
    end
    love.graphics.rectangle("fill", x, y, w, h)

    -- Border (sharp corners for boxy look)
    love.graphics.setColor(Theme.colors.border)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", x, y, w, h)
    love.graphics.setLineWidth(1)

    -- Text (centered)
    local textColor = opts.textColor or Theme.colors.text
    love.graphics.setColor(textColor[1], textColor[2], textColor[3], (textColor[4] or 1))

    local font = opts.font or Theme.getFont(Theme.fonts.normal)
    love.graphics.setFont(font)
    local textHeight = font:getHeight()
    local textYOffset = opts.textYOffset or (h - textHeight) / 2
    love.graphics.printf(text, x, y + textYOffset, w, opts.textAlign or "center")
end

-- Helper function to draw menu/pause style buttons that tabs can also use
function Theme.drawPanelButton(x, y, w, h, text, state)
    state = state or {}
    local alpha = state.alpha or 1
    local isActive = not not state.isActive
    local isHovered = not not state.isHovered

    local hoverKey = state.hoverSoundId or text
    HoverSound.update(makeHoverId("panel", x, y, w, h, hoverKey), isHovered, {
        bounds = {x = x, y = y, w = w, h = h},
        space = state.hoverSoundSpace or "screen",
        clickSoundOpts = state.clickSoundOpts,
        hoverSoundOpts = state.hoverSoundOpts,
    })

    local baseColor = state.baseColor or Theme.colors.surfaceAlt
    local hoverColor = state.hoverColor or Theme.colors.hover
    local activeColor = state.activeColor or hoverColor
    local borderColor = state.borderColor or Theme.colors.border
    local textColor = state.textColor or Theme.colors.text
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
return Theme
