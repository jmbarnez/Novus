---@diagnostic disable: undefined-global
-- Parallax starfield module
local Parallax = {}

function Parallax.new(layers, worldSize)
    local parallax = {
        layers = {},
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
    if not parallax or not parallax.layers then
    -- ...existing code...
        return
    end
    
    local t = love.timer and love.timer.getTime and love.timer.getTime() or 0
    for _, layer in ipairs(parallax.layers) do
        if not layer or not layer.stars then goto continue end
        if layer.parallaxFactor == 0 then
            -- Static layer: draw stars at fixed screen positions, twinkling
            for _, star in ipairs(layer.stars) do
                local twinkle = star.brightness * (0.8 + 0.2 * math.abs(math.sin(t * (star.size + 1) + star.x + star.y)))
                -- Realistic bright stars with color
                love.graphics.setColor(star.r * twinkle, star.g * twinkle, star.b * twinkle, math.min(twinkle * 1.5, 1.0))
                love.graphics.circle("fill", star.x, star.y, star.size)
            end
        else
            -- Parallax layer: draw as before
            local offsetX = cameraX * layer.parallaxFactor
            local offsetY = cameraY * layer.parallaxFactor
            for _, star in ipairs(layer.stars) do
                local drawX = (star.x - offsetX) % parallax.worldSize
                if drawX < 0 then drawX = drawX + parallax.worldSize end
                local drawY = (star.y - offsetY) % parallax.worldSize
                if drawY < 0 then drawY = drawY + parallax.worldSize end
                -- Realistic bright stars with color
                love.graphics.setColor(star.r * star.brightness, star.g * star.brightness, star.b * star.brightness, math.min(star.brightness * 1.3, 1.0))
                love.graphics.circle("fill", drawX, drawY, star.size)
            end
        end
        ::continue::
    end

    love.graphics.setColor(1, 1, 1) -- Reset color
end

return Parallax