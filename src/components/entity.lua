local Components = {}

-- Boundary component - World boundary constraints
-- @field minX number: Minimum X coordinate
-- @field maxX number: Maximum X coordinate
-- @field minY number: Minimum Y coordinate
-- @field maxY number: Maximum Y coordinate
Components.Boundary = function(minX, maxX, minY, maxY)
    return {
        minX = minX or 0,
        maxX = maxX or 0,
        minY = minY or 0,
        maxY = maxY or 0
    }
end

-- Player tag - Marks the player entity
Components.Player = function()
    return {}
end

-- Asteroid component - Marks asteroid entities and their type
-- @field asteroidType string: Type of asteroid ("stone" or "iron")
Components.Asteroid = function(asteroidType)
    return {
        asteroidType = asteroidType or "stone"
    }
end

-- Wreckage component - Marks entity as salvageable wreckage from destroyed ships
-- @field sourceShip string: Type or name of the source ship
Components.Wreckage = function(sourceShip)
    return {
        sourceShip = sourceShip or "unknown"
    }
end

-- LootDrop component - Marks whether entity drops loot when destroyed
-- @field dropsScrap boolean: Whether this wreckage drops scrap
-- @field droppedScrap boolean: Whether scrap has already been dropped
Components.LootDrop = function(dropsScrap)
    return {
        dropsScrap = dropsScrap or false,
        droppedScrap = false
    }
end

-- Collidable component - Marks entity for collision detection
-- @field radius number: Bounding circle radius for broad-phase collision
Components.Collidable = function(radius)
    return {
        radius = radius or 10
    }
end

-- Skills component - Tracks player skills and experience
-- @field skills table: Map of skill names to skill data {level, experience, requiredXp}
Components.Skills = function()
    return {
        skills = {
            mining = {
                level = 1,
                experience = 0,
                requiredXp = 100,  -- XP needed for next level
                totalXp = 0        -- Total XP earned (for history)
            },
            salvaging = {
                level = 1,
                experience = 0,
                requiredXp = 100,  -- XP needed for next level
                totalXp = 0        -- Total XP earned (for history)
            }
        }
    }
end

return Components
