---@diagnostic disable: undefined-global
-- Shared helper for managing continuous laser audio loops

local SoundSystem = require('src.systems.sound')

local LaserAudio = {
    soundName = "laserbeam",
    assetPath = "assets/sounds/laserbeam.wav",
    defaultVolume = 65,
    _attemptedLoad = false,
}

local function ensureLoaded()
    if LaserAudio._attemptedLoad then
        return
    end
    LaserAudio._attemptedLoad = true

    if not SoundSystem or not SoundSystem.load then
        return
    end

    if SoundSystem.sounds and SoundSystem.sounds[LaserAudio.soundName] then
        return
    end

    if love and love.filesystem and love.filesystem.getInfo and love.filesystem.getInfo(LaserAudio.assetPath) then
        SoundSystem.load(LaserAudio.soundName, LaserAudio.assetPath)
    end
end

local function isSourceActive(src)
    if not src then
        return false
    end
    if src.isStopped and src:isStopped() then
        return false
    end
    if src.isPlaying then
        return src:isPlaying()
    end
    -- Fallback: assume active if no query method
    return true
end

local function cloneOpts(opts, defaultVolume)
    local copy = {}
    if opts then
        for k, v in pairs(opts) do
            copy[k] = v
        end
    end
    if copy.volume == nil and defaultVolume ~= nil then
        copy.volume = defaultVolume
    end
    copy.loop = true
    return copy
end

function LaserAudio.start(turretComp, opts)
    if not turretComp then
        return nil
    end

    ensureLoaded()

    -- Clean up stale source references
    if turretComp.laserSound and not isSourceActive(turretComp.laserSound) then
        turretComp.laserSound = nil
    end

    if turretComp.laserSound and isSourceActive(turretComp.laserSound) then
        return turretComp.laserSound
    end

    if not SoundSystem or not SoundSystem.play then
        return nil
    end

    local playOpts = cloneOpts(opts, LaserAudio.defaultVolume)
    local instance = SoundSystem.play(LaserAudio.soundName, playOpts)

    if instance then
        turretComp.laserSound = instance
    end

    return instance
end

function LaserAudio.stop(turretComp)
    if not turretComp or not turretComp.laserSound then
        return
    end

    local src = turretComp.laserSound
    turretComp.laserSound = nil

    if src.stop then
        pcall(function()
            src:stop()
        end)
    end
end

return LaserAudio

