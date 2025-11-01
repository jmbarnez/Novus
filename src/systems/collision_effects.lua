local ECS = require('src.ecs')
local EntityHelpers = require('src.entity_helpers')
local SoundSystem = require('src.systems.sound')
local CollisionUtils = require('src.collision_utils')

local math_sqrt = math.sqrt

local M = {}

local function tryLoadSoundByName(name)
    if not name or not SoundSystem or not SoundSystem.load then return false end
    if SoundSystem.sounds and SoundSystem.sounds[name] then return true end
    if not (love and love.filesystem and love.filesystem.getInfo) then return false end
    local exts = {".wav", ".ogg", ".flac", ".mp3"}
    for _, ext in ipairs(exts) do
        local path = "assets/sounds/" .. name .. ext
        if love.filesystem.getInfo(path) then
            pcall(function() SoundSystem.load(name, path) end)
            return true
        end
    end
    return false
end

local function getSurfaceKeyForEntity(targetId)
    local shield = ECS.getComponent(targetId, "Shield")
    if shield and shield.current and shield.current > 0 then
        return "shield"
    end
    if ECS.getComponent(targetId, "Hull") then
        return "hull"
    end
    if ECS.getComponent(targetId, "Asteroid") or ECS.getComponent(targetId, "Wreckage") then
        return "rock"
    end
    return "default"
end

function M.playProjectileImpactSfx(projComp, targetId, collisionX, collisionY)
    if not projComp or not projComp.impactSfx then return end
    local surfaceKey = getSurfaceKeyForEntity(targetId)
    local sfxName = projComp.impactSfx[surfaceKey] or projComp.impactSfx.default
    if not sfxName then return end
    tryLoadSoundByName(sfxName)
    if not (SoundSystem and SoundSystem.play and SoundSystem.sounds and SoundSystem.sounds[sfxName]) then
        return
    end
    local listenerX, listenerY = 0, 0
    local cameraEntities = ECS.getEntitiesWith({"Camera", "Position"})
    if #cameraEntities > 0 then
        local cameraPos = ECS.getComponent(cameraEntities[1], "Position")
        listenerX, listenerY = cameraPos.x + 400, cameraPos.y + 300
    end
    pcall(function()
        SoundSystem.play(sfxName, {volume = 80, position = {x = collisionX, y = collisionY}, listener = {x = listenerX, y = listenerY}})
    end)
end

function M.applyProjectileDamage(projectileId, targetId)
    local proj = ECS.getComponent(projectileId, "Projectile")
    if not proj then return end
    local damage = proj.damage or 10
    local shield = ECS.getComponent(targetId, "Shield")
    local hull = ECS.getComponent(targetId, "Hull")
    if shield and shield.current > 0 then
        local pos = ECS.getComponent(projectileId, "Position")
        if pos then
            EntityHelpers.createShieldImpact(pos.x, pos.y, targetId)
        end
        local remaining = shield.current - damage
        shield.current = math.max(0, remaining)
        damage = math.max(0, -remaining)
        shield.regenTimer = shield.regenDelay or 0
    end
    if damage > 0 and hull then
        hull.current = math.max(0, hull.current - damage)
    end
    local durability = ECS.getComponent(targetId, "Durability")
    if durability then
        local targetAsteroid = ECS.getComponent(targetId, "Asteroid")
        local targetWreckage = ECS.getComponent(targetId, "Wreckage")
        local damageToApply = damage
        if targetAsteroid or targetWreckage then
            if proj.weaponModule or proj.weaponType then
                damageToApply = damage * 4.0
            else
                damageToApply = damage * 0.1
            end
        end
        durability.current = durability.current - damageToApply
        if proj.ownerId then
            local weaponModule = proj.weaponModule or proj.weaponType or nil
            EntityHelpers.recordLastDamager(targetId, proj.ownerId, weaponModule)
        end
    end
    if proj.ownerId and hull then
        local weaponModule = proj.weaponModule or proj.weaponType or nil
        EntityHelpers.recordLastDamager(targetId, proj.ownerId, weaponModule)
    end
    EntityHelpers.notifyAIDamage(targetId, projectileId)
    if proj.brittle then
        local pDur = ECS.getComponent(projectileId, "Durability")
        if pDur then pDur.current = 0 end
    end
end

return M


