---@diagnostic disable: undefined-global
-- Plasma Theme (merged with clean/boxy UI tokens)
-- Provides plasma-style colors and clean/boxy UI helpers

local PlasmaTheme = {}

-- Compatibility: ensure table.unpack exists in environments where it's nil
if not table.unpack and unpack then table.unpack = unpack end

PlasmaTheme._time = 0

PlasmaTheme.settings = { outline = 3, glow = 0.5, pulseSpeed = 1.2 }

PlasmaTheme.palette = { primary = {1.0,0.2,0.5,1}, accent = {0.4,0.9,1,1}, success = {0.1,1.0,0.2,1} }

PlasmaTheme.colors = {
    bgPureBlack = {0.02,0.02,0.1,1}, surface = {0.06,0.06,0.06,1}, surfaceAlt = {0.08,0.08,0.08,1},
    healthBarBg = {0.05,0.05,0.05,1}, healthBarFill = PlasmaTheme.palette.primary, shieldBarFill = {0.2,0.8,1,1},
    asteroidBarBg = {0.15,0.15,0.1,1}, asteroidBarFill = {1,1,0,1}, wreckageBarBg = {0.05,0.1,0.1,1}, wreckageBarFill = {0.2,1,0.2,1},
    border = {0.04,0.04,0.04,1}, borderLight = {0.15,0.15,0.15,1}, outlineBlack = {0,0,0,1},
    text = {0.95,0.95,0.95,1}, textSecondary = {0.75,0.75,0.75,1}, textMuted = {0.55,0.55,0.55,1}, textAccent = PlasmaTheme.palette.accent,
    hover = {0.40,0.60,0.80,1}, close = {0.15,0.15,0.15,1}, closeHover = {0.80,0.30,0.30,1},
}

-- Backwards-compatibility aliases used by existing UI code
PlasmaTheme.colors.success = PlasmaTheme.colors.success or PlasmaTheme.palette.success
PlasmaTheme.colors.danger = PlasmaTheme.colors.danger or {1,0.25,0.25,1}
PlasmaTheme.colors.accent = PlasmaTheme.palette.accent
PlasmaTheme.colors.accentHover = PlasmaTheme.colors.textAccent or PlasmaTheme.palette.accent
PlasmaTheme.colors.borderAlt = PlasmaTheme.colors.borderLight
-- Provide legacy light surface shade used by various UI panels without depending on later functions
do
    local s = PlasmaTheme.colors.surface or {0.06,0.06,0.06,1}
    local amt = 0.12
    local r = s[1] + (1 - s[1]) * amt
    local g = s[2] + (1 - s[2]) * amt
    local b = s[3] + (1 - s[3]) * amt
    local a = s[4] or 1
    PlasmaTheme.colors.surfaceLight = PlasmaTheme.colors.surfaceLight or {r,g,b,a}
end
-- Color helpers must be defined before they're used below
function PlasmaTheme.lerpColor(c1,c2,t) local r = c1[1]+(c2[1]-c1[1])*t; local g = c1[2]+(c2[2]-c1[2])*t; local b = c1[3]+(c2[3]-c1[3])*t; local a = c1[4]+(c2[4]-c1[4])*t; return {r,g,b,a} end
function PlasmaTheme.withAlpha(color, alpha) return {color[1], color[2], color[3], alpha} end
function PlasmaTheme.darken(color, amount) local factor = 1-amount; return { color[1]*factor, color[2]*factor, color[3]*factor, color[4] or 1 } end
function PlasmaTheme.lighten(color, amount) return PlasmaTheme.lerpColor(color, {1,1,1, color[4] or 1}, amount) end
PlasmaTheme.colors.successHover = PlasmaTheme.colors.success and PlasmaTheme.lighten(PlasmaTheme.colors.success, 0.15) or {0.3,0.9,0.3,1}
PlasmaTheme.colors.dangerHover = PlasmaTheme.colors.danger and PlasmaTheme.lighten(PlasmaTheme.colors.danger, 0.15) or {1,0.45,0.45,1}
-- Overlay/backdrop used by modal/pause overlays
PlasmaTheme.colors.overlay = PlasmaTheme.colors.overlay or {0.05, 0.05, 0.05, 0.8}

PlasmaTheme.typography = { baseScale=1.0, sizes = { xs=10, sm=12, md=14, lg=18, xl=24, xxl=32, huge=48 }, fonts = { regular = "assets/fonts/Orbitron-Regular.ttf", bold = "assets/fonts/Orbitron-Bold.ttf" } }

-- Backwards compatibility: provide legacy font tokens used across UI modules
PlasmaTheme.fonts = {
    tiny = 10,                               -- maps to typography.sizes.xs
    small = 12,                              -- maps to typography.sizes.sm
    normal = 14,                             -- maps to typography.sizes.md
    title = 18,                              -- maps to typography.sizes.lg
    fontPath = "assets/fonts/Orbitron-Regular.ttf",
    fontPathBold = "assets/fonts/Orbitron-Bold.ttf",
}
PlasmaTheme.spacing = { xs=4, sm=6, md=8, lg=12, xl=16, xxl=24, windowBorder=1, slotSize=72, iconSize=48, iconGridPadding=12 }
PlasmaTheme.elevation = { none=0, low=2, medium=4, high=8, maximum=12 }
PlasmaTheme.effects = { transitionMs=150, hoverLift=2, focusGlow=2, shadowBlur=4 }
PlasmaTheme.window = { borderThickness=1, topBarHeight=28, bottomBarHeight=40, tabHeight=72, cornerRadius=0, framePadding=8 }

local Scaling = require('src.scaling')
local HoverSound = require('src.ui.hover_sound')

PlasmaTheme._fontCache = { regular = {}, bold = {}, fallback = {} }

local function cacheKey(path, size) return string.format("%s:%d", path or "__default__", size) end
local function configureFont(font) if font and font.setFilter then font:setFilter("nearest","nearest") end; return font end

function PlasmaTheme.getFont(size)
    if type(size) == "string" then size = PlasmaTheme.typography.sizes[size] or PlasmaTheme.typography.sizes.md end
    size = size or PlasmaTheme.typography.sizes.md
    size = size * PlasmaTheme.typography.baseScale
    size = Scaling and Scaling.scaleSize and Scaling.scaleSize(size) or size
    local fontPath = PlasmaTheme.typography.fonts.regular
    if fontPath then
        local fontFile = love.filesystem.getInfo(fontPath)
        if fontFile then
            local key = cacheKey(fontPath, size)
            if not PlasmaTheme._fontCache.regular[key] then PlasmaTheme._fontCache.regular[key] = configureFont(love.graphics.newFont(fontPath, size)) end
            return PlasmaTheme._fontCache.regular[key]
        end
    end
    local key = cacheKey("__fallback__", size)
    if not PlasmaTheme._fontCache.fallback[key] then PlasmaTheme._fontCache.fallback[key] = configureFont(love.graphics.newFont(size)) end
    return PlasmaTheme._fontCache.fallback[key]
end

function PlasmaTheme.getFontBold(size)
    if type(size) == "string" then size = PlasmaTheme.typography.sizes[size] or PlasmaTheme.typography.sizes.md end
    size = size or PlasmaTheme.typography.sizes.md
    size = size * PlasmaTheme.typography.baseScale
    size = Scaling and Scaling.scaleSize and Scaling.scaleSize(size) or size
    local fontPath = PlasmaTheme.typography.fonts.bold
    if fontPath then
        local fontFile = love.filesystem.getInfo(fontPath)
        if fontFile then
            local key = cacheKey(fontPath, size)
            if not PlasmaTheme._fontCache.bold[key] then PlasmaTheme._fontCache.bold[key] = configureFont(love.graphics.newFont(fontPath, size)) end
            return PlasmaTheme._fontCache.bold[key]
        end
    end
    local key = cacheKey("__fallback_bold__", size)
    if not PlasmaTheme._fontCache.bold[key] then PlasmaTheme._fontCache.bold[key] = configureFont(love.graphics.newFont(size)) end
    return PlasmaTheme._fontCache.bold[key]
end

function PlasmaTheme.setFontScale(scale) PlasmaTheme.typography.baseScale = scale; PlasmaTheme._fontCache = { regular = {}, bold = {}, fallback = {} } end
function PlasmaTheme.getFontSize(name) return PlasmaTheme.typography.sizes[name] or PlasmaTheme.typography.sizes.md end



function PlasmaTheme.getLuminance(color)
    local r = color[1] <= 0.03928 and color[1]/12.92 or math.pow((color[1]+0.055)/1.055, 2.4)
    local g = color[2] <= 0.03928 and color[2]/12.92 or math.pow((color[2]+0.055)/1.055, 2.4)
    local b = color[3] <= 0.03928 and color[3]/12.92 or math.pow((color[3]+0.055)/1.055, 2.4)
    return 0.2126 * r + 0.7152 * g + 0.0722 * b
end

function PlasmaTheme.getContrastRatio(c1,c2) local lum1 = PlasmaTheme.getLuminance(c1); local lum2 = PlasmaTheme.getLuminance(c2); local lighter = math.max(lum1,lum2); local darker = math.min(lum1,lum2); return (lighter+0.05)/(darker+0.05) end

function PlasmaTheme.ensureContrast(fg,bg,minRatio)
    minRatio = minRatio or 4.5
    local currentRatio = PlasmaTheme.getContrastRatio(fg,bg)
    if currentRatio >= minRatio then return fg end
    local darkened = PlasmaTheme.darken(fg,0.3)
    local lightened = PlasmaTheme.lighten(fg,0.3)
    local darkRatio = PlasmaTheme.getContrastRatio(darkened,bg)
    local lightRatio = PlasmaTheme.getContrastRatio(lightened,bg)
    if darkRatio > lightRatio and darkRatio >= minRatio then return darkened elseif lightRatio >= minRatio then return lightened end
    return bg[1] > 0.5 and {0.1,0.1,0.1, fg[4] or 1} or {0.9,0.9,0.9, fg[4] or 1}
end

PlasmaTheme.variants = { current = "plasma", plasma = { name = "Plasma" } }
function PlasmaTheme.setVariant(name) if PlasmaTheme.variants[name] then PlasmaTheme.variants.current = name; PlasmaTheme._fontCache = { regular = {}, bold = {}, fallback = {} }; return true end; return false end
function PlasmaTheme.getCurrentVariant() return PlasmaTheme.variants[PlasmaTheme.variants.current] end

function PlasmaTheme.draw3DBorder(x,y,w,h,depth,opts)
    if type(depth)=="table" and opts==nil then opts=depth; depth=opts.depth end
    depth = depth or PlasmaTheme.window.borderThickness or 1
    opts = opts or {}
    local alpha = opts.alpha or 1
    local radius = opts.cornerRadius or PlasmaTheme.window.cornerRadius or 0
    local function setColor(color,multiplier) love.graphics.setColor(color[1],color[2],color[3],(color[4] or 1)*alpha*(multiplier or 1)) end
    setColor(PlasmaTheme.colors.surface)
    love.graphics.rectangle("fill", x,y,w,h)
    setColor(PlasmaTheme.colors.border)
    love.graphics.setLineWidth(depth)
    love.graphics.rectangle("line", x,y,w,h)
    love.graphics.setLineWidth(1)
end

function PlasmaTheme.drawButton(x,y,w,h,text,isHovered,buttonColor,buttonColorHover,opts)
    local baseColor = buttonColor or PlasmaTheme.colors.surfaceAlt
    local hoverColor = buttonColorHover or PlasmaTheme.colors.hover
    opts = opts or {}
    HoverSound.update(("button:%d:%d:%d:%d:%s"):format(x,y,w,h,text), isHovered, { bounds = opts.bounds or {x=x,y=y,w=w,h=h}, space = opts.space or "screen", clickSoundOpts = opts.clickSoundOpts, hoverSoundOpts = opts.hoverSoundOpts })
    if isHovered then love.graphics.setColor(hoverColor[1],hoverColor[2],hoverColor[3],hoverColor[4]) else love.graphics.setColor(baseColor[1],baseColor[2],baseColor[3],baseColor[4]) end
    love.graphics.rectangle("fill", x,y,w,h)
    love.graphics.setColor(PlasmaTheme.colors.border)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", x,y,w,h)
    love.graphics.setLineWidth(1)
    local textColor = opts.textColor or PlasmaTheme.colors.text
    love.graphics.setColor(textColor[1],textColor[2],textColor[3],(textColor[4] or 1))
    local font = opts.font or PlasmaTheme.getFont(PlasmaTheme.typography.sizes.md)
    love.graphics.setFont(font)
    local textHeight = font:getHeight()
    local textYOffset = opts.textYOffset or (h - textHeight)/2
    love.graphics.printf(text, x, y + textYOffset, w, opts.textAlign or "center")
end

function PlasmaTheme.drawPanelButton(x,y,w,h,text,state)
    state = state or {}
    local alpha = state.alpha or 1
    local isActive = not not state.isActive
    local isHovered = not not state.isHovered
    HoverSound.update(("panel:%d:%d:%d:%d:%s"):format(x,y,w,h,text), isHovered, { bounds = {x=x,y=y,w=w,h=h}, space = state.hoverSoundSpace or "screen", clickSoundOpts = state.clickSoundOpts, hoverSoundOpts = state.hoverSoundOpts })
    local baseColor = state.baseColor or PlasmaTheme.colors.surfaceAlt
    local hoverColor = state.hoverColor or PlasmaTheme.colors.hover
    local activeColor = state.activeColor or hoverColor
    local borderColor = state.borderColor or PlasmaTheme.colors.border
    local textColor = state.textColor or PlasmaTheme.colors.text
    local radius = state.cornerRadius or PlasmaTheme.window.cornerRadius or 0
    local borderWidth = state.borderWidth or 2
    local idleAlpha = state.idleAlpha or 0.9
    local hoverAlpha = state.hoverAlpha or 1.0
    local activeAlpha = state.activeAlpha or 1.0
    local function setColor(color,multiplier) multiplier = multiplier or 1; love.graphics.setColor(color[1],color[2],color[3],(color[4] or 1)*alpha*multiplier) end
    if isActive then setColor(activeColor, activeAlpha) elseif isHovered then setColor(hoverColor, hoverAlpha) else setColor(baseColor, idleAlpha) end
    love.graphics.rectangle("fill", x,y,w,h, radius, radius)
    setColor(borderColor)
    love.graphics.setLineWidth(borderWidth)
    love.graphics.rectangle("line", x,y,w,h, radius, radius)
    love.graphics.setLineWidth(1)
    local font = state.font or PlasmaTheme.getFont(PlasmaTheme.typography.sizes.md)
    love.graphics.setFont(font)
    setColor(textColor)
    local textHeight = font:getHeight()
    local textYOffset = state.textYOffset or (h - textHeight)/2
    love.graphics.printf(text, x, y + textYOffset, w, state.textAlign or "center")
end

function PlasmaTheme.drawHealthBar(x,y,width,height,ratio,isShield)
    love.graphics.setColor(PlasmaTheme.colors.healthBarBg)
    love.graphics.rectangle("fill", x,y,width,height,2,2)
    local fillColor = isShield and PlasmaTheme.colors.shieldBarFill or PlasmaTheme.colors.healthBarFill
    love.graphics.setColor(fillColor)
    love.graphics.rectangle("fill", x+1, y+1, math.max(0, (width-2)*ratio), height-2, 1,1)
    love.graphics.setColor(PlasmaTheme.colors.outlineBlack)
    love.graphics.setLineWidth(PlasmaTheme.settings.outline or 3)
    love.graphics.rectangle("line", x,y,width,height,2,2)
    love.graphics.setLineWidth(1)
end

function PlasmaTheme.drawDurabilityBar(x,y,width,height,ratio,barType)
    barType = barType or "asteroid"
    local bgColor = barType == "asteroid" and PlasmaTheme.colors.asteroidBarBg or PlasmaTheme.colors.wreckageBarBg
    local fillColor = barType == "asteroid" and PlasmaTheme.colors.asteroidBarFill or PlasmaTheme.colors.wreckageBarFill
    love.graphics.setColor(bgColor)
    love.graphics.rectangle("fill", x,y,width,height)
    if height <= 3 then
        love.graphics.setColor(fillColor)
        love.graphics.rectangle("fill", x,y, width*ratio, height)
    else
        love.graphics.setColor(fillColor)
        love.graphics.rectangle("fill", x+1, y+1, math.max(0, (width-2)*ratio), height-2)
    end
    love.graphics.setColor(PlasmaTheme.colors.outlineBlack)
    local outlineWidth = height <= 3 and 1 or PlasmaTheme.settings.outline or 3
    love.graphics.setLineWidth(outlineWidth)
    love.graphics.rectangle("line", x,y,width,height)
    love.graphics.setLineWidth(1)
end

function PlasmaTheme.update(dt)
    PlasmaTheme._time = (PlasmaTheme._time or 0) + (dt or 0)
end

function PlasmaTheme.pulseAlpha()
    return 0.85 + 0.15 * math.sin((PlasmaTheme._time or 0) * PlasmaTheme.settings.pulseSpeed)
end

return PlasmaTheme

