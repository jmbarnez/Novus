---@diagnostic disable: undefined-global
-- Parallax starfield module
local Parallax = {}


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
            
            table.insert(parallax.layers[i].stars, {
                x = love.math.random(0, starXMax),
                y = love.math.random(0, starYMax),
                size = love.math.random(1, 3),
                brightness = love.math.random(layer.brightness * 0.8, layer.brightness * 1.0),
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


    local t = love.timer and love.timer.getTime and love.timer.getTime() or 0
    -- Lazy-load nebula shader and create nebula layers once
    if parallax.nebula.shader == nil then
        -- Attempt to load shader from src/shaders
        local vertCode = love.filesystem.read('src/shaders/nebula_shader.vert')
        local fragCode = love.filesystem.read('src/shaders/nebula_shader.frag')
        
        if vertCode and fragCode then
            local success, shader = pcall(love.graphics.newShader, vertCode, fragCode)
            if success and shader then
                parallax.nebula.shader = shader
                print("[Parallax] Nebula shader loaded successfully")
            else
                parallax.nebula.shader = false -- mark as unavailable
                print("[Parallax] Failed to create nebula shader: " .. tostring(shader))
            end
        else
            parallax.nebula.shader = false -- mark as unavailable
            print("[Parallax] Failed to read nebula shader files - vert: " .. tostring(vertCode ~= nil) .. ", frag: " .. tostring(fragCode ~= nil))
        end
        -- Set up multiple nebula cloud layers with different parameters
        -- Nearly static, deep background layers with abundant clouds
        parallax.nebula.layers = {
            -- Very far layer 1: extremely slow, abundant small clouds
            {speed = 0.001, scale = 3.0, tint = {0.4, 0.7, 1.0}, alpha = 0.8, offset = 0, clouds = {}, cloudCount = 18},
            -- Very far layer 2: extremely slow, abundant medium clouds
            {speed = 0.0015, scale = 2.5, tint = {0.5, 0.8, 0.9}, alpha = 0.75, offset = 500, clouds = {}, cloudCount = 15},
            -- Far layer: nearly static, abundant clouds
            {speed = 0.002, scale = 2.0, tint = {0.45, 0.95, 0.7}, alpha = 0.7, offset = 1000, clouds = {}, cloudCount = 15},
            -- Mid-far layer: slightly more movement, but still slow
            {speed = 0.005, scale = 1.5, tint = {0.5, 1.0, 0.8}, alpha = 0.8, offset = 1500, clouds = {}, cloudCount = 12},
            -- Mid layer: gentle movement
            {speed = 0.01, scale = 1.2, tint = {0.55, 1.0, 0.9}, alpha = 0.85, offset = 2000, clouds = {}, cloudCount = 12}
        }
        -- generate cloud blobs for each layer spread across the world
        for _, nl in ipairs(parallax.nebula.layers) do
            for i = 1, (nl.cloudCount or 3) do
                local r
                -- Scale cloud size based on layer scale for proper depth perception
                -- Made much smaller (reduced by ~60-70%)
                if nl.scale and nl.scale >= 2.5 then
                    -- Very far layers: smaller clouds
                    r = love.math.random(250, 420) * (nl.scale or 1.0)
                elseif nl.scale and nl.scale >= 1.5 then
                    -- Mid-far layers: medium clouds
                    r = love.math.random(280, 460) * (nl.scale or 1.0)
                else
                    -- Closer layers: larger clouds
                    r = love.math.random(320, 540) * (nl.scale or 1.0)
                end
                
                -- Spawn clouds in range centered around origin for better visibility
                -- Add half worldSize to shift from 0-based to centered coordinates
                local x = love.math.random(-parallax.worldSize/2, parallax.worldSize/2)
                local y = love.math.random(-parallax.worldSize/2, parallax.worldSize/2)
                
                table.insert(nl.clouds, {
                    x = x,
                    y = y,
                    radius = r
                })
            end
        end
        if not _G.nebulaInitialized then
            print("[Parallax] Initialized " .. #parallax.nebula.layers .. " nebula layers")
            for i, nl in ipairs(parallax.nebula.layers) do
                print(string.format("[Parallax] Layer %d: %d clouds", i, #nl.clouds))
            end
            _G.nebulaInitialized = true
        end
    end

    -- Draw nebula layers beneath stars if shader available
    if parallax.nebula.shader and parallax.nebula.shader ~= false then
        local shader = parallax.nebula.shader

        -- Draw nebula layers into the active canvas (camera-relative coordinates)
        for _, nl in ipairs(parallax.nebula.layers) do
            if shader and shader.send then
                shader:send('time', t + (nl.offset or 0))
                shader:send('scale', nl.scale or 1.0)
                local tint = nl.tint or {1,1,1}
                shader:send('tint', {tint[1], tint[2], tint[3]})
                shader:send('alpha', nl.alpha or 0.5)
                -- new noise shaping uniforms with sensible defaults per-layer
                shader:send('threshold', nl.threshold or 0.45)
                shader:send('contrast', nl.contrast or 0.18)
                shader:send('noiseScale', nl.noiseScale or 1.0)
            end

            love.graphics.setShader(shader)
            love.graphics.setColor(1,1,1, nl.alpha)
            -- Draw each cloud blob in the layer as a quad centered at cloud position
            for _, cloud in ipairs(nl.clouds) do
                -- Compute screen position (like stars do)
                local offsetX = cameraX * nl.speed
                local offsetY = cameraY * nl.speed
                local screenX = cloud.x - offsetX
                local screenY = cloud.y - offsetY
                
                -- Wrap coordinates to keep them in visible range
                screenX = screenX % parallax.worldSize
                if screenX < 0 then screenX = screenX + parallax.worldSize end
                if screenX > parallax.worldSize then screenX = screenX - parallax.worldSize end
                
                screenY = screenY % parallax.worldSize
                if screenY < 0 then screenY = screenY + parallax.worldSize end
                if screenY > parallax.worldSize then screenY = screenY - parallax.worldSize end

                -- send cloud center (in canvas pixel space) and scale/radius
                if shader and shader.send then
                    shader:send('center', {screenX, screenY})
                    shader:send('cloudScale', cloud.radius)
                    -- small offset to move pattern slightly per-layer
                    shader:send('offset', {( -cameraX * nl.speed + nl.offset ) , ( -cameraY * nl.speed + nl.offset )})
                end

                -- draw quad covering the cloud radius at screen coordinates
                local left = screenX - cloud.radius
                local top = screenY - cloud.radius
                love.graphics.rectangle('fill', left, top, cloud.radius * 2, cloud.radius * 2)
            end
            love.graphics.setShader()
        end
        love.graphics.setColor(1,1,1,1)
    end
    for _, layer in ipairs(parallax.layers) do
        if not layer or not layer.stars then goto continue end
        if layer.parallaxFactor == 0 then
            -- Static layer: draw stars at fixed screen positions, twinkling
            for _, star in ipairs(layer.stars) do
                local twinkle = star.brightness * (0.8 + 0.2 * math.abs(math.sin(t * (star.size + 1) + star.x + star.y)))
                love.graphics.setColor(star.r * twinkle, star.g * twinkle, star.b * twinkle, math.min(twinkle * 1.5, 1.0))
                love.graphics.circle("fill", star.x, star.y, star.size)
            end
        else
            local offsetX = cameraX * layer.parallaxFactor
            local offsetY = cameraY * layer.parallaxFactor
            for _, star in ipairs(layer.stars) do
                local drawX = (star.x - offsetX) % parallax.worldSize
                if drawX < 0 then drawX = drawX + parallax.worldSize end
                local drawY = (star.y - offsetY) % parallax.worldSize
                if drawY < 0 then drawY = drawY + parallax.worldSize end
                love.graphics.setColor(star.r * star.brightness, star.g * star.brightness, star.b * star.brightness, math.min(star.brightness * 1.3, 1.0))
                love.graphics.circle("fill", drawX, drawY, star.size)
            end
        end
        ::continue::
    end
    love.graphics.setColor(1, 1, 1)
end

return Parallax