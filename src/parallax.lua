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
        local success, shader = pcall(love.graphics.newShader, 'src/shaders/nebula_shader.vert', 'src/shaders/nebula_shader.frag')
        if success and shader then
            parallax.nebula.shader = shader
        else
            parallax.nebula.shader = false -- mark as unavailable
        end
        -- Set up a few nebula cloud layers with different parameters
        -- Slower, more distant nebula layers: reduced speed and larger scale
        -- Add a close, large nebula layer plus mid and far layers
        parallax.nebula.layers = {
            -- Close layer: big, fewer clouds, strong presence (large radius, faster parallax)
            {speed = 0.04, scale = 1.0, tint = {0.45, 0.6, 1.0}, alpha = 0.8, offset = 0, clouds = {} , cloudCount = 2, close = true},
            -- Mid layer: medium-sized clouds
            {speed = 0.018, scale = 1.2, tint = {0.7, 0.35, 0.9}, alpha = 0.55, offset = 1000, clouds = {}, cloudCount = 3},
            -- Far layer: soft, distant clouds
            {speed = -0.006, scale = 2.6, tint = {0.25, 0.8, 0.45}, alpha = 0.35, offset = 2000, clouds = {}, cloudCount = 2}
        }
        -- generate cloud blobs for each layer spread across the world
        for _, nl in ipairs(parallax.nebula.layers) do
            for i = 1, (nl.cloudCount or 3) do
                local r
                if nl.close then
                    -- very large clouds for the close layer
                    r = love.math.random(600, 1400) * (nl.scale or 1.0)
                else
                    -- mid/far layers
                    if nl.scale and nl.scale < 1.6 then
                        r = love.math.random(220, 560) * (nl.scale or 1.0)
                    else
                        r = love.math.random(140, 320) * (nl.scale or 1.0)
                    end
                end
                table.insert(nl.clouds, {
                    x = love.math.random(0, parallax.worldSize),
                    y = love.math.random(0, parallax.worldSize),
                    radius = r
                })
            end
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
            end

            love.graphics.setShader(shader)
            love.graphics.setColor(1,1,1, nl.alpha)
            -- Draw each cloud blob in the layer as a quad centered at cloud position
            for _, cloud in ipairs(nl.clouds) do
                -- compute world position adjusted by parallax speed
                local worldX = (cloud.x - cameraX * nl.speed) % parallax.worldSize
                if worldX < 0 then worldX = worldX + parallax.worldSize end
                local worldY = (cloud.y - cameraY * nl.speed) % parallax.worldSize
                if worldY < 0 then worldY = worldY + parallax.worldSize end

                -- send cloud center (in canvas pixel space) and scale/radius
                if shader and shader.send then
                    shader:send('center', {worldX, worldY})
                    shader:send('cloudScale', cloud.radius)
                    -- small offset to move pattern slightly per-layer
                    shader:send('offset', {( -cameraX * nl.speed + nl.offset ) , ( -cameraY * nl.speed + nl.offset )})
                end

                -- draw quad covering the cloud radius
                local left = worldX - cloud.radius
                local top = worldY - cloud.radius
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