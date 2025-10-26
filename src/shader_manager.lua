---@diagnostic disable: undefined-global
-- Shader Manager - Handles shader loading and application
-- Manages cel-shading and other post-processing effects

local ShaderManager = {}

local celShader = nil
local auroraShader = nil
local nebulaShader = nil
-- Cel-shading is now permanently enabled - no toggle functionality

-- Initialize shaders
function ShaderManager.init()
    print("=== ShaderManager.init() called ===")
    
    -- Load cel shader
    local celShaderCode = love.filesystem.read("src/shaders/cel_shader.frag")
    if celShaderCode then
        celShader = love.graphics.newShader(celShaderCode)
        if celShader then
            ShaderManager.setCelShadingProperties({
                plasmaIntensity = 0.6,    -- Reduced for subtle effect (0.5-2.0)
                glowThreshold = 0.5       -- Only bright colors glow (0.0-1.0)
            })
            print("Cel shader loaded successfully")
        else
            print("Failed to create cel shader")
        end
    else
        print("Failed to read cel shader file")
    end

    -- Load aurora shader
    print("=== Loading aurora shader ===")
    
    -- Try creating a shader from inline code first
    local inlineShaderCode = [[
        extern float time;
        extern vec2 resolution;
        extern vec3 color1;
        extern vec3 color2;
        extern vec3 color3;
        
        vec4 effect(vec4 color, Image texture, vec2 tex_coords, vec2 screen_coords) {
            vec4 texcolor = Texel(texture, tex_coords);
            
            // Only apply aurora effect to non-transparent pixels (the actual text)
            if (texcolor.a < 0.01) {
                return texcolor;
            }
            
            vec2 p = screen_coords / resolution;
            
            // Create flowing wave patterns
            float wave1 = sin(p.x * 4.0 + time * 1.2) * 0.5 + 0.5;
            float wave2 = sin(p.x * 3.0 - time * 0.8 + 1.5) * 0.5 + 0.5;
            float wave3 = sin(p.x * 5.0 + time * 1.8 - 0.7) * 0.5 + 0.5;
            float wavePattern = (wave1 + wave2 + wave3) / 3.0;
            
            // Cycle through all three colors
            vec3 auroraColor;
            if (wavePattern < 0.33) {
                auroraColor = mix(color1, color2, wavePattern * 3.0);
            } else if (wavePattern < 0.66) {
                auroraColor = mix(color2, color3, (wavePattern - 0.33) * 3.0);
            } else {
                auroraColor = mix(color3, color1, (wavePattern - 0.66) * 3.0);
            }
            
            // Use the original text alpha but apply aurora colors
            return vec4(auroraColor, texcolor.a) * color;
        }
    ]]
    
    print("Testing inline shader...")
    local success, result = pcall(function()
        return love.graphics.newShader(inlineShaderCode)
    end)
    if success and result then
        print("SUCCESS: Inline shader loaded!")
        auroraShader = result
    else
        print("FAILED: Inline shader failed!")
        print("Error:", result)
    end
    
    -- If simple shader failed, try the complex one
    if not auroraShader then
        local auroraVertCode = love.filesystem.read("src/shaders/aurora.vert")
        local auroraFragCode = love.filesystem.read("src/shaders/aurora.frag")
        
        print("Aurora vertex code length:", auroraVertCode and #auroraVertCode or "nil")
        print("Aurora fragment code length:", auroraFragCode and #auroraFragCode or "nil")
        
        if auroraVertCode and auroraFragCode then
            print("Creating complex aurora shader...")
            local success, result = pcall(function()
                return love.graphics.newShader(auroraFragCode, auroraVertCode)
            end)
            if success and result then
                auroraShader = result
                print("SUCCESS: Complex aurora shader loaded!")
            else
                print("FAILED to create complex aurora shader!")
                print("Error:", result)
                print("Success:", success)
            end
        else
            print("FAILED: Could not read aurora shader files")
            -- Try to list files in shaders directory
            local files = love.filesystem.getDirectoryItems("src/shaders")
            print("Files in src/shaders:")
            for i, file in ipairs(files) do
                print("  ", file)
            end
        end
    end
    
    -- Load nebula shader
    print("=== Loading nebula shader ===")
    local nebulaShaderCode = love.filesystem.read("src/shaders/nebula.frag")
    if nebulaShaderCode then
        local success, result = pcall(function()
            return love.graphics.newShader(nebulaShaderCode)
        end)
        if success and result then
            nebulaShader = result
            print("SUCCESS: Nebula shader loaded!")
        else
            print("FAILED to create nebula shader!")
            print("Error:", result)
        end
    else
        print("FAILED: Could not read nebula shader file")
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
    if nebulaShader then
        nebulaShader:send("time", love.timer.getTime())
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

-- Get nebula shader
function ShaderManager.getNebulaShader()
    return nebulaShader
end

-- Set nebula shader colors
function ShaderManager.setNebulaColors(color1, color2, color3)
    if nebulaShader then
        nebulaShader:send("nebulaColor1", color1)
        nebulaShader:send("nebulaColor2", color2)
        nebulaShader:send("nebulaColor3", color3)
    end
end

-- Set nebula shader resolution
function ShaderManager.setNebulaResolution(width, height)
    if nebulaShader then
        nebulaShader:send("resolution", {width, height})
    end
end

-- Set nebula shader intensity
function ShaderManager.setNebulaIntensity(intensity)
    if nebulaShader then
        nebulaShader:send("nebulaIntensity", intensity)
        -- Try to send nebulaDim if the shader defines it; fail safely if not present
        local ok, err = pcall(function()
            nebulaShader:send("nebulaDim", intensity)
        end)
        if not ok then
            -- Shader doesn't define nebulaDim; log for debugging but continue
            print("Warning: nebula shader does not accept 'nebulaDim' uniform:", err)
        end
    end
end

return ShaderManager

