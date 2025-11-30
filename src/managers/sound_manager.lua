local SoundManager = {}

local sounds = {}
local music  = {}
local currentMusic
local sfxVolume = 0.25
local musicVolume = 0.25
local listenerX, listenerY = 0, 0
local spatialConfigured = false
local spatialRefDistance = 96
local spatialMaxDistance = 2200
local spatialRolloff = 1.25

local function get_channel_count(src)
    if src.getChannelCount then
        return src:getChannelCount()
    elseif src.getChannels then
        return src:getChannels()
    end
    return nil
end

local function safe_new_source(path, sourceType)
    if not love or not love.audio or not love.audio.newSource then
        return nil, "audio not available"
    end

    local ok, src = pcall(love.audio.newSource, path, sourceType)
    if not ok then
        return nil, src or "failed to load source"
    end

    return src, nil
end

function SoundManager.load_sound(name, path)
    if not name or not path then return nil, "name and path required" end

    local src, err = safe_new_source(path, "static")
    if not src then
        return nil, err
    end

    sounds[name] = src
    return src
end

function SoundManager.play_sound(name, volume)
    local src = sounds[name]
    if not src then return end

    local channels = get_channel_count(src)
    if src.setRelative and channels == 1 then
        src:setRelative(true)
    end

    if src.setVolume then
        local finalVolume = volume
        if finalVolume == nil then
            finalVolume = sfxVolume
        else
            finalVolume = finalVolume * sfxVolume
        end
        src:setVolume(finalVolume)
    end

    src:stop()
    src:play()
end

function SoundManager.stop_sound(name)
    local src = sounds[name]
    if src then
        src:stop()
    end
end

function SoundManager.load_music(name, path)
    if not name or not path then return nil, "name and path required" end

    local src, err = safe_new_source(path, "stream")
    if not src then
        return nil, err
    end

    music[name] = src
    return src
end

function SoundManager.play_music(name, opts)
    opts = opts or {}
    local src = music[name]
    if not src then return end

    if opts.loop ~= nil and src.setLooping then
        src:setLooping(opts.loop)
    else
        src:setLooping(true)
    end

    if src.setVolume then
        local vol = opts.volume
        if vol == nil then
            vol = musicVolume
        end
        src:setVolume(vol)
    end

    if opts.seek and src.seek then
        src:seek(opts.seek)
    end

    if currentMusic and currentMusic ~= src then
        currentMusic:stop()
    end

    currentMusic = src
    src:play()
end

function SoundManager.stop_music()
    if currentMusic then
        currentMusic:stop()
        currentMusic = nil
    end
end

function SoundManager.pause_music()
    if currentMusic then
        currentMusic:pause()
    end
end

function SoundManager.resume_music()
    if currentMusic then
        currentMusic:play()
    end
end

function SoundManager.set_music_volume(volume)
    if type(volume) ~= "number" then return end
    if volume < 0 then volume = 0 end
    if volume > 1 then volume = 1 end
    musicVolume = volume
    if currentMusic and currentMusic.setVolume then
        currentMusic:setVolume(musicVolume)
    end
end

function SoundManager.get_music_volume()
    return musicVolume
end

function SoundManager.set_global_volume(volume)
    if love and love.audio and love.audio.setVolume then
        love.audio.setVolume(volume)
    end
end

function SoundManager.set_sfx_volume(volume)
    if type(volume) ~= "number" then return end
    if volume < 0 then volume = 0 end
    if volume > 1 then volume = 1 end
    sfxVolume = volume
end

function SoundManager.get_sfx_volume()
    return sfxVolume
end

function SoundManager.set_listener_position(x, y)
    if not (love and love.audio and love.audio.setPosition) then
        return
    end
    listenerX = x or 0
    listenerY = y or 0
    if not spatialConfigured and love.audio.setDistanceModel then
        love.audio.setDistanceModel("inverseclamped")
        spatialConfigured = true
    end
    love.audio.setPosition(listenerX, listenerY, 0)
end

function SoundManager.play_sound_at(name, x, y, opts)
    local base = sounds[name]
    if not (base and base.clone) then
        return
    end
    if not (love and love.audio) then
        return
    end

    opts = opts or {}

    local src = base:clone()
    local isMono = (get_channel_count(src) == 1)

    if isMono and src.setRelative then
        src:setRelative(false)
    end

    local px = x or listenerX
    local py = y or listenerY
    if isMono and src.setPosition then
        src:setPosition(px, py, 0)
    end

    if src.setVolume then
        local vol = opts.volume or 1
        src:setVolume(vol * sfxVolume)
    end

    if isMono and src.setAttenuationDistances then
        local ref = opts.refDistance or spatialRefDistance
        local max = opts.maxDistance or spatialMaxDistance
        src:setAttenuationDistances(ref, max)
    end

    if isMono and src.setRolloff then
        local rolloff = opts.rolloff or spatialRolloff
        src:setRolloff(rolloff)
    end

    src:play()
end

function SoundManager.stop_all()
    for _, src in pairs(sounds) do
        src:stop()
    end
    for _, src in pairs(music) do
        src:stop()
    end
    currentMusic = nil
end

return SoundManager
