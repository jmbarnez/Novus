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
-- @field asteroidType string: Type of asteroid ("stone", "iron", or "crystal")
-- @field crystalFormation table: Crystal formation data for crystal asteroids (nil for non-crystal)
-- @field xpReward number: Amount of mining XP this asteroid awards when destroyed (nil = use default from SkillXP)
Components.Asteroid = function(asteroidType, crystalFormation, xpReward)
    return {
        asteroidType = asteroidType or "stone",
        crystalFormation = crystalFormation,  -- nil for non-crystal asteroids, table for crystal asteroids
        xpReward = xpReward  -- nil means use default XP calculation
    }
end

-- Attached component - marks an entity as attached to a parent entity
-- @field parentId number: Entity ID of parent
-- @field localX number: Local X offset relative to parent (in parent's local space)
-- @field localY number: Local Y offset relative to parent (in parent's local space)
Components.Attached = function(parentId, localX, localY)
    return {
        parentId = parentId or 0,
        localX = localX or 0,
        localY = localY or 0
    }
end

-- CrystalFormation component - marks a world crystal formation attached to an asteroid
-- @field size number: visual size of the crystal cluster
-- @field shardCount number: number of shards to render
-- @field color table: base color for shards
Components.CrystalFormation = function(size, shardCount, color)
    return {
        size = size or 10,
        shardCount = shardCount or 4,
        color = color or {0.7, 0.5, 1, 1}
    }
end

-- Hotspot component - marks a temporary weak point on an asteroid
-- @field timeRemaining number: seconds until hotspot expires
-- @field dpsMultiplier number: damage multiplier when mining this hotspot
-- @field timeSinceSpawn number: time since hotspot was created (for animation)
Components.Hotspot = function(timeRemaining, dpsMultiplier)
    return {
        timeRemaining = timeRemaining or 10,
        dpsMultiplier = dpsMultiplier or 2.0,
        timeSinceSpawn = 0
    }
end

-- BeingMined component - marks an asteroid that is currently being mined
-- @field lastHitTime number: time when asteroid was last hit by mining laser
Components.BeingMined = function(lastHitTime)
    return {
        lastHitTime = lastHitTime or 0
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

-- StationDetails component - Pure data for modular station rendering
Components.StationDetails = function(details)
    return details or {}
end

-- Optional: StationLabel text
Components.StationLabel = function(text)
    return text or nil
end

-- FloatingQuestionMark component - Creates a hovering question mark effect
Components.FloatingQuestionMark = function(amplitude, speed, color)
    return {
        amplitude = amplitude or 8,  -- How high the question mark bobs
        speed = speed or 2,          -- How fast it bobs
        color = color or {1, 1, 0.3, 0.8},  -- Yellow with slight transparency
        time = 0  -- Internal timer for animation
    }
end

-- Station component - Marks entity as a station (prevents conflicting behaviors)
Components.Station = function()
    return {}
end

-- Level component - Tracks entity level (enemies, players, etc.)
-- @field level number: Entity level (1-10, higher = more difficult/powerful)
--
-- Both player and enemy AI entities use this component.
-- Enemy stats (hull, shield, etc.) are scaled by level automatically in ShipLoader.createShip.
-- Player level can be used for future scaling, progression, or stat bonuses.
Components.Level = function(level)
    return {
        level = level or 1
    }
end

-- ItemCleanup component - Tracks when an item was marked for cleanup
-- @field farAwayTimestamp number: Time when item was first detected as far from player
Components.ItemCleanup = function(farAwayTimestamp)
    return {
        farAwayTimestamp = farAwayTimestamp or 0
    }
end

return Components
