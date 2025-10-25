---@diagnostic disable: undefined-global
-- Shader Manager - Handles shader loading and application
-- Manages cel-shading and other post-processing effects

local ShaderManager = {}

local celShader = nil
local auroraShader = nil
-- Cel-shading is now permanently enabled - no toggle functionality

-- Initialize shaders
function ShaderManager.init()
    -- Load cel shader
    local celShaderCode = love.filesystem.read("src/shaders/cel_shader.frag")
    if celShaderCode then
        celShader = love.graphics.newShader(celShaderCode)
        if celShader then
            ShaderManager.setCelShadingProperties({
                plasmaIntensity = 0.6,    -- Reduced for subtle effect (0.5-2.0)
                glowThreshold = 0.5       -- Only bright colors glow (0.0-1.0)
            })
        end
    end

    -- Load aurora shader
    local auroraVertCode = love.filesystem.read("src/shaders/aurora.vert")
    local auroraFragCode = love.filesystem.read("src/shaders/aurora.frag")
    if auroraVertCode and auroraFragCode then
        auroraShader = love.graphics.newShader(auroraFragCode, auroraVertCode)
    end
end

-- Set cel-shading properties
function ShaderManager.setCelShadingProperties(props)
    if not celShader then return end
    
    if props.plasmaIntensity then
        celShader:send("PlasmaIntensity", props.plasmaIntensity)
    end
    if props.glowThreshold then
        celShader:send("GlowThreshold", props.glowThreshold)
    end
end

-- Get cel-shading shader
function ShaderManager.getCelShader()
    return celShader
end

-- Get aurora shader
function ShaderManager.getAuroraShader()
    return auroraShader
end

-- Check if cel-shading is enabled (always true if shader loaded successfully)
function ShaderManager.isCelShadingEnabled()
    return celShader ~= nil
end

-- Adjust visual style (kept for compatibility but does nothing now)
function ShaderManager.togglePlasmaMode()
    -- Shader is always active with Plasma settings
end

-- Set screen size for shader
function ShaderManager.setScreenSize(width, height)
    if celShader then
        celShader:send("ScreenSize", {width, height})
    end
end

-- Update time for animated effects (call every frame)
function ShaderManager.updateTime()
    if celShader then
        celShader:send("Time", love.timer.getTime())
    end
    if auroraShader then
        auroraShader:send("time", love.timer.getTime())
    end
end

-- Set aurora shader colors
function ShaderManager.setAuroraColors(color1, color2, color3)
    if auroraShader then
        auroraShader:send("color1", color1)
        auroraShader:send("color2", color2)
        auroraShader:send("color3", color3)
    end
end

-- Set aurora shader resolution
function ShaderManager.setAuroraResolution(width, height)
    if auroraShader then
        auroraShader:send("resolution", {width, height})
    end
end

-- Set aurora shader text bounds
function ShaderManager.setAuroraTextBounds(x, y, width, height)
    if auroraShader then
        auroraShader:send("textBounds", {x, y, width, height})
    end
end

return ShaderManager

