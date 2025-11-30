local SettingsManager = {}

local SoundManager = require "src.managers.sound_manager"
local Config = require "src.config"

local function clamp01(value)
    if type(value) ~= "number" then
        return 0
    end
    if value < 0 then
        return 0
    end
    if value > 1 then
        return 1
    end
    return value
end

function SettingsManager.get_state()
    local master = 1
    if love and love.audio and love.audio.getVolume then
        master = love.audio.getVolume() or master
    end

    local music = 1
    if SoundManager and SoundManager.get_music_volume then
        music = SoundManager.get_music_volume() or music
    end

    local sfx = 1
    if SoundManager and SoundManager.get_sfx_volume then
        sfx = SoundManager.get_sfx_volume() or sfx
    end

    local nebulaEnabled = true
    if Config and Config.BACKGROUND then
        nebulaEnabled = Config.BACKGROUND.ENABLE_NEBULA ~= false
    end

    master = clamp01(master)
    music = clamp01(music)
    sfx = clamp01(sfx)

    return {
        masterVolume = master,
        musicVolume = music,
        sfxVolume = sfx,
        nebulaEnabled = nebulaEnabled,
    }
end

function SettingsManager.set_master_volume(value)
    value = clamp01(value or 0)
    if SoundManager and SoundManager.set_global_volume then
        SoundManager.set_global_volume(value)
    elseif love and love.audio and love.audio.setVolume then
        love.audio.setVolume(value)
    end
end

function SettingsManager.set_music_volume(value)
    value = clamp01(value or 0)
    if SoundManager and SoundManager.set_music_volume then
        SoundManager.set_music_volume(value)
    end
end

function SettingsManager.set_sfx_volume(value)
    value = clamp01(value or 0)
    if SoundManager and SoundManager.set_sfx_volume then
        SoundManager.set_sfx_volume(value)
    end
end

function SettingsManager.set_nebula_enabled(enabled)
    local flag = not not enabled
    if Config and Config.BACKGROUND then
        Config.BACKGROUND.ENABLE_NEBULA = flag
    end
end

return SettingsManager
