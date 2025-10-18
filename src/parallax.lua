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
        
        -- Generate stars for this layer
        for j = 1, parallax.layers[i].count do
            table.insert(parallax.layers[i].stars, {
                x = love.math.random(0, parallax.worldSize),
                y = love.math.random(0, parallax.worldSize),
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
    
    for _, layer in ipairs(parallax.layers) do
        -- Safety check for layer
        if not layer or not layer.stars then
            -- ...existing code...
            goto continue
        end
        
        -- Calculate parallax offset
        local offsetX = cameraX * layer.parallaxFactor
        local offsetY = cameraY * layer.parallaxFactor

        for _, star in ipairs(layer.stars) do
            -- Wrap stars around the world for infinite parallax effect
            local drawX = (star.x - offsetX) % parallax.worldSize
            if drawX < 0 then drawX = drawX + parallax.worldSize end
            local drawY = (star.y - offsetY) % parallax.worldSize
            if drawY < 0 then drawY = drawY + parallax.worldSize end

            -- Only draw stars that are visible on screen (with some padding)
            if drawX >= -50 and drawX <= screenWidth + 50 and
               drawY >= -50 and drawY <= screenHeight + 50 then
                -- Bright white stars
                love.graphics.setColor(1, 1, 1, star.brightness)
                -- Draw as tiny points (1-2 pixels)
                love.graphics.points(drawX, drawY)
            end
        end
        
        ::continue::
    end

    love.graphics.setColor(1, 1, 1) -- Reset color
end

return Parallax