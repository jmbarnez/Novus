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
            table.insert(parallax.layers[i].stars, {
                x = love.math.random(0, starXMax),
                y = love.math.random(0, starYMax),
                size = love.math.random(1, 2), -- Tiny specks
                brightness = love.math.random(layer.brightness * 0.7, layer.brightness)
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
                local twinkle = star.brightness * (0.7 + 0.3 * math.abs(math.sin(t * (star.size + 1) + star.x + star.y)))
                love.graphics.setColor(1, 1, 1, twinkle)
                love.graphics.points(star.x, star.y)
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
                if drawX >= -50 and drawX <= screenWidth + 50 and drawY >= -50 and drawY <= screenHeight + 50 then
                    love.graphics.setColor(1, 1, 1, star.brightness)
                    love.graphics.points(drawX, drawY)
                end
            end
        end
        ::continue::
    end

    love.graphics.setColor(1, 1, 1) -- Reset color
end

return Parallax