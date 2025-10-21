---@diagnostic disable: undefined-global
-- Galaxy Backdrop System
-- Creates and renders distant galaxy spirals and nebulae for atmospheric depth

local ECS = require('src.ecs')
local Components = require('src.components')

local GalaxyBackdropSystem = {
    name = "GalaxyBackdropSystem",
    priority = 5  -- Render early, behind everything else
}

-- Create a galaxy backdrop entity
-- @param x, y - Center position of the galaxy
-- @param size - Approximate size of the galaxy
-- @param color - Base color of the galaxy {r, g, b, a}
-- @param spiralTightness - How tight the spiral arms are (0.1-0.5)
-- @param armCount - Number of spiral arms (2-4)
function GalaxyBackdropSystem.createGalaxy(x, y, size, color, spiralTightness, armCount)
    local galaxyId = ECS.createEntity()
    
    ECS.addComponent(galaxyId, "Position", Components.Position(x, y))
    ECS.addComponent(galaxyId, "GalaxyBackdrop", {
        size = size or 2000,
        color = color or {0.8, 0.6, 1.0, 0.3},
        spiralTightness = spiralTightness or 0.3,
        armCount = armCount or 2,
        coreRadius = (size or 2000) * 0.15,
        armLength = (size or 2000) * 0.8,
        -- Generate spiral arm points
        armPoints = {},
        -- Generate background stars
        backgroundStars = {},
        -- Generate nebula clouds
        nebulaClouds = {}
    })
    
    local galaxy = ECS.getComponent(galaxyId, "GalaxyBackdrop")
    
    -- Generate spiral arm points
    GalaxyBackdropSystem.generateSpiralArms(galaxy)
    
    -- Generate background stars
    GalaxyBackdropSystem.generateBackgroundStars(galaxy)
    
    -- Generate nebula clouds
    GalaxyBackdropSystem.generateNebulaClouds(galaxy)
    
    return galaxyId
end

-- Generate spiral arm points for rendering
function GalaxyBackdropSystem.generateSpiralArms(galaxy)
    galaxy.armPoints = {}
    
    for arm = 1, galaxy.armCount do
        galaxy.armPoints[arm] = {}
        local armAngle = (arm - 1) * (2 * math.pi / galaxy.armCount)
        
        -- Generate points along the spiral arm
        for i = 1, 50 do
            local t = i / 50  -- 0 to 1
            local radius = galaxy.coreRadius + (galaxy.armLength * t)
            local angle = armAngle + (t * galaxy.spiralTightness * 4 * math.pi)
            
            -- Add some noise to make it more organic
            local noiseRadius = radius * (0.8 + 0.4 * math.sin(t * 8 + arm))
            local noiseAngle = angle + (math.sin(t * 12) * 0.2)
            
            table.insert(galaxy.armPoints[arm], {
                x = math.cos(noiseAngle) * noiseRadius,
                y = math.sin(noiseAngle) * noiseRadius,
                brightness = 0.3 + 0.7 * (1 - t) * (1 - t), -- Fade out along arm
                size = 1 + 2 * (1 - t) -- Smaller stars further out
            })
        end
    end
end

-- Generate background stars scattered around the galaxy
function GalaxyBackdropSystem.generateBackgroundStars(galaxy)
    galaxy.backgroundStars = {}
    
    for i = 1, 200 do
        local angle = math.random() * 2 * math.pi
        local distance = galaxy.size * (0.5 + math.random() * 1.5) -- Extend beyond galaxy
        local x = math.cos(angle) * distance
        local y = math.sin(angle) * distance
        
        table.insert(galaxy.backgroundStars, {
            x = x,
            y = y,
            brightness = 0.1 + math.random() * 0.3,
            size = 0.5 + math.random() * 1.5,
            color = {
                0.7 + math.random() * 0.3,
                0.7 + math.random() * 0.3,
                0.8 + math.random() * 0.2,
                1.0
            }
        })
    end
end

-- Generate nebula clouds around the galaxy
function GalaxyBackdropSystem.generateNebulaClouds(galaxy)
    galaxy.nebulaClouds = {}
    
    for i = 1, 8 do
        local angle = math.random() * 2 * math.pi
        local distance = galaxy.size * (0.3 + math.random() * 0.7)
        local x = math.cos(angle) * distance
        local y = math.sin(angle) * distance
        
        table.insert(galaxy.nebulaClouds, {
            x = x,
            y = y,
            radius = 200 + math.random() * 400,
            color = {
                0.3 + math.random() * 0.4,
                0.2 + math.random() * 0.3,
                0.4 + math.random() * 0.4,
                0.1 + math.random() * 0.2
            },
            density = 0.3 + math.random() * 0.4
        })
    end
end

-- Update galaxy backdrop (for any animated effects)
function GalaxyBackdropSystem.update(dt)
    local galaxies = ECS.getEntitiesWith({"GalaxyBackdrop", "Position"})
    
    for _, galaxyId in ipairs(galaxies) do
        local galaxy = ECS.getComponent(galaxyId, "GalaxyBackdrop")
        local position = ECS.getComponent(galaxyId, "Position")
        
        if galaxy and position then
            -- Animate nebula clouds (slow drift)
            for _, cloud in ipairs(galaxy.nebulaClouds) do
                cloud.x = cloud.x + math.sin(cloud.x * 0.001) * dt * 10
                cloud.y = cloud.y + math.cos(cloud.y * 0.001) * dt * 10
            end
            
            -- Animate background stars (subtle twinkling)
            for _, star in ipairs(galaxy.backgroundStars) do
                star.brightness = star.brightness + (math.random() - 0.5) * dt * 0.5
                star.brightness = math.max(0.1, math.min(0.4, star.brightness))
            end
        end
    end
end

-- Render galaxy backdrop
function GalaxyBackdropSystem.draw()
    local galaxies = ECS.getEntitiesWith({"GalaxyBackdrop", "Position"})
    
    for _, galaxyId in ipairs(galaxies) do
        local galaxy = ECS.getComponent(galaxyId, "GalaxyBackdrop")
        local position = ECS.getComponent(galaxyId, "Position")
        
        if galaxy and position then
            love.graphics.push()
            love.graphics.translate(position.x, position.y)
            
            -- Draw nebula clouds first (behind everything)
            for _, cloud in ipairs(galaxy.nebulaClouds) do
                love.graphics.setColor(cloud.color)
                love.graphics.circle("fill", cloud.x, cloud.y, cloud.radius)
                love.graphics.circle("fill", cloud.x, cloud.y, cloud.radius * 0.7)
                love.graphics.circle("fill", cloud.x, cloud.y, cloud.radius * 0.4)
            end
            
            -- Draw galaxy core
            love.graphics.setColor(galaxy.color[1], galaxy.color[2], galaxy.color[3], galaxy.color[4] * 0.8)
            love.graphics.circle("fill", 0, 0, galaxy.coreRadius)
            
            -- Draw spiral arms
            for arm = 1, galaxy.armCount do
                local armPoints = galaxy.armPoints[arm]
                if armPoints then
                    for i, point in ipairs(armPoints) do
                        local alpha = point.brightness * galaxy.color[4]
                        love.graphics.setColor(galaxy.color[1], galaxy.color[2], galaxy.color[3], alpha)
                        love.graphics.circle("fill", point.x, point.y, point.size)
                    end
                end
            end
            
            -- Draw background stars
            for _, star in ipairs(galaxy.backgroundStars) do
                love.graphics.setColor(star.color[1], star.color[2], star.color[3], star.brightness)
                love.graphics.circle("fill", star.x, star.y, star.size)
            end
            
            love.graphics.pop()
        end
    end
    
    -- Reset color
    love.graphics.setColor(1, 1, 1, 1)
end

return GalaxyBackdropSystem
