--[[
  Sound Manager Module

  Handles all audio playback including sound effects and background music.
  Integrates with game settings for volume control.
]]

local Settings = require("game.settings")

local Sound = {}

-- Audio source pools
Sound.sources = {
    sfx = {},    -- Sound effect sources (keyed by id)
    music = nil, -- Current music source
}

-- Volume levels (0-1)
Sound.volumes = {
    master = 1.0,
    sfx = 0.8,
    music = 0.5,
}

-- Track current music for looping
Sound.currentMusicId = nil

--------------------------------------------------------------------------------
-- Initialization
--------------------------------------------------------------------------------

function Sound.load()
    -- Load volume settings
    local audio = Settings.get("audio")
    if audio then
        Sound.volumes.master = audio.masterVolume or 1.0
        Sound.volumes.sfx = audio.sfxVolume or 0.8
        Sound.volumes.music = audio.musicVolume or 0.5
    end

    -- Preload sound effects
    Sound._loadSfx("laser_fire", "assets/sounds/sfx/auto_cannon_shot.wav")
    Sound._loadSfx("impact", "assets/sounds/sfx/impact.wav")
    Sound._loadSfx("explosion_small", "assets/sounds/sfx/explosion_small.wav")
    Sound._loadSfx("pickup", "assets/sounds/sfx/item_pickup.ogg")
    Sound._loadSfx("quest_complete", "assets/sounds/sfx/quest_complete.wav")
    Sound._loadSfx("dock", "assets/sounds/sfx/dock.wav")
    Sound._loadSfx("ui_click", "assets/sounds/sfx/ui_click.wav")
end

function Sound._loadSfx(id, path)
    if not love.audio then return end

    if not love.filesystem.getInfo(path) then
        print("[Sound] Warning: Missing audio file: " .. path)
        return
    end

    local ok, source = pcall(love.audio.newSource, path, "static")
    if ok and source then
        Sound.sources.sfx[id] = source
    else
        print("[Sound] Warning: Failed to load audio: " .. path)
    end
end

--------------------------------------------------------------------------------
-- Volume Control
--------------------------------------------------------------------------------

function Sound.setVolume(channel, value)
    value = math.max(0, math.min(1, value or 1))
    Sound.volumes[channel] = value

    -- Persist to settings
    local audio = Settings.get("audio") or {}
    if channel == "master" then
        audio.masterVolume = value
        -- Update current music volume immediately when master changes
        if Sound.sources.music then
            Sound.sources.music:setVolume(Sound._getMusicVolume())
        end
    elseif channel == "sfx" then
        audio.sfxVolume = value
    elseif channel == "music" then
        audio.musicVolume = value
        -- Update current music volume immediately
        if Sound.sources.music then
            Sound.sources.music:setVolume(Sound._getMusicVolume())
        end
    end
    Settings.set("audio", audio)
end

function Sound.getVolume(channel)
    return Sound.volumes[channel] or 1.0
end

function Sound._getSfxVolume()
    return Sound.volumes.master * Sound.volumes.sfx
end

function Sound._getMusicVolume()
    return Sound.volumes.master * Sound.volumes.music
end

--------------------------------------------------------------------------------
-- Sound Effects
--------------------------------------------------------------------------------

function Sound.play(id, opts)
    opts = opts or {}
    if not love.audio then return false end

    local source = Sound.sources.sfx[id]
    if not source then
        return false
    end

    -- Clone the source for overlapping playback
    local clone = source:clone()

    -- Apply volume with optional variation
    local baseVolume = Sound._getSfxVolume()
    local volumeVariation = opts.volumeVariation or 0
    local volume = baseVolume * (1 + (math.random() * 2 - 1) * volumeVariation)
    clone:setVolume(math.max(0, math.min(1, volume)))

    -- Apply pitch variation
    local basePitch = opts.pitch or 1.0
    local pitchVariation = opts.pitchVariation or 0
    local pitch = basePitch * (1 + (math.random() * 2 - 1) * pitchVariation)
    clone:setPitch(math.max(0.5, math.min(2.0, pitch)))

    clone:play()
    return true
end

--------------------------------------------------------------------------------
-- Background Music
--------------------------------------------------------------------------------

function Sound.playMusic(id, opts)
    opts = opts or {}

    -- Stop current music if playing
    Sound.stopMusic()

    if not love.audio then return false end

    local pathVariants = {
        "assets/sounds/music/" .. id .. ".ogg",
        "assets/sounds/music/" .. id .. ".mp3",
    }

    local path
    for _, candidate in ipairs(pathVariants) do
        if love.filesystem.getInfo(candidate) then
            path = candidate
            break
        end
    end

    if not path then
        print("[Sound] Warning: Missing music file for id '" .. id .. "' (tried .ogg and .mp3)")
        return false
    end

    local ok, source = pcall(love.audio.newSource, path, "stream")
    if not ok or not source then
        print("[Sound] Warning: Failed to load music: " .. path)
        return false
    end

    source:setLooping(opts.loop ~= false) -- Loop by default
    source:setVolume(Sound._getMusicVolume())
    source:play()

    Sound.sources.music = source
    Sound.currentMusicId = id
    return true
end

function Sound.stopMusic()
    if Sound.sources.music then
        Sound.sources.music:stop()
        Sound.sources.music = nil
    end
    Sound.currentMusicId = nil
end

function Sound.pauseMusic()
    if Sound.sources.music then
        Sound.sources.music:pause()
    end
end

function Sound.resumeMusic()
    if Sound.sources.music then
        Sound.sources.music:play()
    end
end

function Sound.isMusicPlaying()
    return Sound.sources.music and Sound.sources.music:isPlaying()
end

--------------------------------------------------------------------------------
-- Cleanup
--------------------------------------------------------------------------------

function Sound.stopAll()
    -- Stop all sound effects
    for _, source in pairs(Sound.sources.sfx) do
        source:stop()
    end

    -- Stop music
    Sound.stopMusic()
end

return Sound
