local Components = {}

-- Hull component - Represents the hull integrity of an entity (hitpoints)
-- @field current number: The current hull value of the entity
-- @field max number: The maximum hull value of the entity
Components.Hull = function(current, max)
    return {
        current = current or 100,
        max = max or 100
    }
end

-- Shield component - Represents shield energy for an entity
-- @field current number: Current shield value
-- @field max number: Maximum shield value
-- @field regen number: Shield regeneration rate (units per second)
-- @field regenDelay number: Seconds to wait after taking damage before regen
-- @field regenTimer number: Internal timer for managing regen delays
Components.Shield = function(current, max, regen, regenDelay)
    return {
        current = current or 0,
        max = max or 0,
        regen = regen or 0,
        regenDelay = regenDelay or 0,
        regenTimer = 0
    }
end

-- Durability component - Represents the health of an entity
-- @field current number: The current durability of the entity
-- @field max number: The maximum durability of the entity
Components.Durability = function(current, max)
    return {
        current = current or 100,
        max = max or 100
    }
end

-- @field ownerId number: The entity ID of the owner who fired the projectile
-- @field damage number: The amount of damage the projectile deals
-- @field brittle boolean: Whether projectile breaks on impact
-- @field isMissile boolean: True if projectile is a missile (for homing, special logic)
-- @field ownerImmunityTime number: Time remaining during which projectile won't collide with owner
Components.Projectile = function(data)
    return {
        ownerId = data.ownerId or 0,
        damage = data.damage or 10,
        brittle = data.brittle or false,
        isMissile = data.isMissile or false,
        ownerImmunityTime = data.ownerImmunityTime or 0.2  -- 0.2 seconds of immunity to owner collision
    }
end

-- LastDamager component - Tracks who last damaged an entity
-- @field pilotId number: The pilot ID of whoever dealt the last damage
-- @field weaponType string: The type of weapon used (e.g. "mining_laser", "basic_cannon")
Components.LastDamager = function(pilotId, weaponType)
    return {
        pilotId = pilotId or 0,
        weaponType = weaponType or "unknown"
    }
end

-- HomingMissile component - Makes a projectile home in on a target
-- @field targetId number: Entity ID of the target to home in on
-- @field turnRate number: Maximum turning rate in radians per second
-- @field maxRange number: Maximum range at which homing works
Components.HomingMissile = function(targetId, turnRate, maxRange)
    return {
        targetId = targetId or nil,
        turnRate = turnRate or 2.0,
        maxRange = maxRange or 1000
    }
end

return Components
