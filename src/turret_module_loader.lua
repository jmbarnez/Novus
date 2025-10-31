-- Utility to load turret module definitions by name
local M = {}

function M.getTurretModuleByName(name)
    local ok, mod = pcall(require, 'src.turret_modules.' .. name)
    if ok and type(mod) == 'table' then
        return mod
    end
    return nil
end

-- Create an instance copy of a turret module definition.
-- If `opts.loot` is true, apply randomized modifiers so looted modules vary.
function M.createInstance(moduleOrName, opts)
    opts = opts or {}
    local base = nil
    if type(moduleOrName) == 'string' then
        base = M.getTurretModuleByName(moduleOrName)
    else
        base = moduleOrName
    end
    if not base then return nil end

    -- Shallow copy base definition to create an instance (so we don't mutate shared defs)
    local instance = {}
    for k, v in pairs(base) do instance[k] = v end

    -- Ensure a default level of 1 if not provided by external systems
    instance.level = instance.level or 1

    -- Optionally randomize modifiers for looted modules
    if opts.loot and instance.allowModifiers ~= false then
        instance.modifiers = instance.modifiers and (function(tbl)
            local copy = {}
            for kk, vv in pairs(tbl) do copy[kk] = vv end
            return copy
        end)(instance.modifiers) or {}

        -- Basic modifier pool (can be expanded per-module later)
        local possibleMods = {
            damageMultiplier = {min = 0.85, max = 1.25},
            fireRateMultiplier = {min = 0.85, max = 1.25},
            rangeMultiplier = {min = 0.9, max = 1.15},
            accuracyMultiplier = {min = 0.9, max = 1.15},
        }

        -- Randomly decide which modifiers to apply
        for modKey, range in pairs(possibleMods) do
            if math.random() < 0.45 then -- ~45% chance to get this modifier
                local val = range.min + math.random() * (range.max - range.min)
                instance.modifiers[modKey] = val
            end
        end

        -- Add a small rarity tag to describe how many modifiers were applied
        local count = 0
        for _ in pairs(instance.modifiers) do count = count + 1 end
        instance.modifierRarity = count
    end

    return instance
end

return M
