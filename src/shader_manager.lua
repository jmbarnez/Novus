---@diagnostic disable: undefined-global
-- Shader Manager - Handles shader loading and application
-- Manages cel-shading and other post-processing effects

local ShaderManager = {}

local celShader = nil
-- Cel-shading is now permanently enabled - no toggle functionality

-- Initialize shaders
function ShaderManager.init()
    local shaderCode = love.filesystem.read("src/shaders/cel_shader.frag")
    if shaderCode then
        celShader = love.graphics.newShader(shaderCode)
        if celShader then
            ShaderManager.setCelShadingProperties({
                plasmaIntensity = 0.6,    -- Reduced for subtle effect (0.5-2.0)
                glowThreshold = 0.5       -- Only bright colors glow (0.0-1.0)
            })
        end
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
end

return ShaderManager

