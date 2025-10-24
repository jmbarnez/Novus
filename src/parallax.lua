---@diagnostic disable: undefined-global
-- Parallax starfield module
local Parallax = {}

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

			-- radial vignette so edges stay dark
			local dx = (x - w * 0.5) / (w * 0.5)
			local dy = (y - h * 0.5) / (h * 0.5)
			local dist = math.sqrt(dx * dx + dy * dy)
			local vign = math.max(0, 1.0 - dist * 0.75)

			-- final brightness and color composition
			local brightness = filament * vign
			local base_r, base_g, base_b = 0.01, 0.01, 0.03
			local fr = math.min(1, base_r + r * brightness)
			local fg = math.min(1, base_g + g * brightness)
			local fb = math.min(1, base_b + b * brightness)

			id:setPixel(x, y, fr, fg, fb, 1)
		end
	end

	-- sprinkle stars (non-animated)
	for i = 1, 400 do
		local sx = love.math.random(0, w - 1)
		local sy = love.math.random(0, h - 1)
		local size = love.math.random(1, 2)
		local bright = 0.6 + love.math.random() * 0.4
		for oy = 0, size - 1 do
			for ox = 0, size - 1 do
				local px = math.min(w - 1, sx + ox)
				local py = math.min(h - 1, sy + oy)
				local r, g, b, a = id:getPixel(px, py)
				id:setPixel(px, py, math.min(1, r + bright), math.min(1, g + bright), math.min(1, b + bright), 1)
			end
		end
	end

	-- return Image (created once)
	return love.graphics.newImage(id)
end


function Parallax.new(layers, worldSize)
    local parallax = {
        layers = {},
        nebula = {},
        worldSize = worldSize or 10000
    }
    
    for i, layer in ipairs(layers) do
        parallax.layers[i] = {
            stars = {},
            parallaxFactor = layer.parallaxFactor or 1.0,
            brightness = layer.brightness or 0.5,
            count = layer.count or 100
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
    end
    
    return parallax
end

function Parallax.draw(parallax, cameraX, cameraY, screenWidth, screenHeight)
    -- Safety checks
    if not parallax or not parallax.layers then return end

    -- Ensure no shader affects parallax rendering
    love.graphics.setShader()

    local t = love.timer and love.timer.getTime and love.timer.getTime() or 0
    -- Lazy-load a single HD background image (static background) once.
    if parallax.nebula.backgroundLoaded == nil then
        -- Try common image extensions so you can use PNG or JPEG (jpg/jpeg)
        local basePath = 'assets/backgrounds/space_hd'
        local exts = {'png', 'jpg', 'jpeg'}
        parallax.nebula.backgroundImage = false
        local loadedPath = nil
        for _, ext in ipairs(exts) do
            local imgPath = basePath .. '.' .. ext
            local ok, img = pcall(love.graphics.newImage, imgPath)
            if ok and img then
                parallax.nebula.backgroundImage = img
                loadedPath = imgPath
                break
            end
        end
        if loadedPath then
            print("[Parallax] HD background loaded: " .. loadedPath)
        else
            -- no external image found -> generate procedural 1920x1080 background
            parallax.nebula.backgroundImage = generate_hd_background(1920, 1080)
            print("[Parallax] Generated procedural HD background (1920x1080) as fallback")
        end
        -- Use linear filtering for smoother, scaled-down band rendering
    parallax.nebula.backgroundImage:setFilter('linear', 'linear')
    -- 0 => fully static background; small value gives light parallax
    parallax.nebula.backgroundParallax = 0.02
    
    -- Create a realistic wispy nebula shader using multiple octaves of noise
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
                float density = n1 * 0.5 + n2 * 0.3 + n3 * 0.2;
                density = smoothstep(0.0, 0.6, density);
                
                // Add turbulence for more detail
                float turbulence = snoise(worldPos * scale * 5.0 + time * 0.02) * 0.15;
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
                
                // Final nebula with soft glow
                float alpha = density * 0.35;
                return vec4(nebulaColor * (1.0 + density * 0.5), alpha);
            }
        ]]
        local ok, shader = pcall(love.graphics.newShader, nebulaShaderCode)
        if ok and shader then
            parallax.nebula.shaderEnabled = true
            parallax.nebula.shader = shader
            print("[Parallax] Nebula shader compiled successfully")
        else
            parallax.nebula.shaderEnabled = false
            print("[Parallax] Nebula shader failed to compile: " .. tostring(shader))
        end
    end
    
    parallax.nebula.backgroundLoaded = true
     end

    -- Draw realistic wispy nebula using shader
    if parallax.nebula.backgroundLoaded and parallax.nebula.shaderEnabled and parallax.nebula.shader then
        local savedShader = love.graphics.getShader()
        
        local winW = screenWidth or love.graphics.getWidth()
        local winH = screenHeight or love.graphics.getHeight()
        local t = love.timer.getTime()
        
        -- Create a small dummy texture if needed (shaders need a texture)
        if not parallax.nebula.dummyCanvas then
            parallax.nebula.dummyCanvas = love.graphics.newCanvas(2, 2)
        end
        
        -- Set shader uniforms
        parallax.nebula.shader:send('resolution', {winW, winH})
        parallax.nebula.shader:send('time', t)
        parallax.nebula.shader:send('cameraOffset', {cameraX or 0, cameraY or 0})
        
        -- Draw full-screen quad with nebula shader
        love.graphics.setShader(parallax.nebula.shader)
        love.graphics.setBlendMode('add')
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.draw(parallax.nebula.dummyCanvas, 0, 0, 0, winW/2, winH/2)
        love.graphics.setBlendMode('alpha')
        
        -- Restore shader
        love.graphics.setShader(savedShader)
    end
    
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