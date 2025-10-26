-- Review: This file likely handles the plasma theme for UI. Look for expensive per-frame effects, shader usage, or allocations. If using shaders, ensure they are not recreated or recompiled every frame. If drawing gradients or effects, check if they can be cached or precomputed.

---@diagnostic disable: undefined-global
-- Plasma Theme Configuration
-- Provides universal plasma/energy-style styling for all UI and rendering elements

local PlasmaTheme = {}

-- Plasma/energy-style color palette with vibrant electric colors
PlasmaTheme.colors = {
    -- Dark navy blue background
    bgPureBlack = {0.02, 0.02, 0.1, 1},
    
    -- Health bar colors (vibrant plasma energy)
    healthBarBg = {0.05, 0.05, 0.05, 1},
    healthBarFill = {1, 0.2, 0.5, 1},      -- Electric pink/magenta
    shieldBarFill = {0.2, 0.8, 1, 1},      -- Bright cyan/electric blue
    
    -- Outline colors (glowing energy borders)
    outlineBlack = {0, 0, 0, 1},
    outlineThick = 3,      -- Standard thick outline
    outlineVeryThick = 4,  -- Extra thick for emphasis
    
    -- Asteroid/wreckage bars (energy-infused)
    asteroidBarBg = {0.15, 0.15, 0.1, 1},
    asteroidBarFill = {1, 1, 0, 1},  -- Brilliant mining-laser yellow
    
    wreckageBarBg = {0.05, 0.1, 0.1, 1},
    wreckageBarFill = {0.2, 1, 0.2, 1},  -- Bright green energy
    
    -- Text (high contrast with energy glow)
    textBright = {1, 1, 1, 1},
    textAccent = {0.4, 0.9, 1, 1},  -- Cyan accent
}

-- Helper to draw plasma-style health bar
function PlasmaTheme.drawHealthBar(x, y, width, height, ratio, isShield)
    -- Background
    love.graphics.setColor(PlasmaTheme.colors.healthBarBg)
    love.graphics.rectangle("fill", x, y, width, height, 2, 2)
    
    -- Fill
    local fillColor = isShield and PlasmaTheme.colors.shieldBarFill or PlasmaTheme.colors.healthBarFill
    love.graphics.setColor(fillColor)
    love.graphics.rectangle("fill", x + 1, y + 1, math.max(0, (width - 2) * ratio), height - 2, 1, 1)
    
    -- Thick black outline
    love.graphics.setColor(PlasmaTheme.colors.outlineBlack)
    love.graphics.setLineWidth(PlasmaTheme.colors.outlineThick)
    love.graphics.rectangle("line", x, y, width, height, 2, 2)
    love.graphics.setLineWidth(1)
end

-- Helper to draw plasma-style durability bar
function PlasmaTheme.drawDurabilityBar(x, y, width, height, ratio, barType)
    barType = barType or "asteroid"
    
    local bgColor = barType == "asteroid" and PlasmaTheme.colors.asteroidBarBg or PlasmaTheme.colors.wreckageBarBg
    local fillColor = barType == "asteroid" and PlasmaTheme.colors.asteroidBarFill or PlasmaTheme.colors.wreckageBarFill
    
    -- Background
    love.graphics.setColor(bgColor)
    love.graphics.rectangle("fill", x, y, width, height)
    
    -- Fill - no padding for very small bars (height <= 3)
    if height <= 3 then
        love.graphics.setColor(fillColor)
        love.graphics.rectangle("fill", x, y, width * ratio, height)
    else
        -- For larger bars, use padding like health bar
        love.graphics.setColor(fillColor)
        love.graphics.rectangle("fill", x + 1, y + 1, math.max(0, (width - 2) * ratio), height - 2)
    end
    
    -- Thin outline for small bars, thick for larger bars
    love.graphics.setColor(PlasmaTheme.colors.outlineBlack)
    local outlineWidth = height <= 3 and 1 or PlasmaTheme.colors.outlineThick
    love.graphics.setLineWidth(outlineWidth)
    love.graphics.rectangle("line", x, y, width, height)
    love.graphics.setLineWidth(1)
end

return PlasmaTheme

