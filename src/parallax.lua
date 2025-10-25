---@diagnostic disable: undefined-global
-- Parallax starfield module
local Constants = require('src.constants')
local Parallax = {}

function Parallax.new(layers, worldSize)
    local parallax = {
        layers = {},
        nebula = {},
        worldSize = worldSize or 10000
    }
    
    -- Initialize nebula shader immediately to avoid mid-render creation
    parallax.nebula.shaderEnabled = false
    if love.graphics and love.graphics.newShader then
        local nebulaShaderCode = [[
            extern vec2 resolution;
            extern number time;
            extern vec2 cameraOffset;
            
            // Simplex-like noise approximation
            vec3 mod289(vec3 x) { return x - floor(x * (1.0 / 289.0)) * 289.0; }
            vec2 mod289(vec2 x) { return x - floor(x * (1.0 / 289.0)) * 289.0; }
            vec3 permute(vec3 x) { return mod289(((x*34.0)+1.0)*x); }
            
            float snoise(vec2 v) {
                const vec4 C = vec4(0.211324865405187, 0.366025403784439, -0.577350269189626, 0.024390243902439);
                vec2 i  = floor(v + dot(v, C.yy));
                vec2 x0 = v - i + dot(i, C.xx);
                vec2 i1 = (x0.x > x0.y) ? vec2(1.0, 0.0) : vec2(0.0, 1.0);
                vec4 x12 = x0.xyxy + C.xxzz;
                x12.xy -= i1;
                i = mod289(i);
                vec3 p = permute(permute(i.y + vec3(0.0, i1.y, 1.0)) + i.x + vec3(0.0, i1.x, 1.0));
                vec3 m = max(0.5 - vec3(dot(x0,x0), dot(x12.xy,x12.xy), dot(x12.zw,x12.zw)), 0.0);
                m = m*m; m = m*m;
                vec3 x = 2.0 * fract(p * C.www) - 1.0;
                vec3 h = abs(x) - 0.5;
                vec3 ox = floor(x + 0.5);
                vec3 a0 = x - ox;
                m *= 1.79284291400159 - 0.85373472095314 * (a0*a0 + h*h);
                vec3 g;
                g.x  = a0.x  * x0.x  + h.x  * x0.y;
                g.yz = a0.yz * x12.xz + h.yz * x12.yw;
                return 130.0 * dot(m, g);
            }
            
            // Multi-octave noise for wispy clouds
            float fbm(vec2 p) {
                float value = 0.0;
                float amplitude = 0.5;
                float frequency = 1.0;
                for(int i = 0; i < 5; i++) {
                    value += amplitude * snoise(p * frequency);
                    frequency *= 2.0;
                    amplitude *= 0.5;
                }
                return value;
            }
            
            vec4 effect(vec4 color, Image tex, vec2 tc, vec2 pc)
            {
                // World position with parallax
                vec2 worldPos = (pc - resolution * 0.5) * 0.8 + cameraOffset * 0.02;
                
                // Multiple noise layers for realistic nebula
                float scale = 0.0008;
                float n1 = fbm(worldPos * scale);
                float n2 = fbm(worldPos * scale * 1.8 + vec2(100.0, 50.0));
                float n3 = fbm(worldPos * scale * 3.2 + vec2(200.0, 150.0));
                
                // Combine noise layers to create wispy tendrils
                float density = n1 * 0.4 + n2 * 0.25 + n3 * 0.15;
                density = smoothstep(0.0, 0.8, density);
                
                // Add turbulence for more detail (reduced animation speed)
                float turbulence = snoise(worldPos * scale * 5.0 + time * 0.01) * 0.15;
                density += turbulence;
                
                // Vertical gradient (thinner at top/bottom)
                float verticalGradient = 1.0 - abs(tc.y - 0.5) * 2.0;
                verticalGradient = smoothstep(0.2, 0.8, verticalGradient);
                density *= verticalGradient;
                
                // Color variations (blue to cyan-green nebula)
                vec3 color1 = vec3(0.1, 0.3, 0.95);  // Deep blue
                vec3 color2 = vec3(0.08, 0.85, 0.6); // Cyan-green
                vec3 color3 = vec3(0.3, 0.6, 1.0);   // Light blue
                
                float colorMix = snoise(worldPos * scale * 0.5) * 0.5 + 0.5;
                vec3 nebulaColor = mix(color1, color2, colorMix);
                nebulaColor = mix(nebulaColor, color3, n3 * 0.5 + 0.5);
                
                // Final nebula with soft glow (further reduced alpha and dimmer color)
                float alpha = density * 0.035; // was 0.08, now dimmer
                float nebulaDim = 0.55; // reduce color intensity
                return vec4(nebulaColor * nebulaDim, alpha);
            }
        ]]
        local ok, shader = pcall(love.graphics.newShader, nebulaShaderCode)
        if ok and shader then
            parallax.nebula.shaderEnabled = true
            parallax.nebula.shader = shader
            -- Initialize shader uniforms immediately
            local winW = love.graphics.getWidth()
            local winH = love.graphics.getHeight()
            shader:send('resolution', {winW, winH})
            shader:send('time', 0)
            shader:send('cameraOffset', {0, 0})
        end
    end
    
    -- Create dummy canvas for shader (needs a texture)
    if parallax.nebula.shaderEnabled then
        parallax.nebula.dummyCanvas = love.graphics.newCanvas(2, 2)
    end
    
    for i, layer in ipairs(layers) do
        parallax.layers[i] = {
            stars = {},
            parallaxFactor = layer.parallaxFactor or 1.0,
            brightness = layer.brightness or 0.5,
            count = layer.count or 100,
            nebulaClouds = {}
        }
        local isStatic = (parallax.layers[i].parallaxFactor == 0)
        local starXMax = isStatic and (love.graphics.getWidth()) or parallax.worldSize
        local starYMax = isStatic and (love.graphics.getHeight()) or parallax.worldSize
        -- Generate stars for this layer
        for j = 1, parallax.layers[i].count do
            -- Realistic star colors based on temperature
            local colorType = love.math.random(1, 10)
            local r, g, b
            if colorType <= 2 then
                -- Blue stars (hot, O/B type)
                r = love.math.random(70, 100) / 255
                g = love.math.random(150, 200) / 255
                b = 1.0
            elseif colorType <= 4 then
                -- White stars (A type)
                r = 1.0
                g = 1.0
                b = love.math.random(200, 255) / 255
            elseif colorType <= 6 then
                -- Yellow/White stars (F/G type like our sun)
                r = 1.0
                g = love.math.random(230, 255) / 255
                b = love.math.random(150, 200) / 255
            elseif colorType <= 8 then
                -- Orange stars (K type)
                r = 1.0
                g = love.math.random(180, 220) / 255
                b = love.math.random(80, 150) / 255
            else
                -- Red stars (M type, cool)
                r = 1.0
                g = love.math.random(100, 180) / 255
                b = love.math.random(80, 150) / 255
            end
            
            -- place stars: screen-space for static layers, world-space centered for others
            local sx, sy
            if isStatic then
                sx = love.math.random(0, starXMax)
                sy = love.math.random(0, starYMax)
            else
                sx = love.math.random(-parallax.worldSize/2, parallax.worldSize/2)
                sy = love.math.random(-parallax.worldSize/2, parallax.worldSize/2)
            end
            -- brightness as float in [0.8..1.0]*layer.brightness
            local brightness = (layer.brightness or 0.5) * (0.8 + love.math.random() * 0.2)
            table.insert(parallax.layers[i].stars, {
                x = sx,
                y = sy,
                size = love.math.random(1, 3),
                brightness = brightness,
                r = r,
                g = g,
                b = b
            })
        end
        -- Generate nebula clouds for non-static layers
        if not isStatic then
            local numClouds = love.math.random(2, 4)
            for c = 1, numClouds do
                table.insert(parallax.layers[i].nebulaClouds, {
                    x = love.math.random(-parallax.worldSize/2, parallax.worldSize/2),
                    y = love.math.random(-parallax.worldSize/2, parallax.worldSize/2),
                    scale = love.math.random(30, 60) / 100, -- 0.3 to 0.6
                    opacity = love.math.random(25, 45) / 100, -- 0.25 to 0.45
                })
            end
        end
    end
    
    return parallax
end

-- add: procedural HD background generator (1920x1080 blue-green nebula + stars)
local function generate_hd_background(w, h)
	-- require image API
	local id = love.image.newImageData(w, h)
	local seed = love.math.random() * 10000
    -- Make nebula details a bit coarser and less dense so generated clouds are thinner
    local octaves = 4
    local baseScale = 900.0

	for y = 0, h - 1 do
		for x = 0, w - 1 do
			-- fractal noise
			local nx = x / baseScale
			local ny = y / baseScale
			local v = 0
			local amp = 1.0
			local freq = 1.0
			local ampSum = 0.0
			for o = 1, octaves do
				v = v + amp * love.math.noise(nx * freq + seed, ny * freq + seed)
				ampSum = ampSum + amp
				amp = amp * 0.5
				freq = freq * 2.0
			end
			v = v / (ampSum > 0 and ampSum or 1)

			-- detail noise for filaments
			local detail = love.math.noise(nx * 8 + seed * 2, ny * 8 + seed * 2)

			-- mix factor between blue and green areas
			local mix = math.max(0, math.min(1, (v * 1.3 - 0.15)))

			-- base nebula palette
			local blue = {0.08, 0.25, 0.9}
			local green = {0.05, 0.9, 0.55}

			local r = blue[1] * (1 - mix) + green[1] * mix
			local g = blue[2] * (1 - mix) + green[2] * mix
			local b = blue[3] * (1 - mix) + green[3] * mix

			-- filaments boost
			local filament = math.pow(v * 1.2 + detail * 0.15, 2.0)

            if isStatic then
                sx = love.math.random(0, starXMax)
                sy = love.math.random(0, starYMax)
            else
                sx = love.math.random(-parallax.worldSize/2, parallax.worldSize/2)
                sy = love.math.random(-parallax.worldSize/2, parallax.worldSize/2)
            end
            local brightness = (layer.brightness or 0.5) * (0.8 + love.math.random() * 0.2)
            table.insert(parallax.layers[i].stars, {
                x = sx,
                y = sy,
                size = love.math.random(1, 3),
                brightness = brightness,
                r = r,
                g = g,
                b = b
            })
        end
    end
    
    return parallax
end

function Parallax.draw(parallax, cameraX, cameraY, screenWidth, screenHeight)
    -- Safety checks
    if not parallax or not parallax.layers then return end

    -- Ensure no shader affects parallax rendering
    love.graphics.setShader()

    -- No nebula or background: only draw stars
    
    for _, layer in ipairs(parallax.layers) do
        if not layer or not layer.stars then goto continue end

        -- Draw stars with per-layer parallax while ensuring full-screen coverage.
        -- For world-space layers we compute a world->screen scale so stars span the viewport,
        -- then apply parallaxFactor only to the camera influence so distant layers move less.
        local worldToScreenX = (screenWidth) / (parallax.worldSize or 1)
        local worldToScreenY = (screenHeight) / (parallax.worldSize or 1)
        for _, star in ipairs(layer.stars) do
            local pf = layer.parallaxFactor or 1.0
            local sx, sy
            if pf == 0 then
                -- static / screen-space layer (stars were generated in screen coords)
                sx = star.x
                sy = star.y
            else
                -- world-space star: map world position to screen with worldToScreen scale,
                -- but reduce camera influence by parallaxFactor so distant layers move less.
                sx = (screenWidth * 0.5) + ( (star.x or 0) - ( (cameraX or 0) * pf ) ) * worldToScreenX
                sy = (screenHeight * 0.5) + ( (star.y or 0) - ( (cameraY or 0) * pf ) ) * worldToScreenY
            end
            -- cheap off-screen skip
            if sx < -4 or sx > screenWidth + 4 or sy < -4 or sy > screenHeight + 4 then
                goto star_continue
            end
            love.graphics.setColor(star.r, star.g, star.b, star.brightness)
            love.graphics.points(sx, sy)
            ::star_continue::
        end
         ::continue::
    end
    
    -- Restore no shader (clean state for caller)
    love.graphics.setShader()
end

return Parallax