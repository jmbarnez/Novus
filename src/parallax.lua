---@diagnostic disable: undefined-global
-- Parallax starfield module
local Parallax = {}

-- add: procedural HD background generator (1920x1080 blue-green nebula + stars)
local function generate_hd_background(w, h)
	-- require image API
	local id = love.image.newImageData(w, h)
	local seed = love.math.random() * 10000
	local octaves = 5
	local baseScale = 600.0

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
        -- use nearest-neighbor filtering for crisp scaling (no blur)
        parallax.nebula.backgroundImage:setFilter('nearest', 'nearest')
         -- 0 => fully static background; set small value (e.g. 0.02) for slight parallax if desired
         parallax.nebula.backgroundParallax = 0
         parallax.nebula.backgroundLoaded = true
     end

    -- Draw HD background (centered; can be static or slightly parallaxed)
    if parallax.nebula.backgroundImage and parallax.nebula.backgroundImage ~= false then
        -- save current shader, disable for background draw, then restore
        local savedShader = love.graphics.getShader()
        love.graphics.setShader()
        
         local img = parallax.nebula.backgroundImage
         local iw, ih = img:getWidth(), img:getHeight()
         -- use provided screen size or fall back to actual window dimensions
         local winW = screenWidth or love.graphics.getWidth()
         local winH = screenHeight or love.graphics.getHeight()
         -- scale to cover the window while preserving aspect ratio (cover)
         local scale = math.max(winW / iw, winH / ih)
         local drawW, drawH = iw * scale, ih * scale
         -- center the scaled image; apply small parallax offset if configured
         local px = (winW * 0.5) - (drawW * 0.5) - ((cameraX or 0) * (parallax.nebula.backgroundParallax or 0))
         local py = (winH * 0.5) - (drawH * 0.5) - ((cameraY or 0) * (parallax.nebula.backgroundParallax or 0))
         love.graphics.setColor(1,1,1,1)
         love.graphics.draw(img, px, py, 0, scale, scale)
        
        -- restore the saved shader
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