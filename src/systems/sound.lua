---@diagnostic disable: undefined-global
-- Sound System: Procedural Sound Effects
-- Generates and plays procedural sounds for game events

local SoundSystem = {
    name = "SoundSystem",
    sounds = {},
    volumes = {
        master = 10,   -- Default to 10% master volume
        music = 100,
        sfx = 100
    },
    _lastMusicVolume = 100  -- Track actual music volume multiplier
}

-- Load a single sound file (path relative to the game folder)
function SoundSystem.load(name, path)
    if not love or not love.filesystem then
        return
    end
    if love.filesystem.getInfo(path) then
        local success, src = pcall(love.audio.newSource, path, "static")
        if success and src then
            SoundSystem.sounds[name] = src
        end
    end
end

-- Load all sounds from a directory (e.g., "assets/sounds")
function SoundSystem.loadAll(dir)
    if not love or not love.filesystem then return end
    local items = love.filesystem.getDirectoryItems(dir)
    for _, file in ipairs(items) do
        local fileLower = file:lower()
        if fileLower:match("%.(wav|ogg|mp3)$") then
            local name = fileLower:gsub("%.[^%.]+$", "")
            SoundSystem.load(name, dir .. "/" .. file)
        end
    end
end

-- Set volume for a specific audio type (master, music, sfx)
function SoundSystem.setVolume(volumeType, volume)
    if SoundSystem.volumes[volumeType] then
        SoundSystem.volumes[volumeType] = math.max(0, math.min(100, volume))
        
        -- Apply to music if it's master or music volume
        if volumeType == "master" or volumeType == "music" then
            if SoundSystem.musicSource then
                local finalVolume = (SoundSystem.volumes.master / 100) * (SoundSystem.volumes.music / 100)
                SoundSystem.musicSource:setVolume(finalVolume)
            end
        end
    end
end

-- Get volume for a specific audio type
function SoundSystem.getVolume(volumeType)
    return SoundSystem.volumes[volumeType] or 100
end

-- Play a named sound. opts: {volume, pitch, loop}
function SoundSystem.play(name, opts)
    local src = SoundSystem.sounds[name]
    if not src then
        return nil
    end
    local clone = src:clone()
    
    -- Apply volume scaling based on master and sfx volumes
    local finalVolume = (SoundSystem.volumes.master / 100) * (SoundSystem.volumes.sfx / 100)
    if opts and opts.volume then 
        finalVolume = finalVolume * (opts.volume / 100)
    end
    clone:setVolume(finalVolume)
    
    if opts and opts.pitch then clone:setPitch(opts.pitch) end
    if opts and opts.loop then clone:setLooping(true) end
    clone:play()
    return clone
end

-- Music control
function SoundSystem.playMusic(path, opts)
    if SoundSystem.musicSource then
        SoundSystem.musicSource:stop()
        SoundSystem.musicSource = nil
    end
    if love.filesystem.getInfo(path) then
        -- Debug: found music file
        local success, src = pcall(love.audio.newSource, path, "stream")
        if success and src then
            SoundSystem.musicSource = src
            SoundSystem.musicSource:setLooping(true)
            
            -- Store the music volume multiplier for future reference
            local musicMultiplier = (opts and opts.volume) or 100
            SoundSystem._lastMusicVolume = musicMultiplier
            
            -- Update the music volume to match the multiplier
            SoundSystem.volumes.music = musicMultiplier
            
            -- Apply volume scaling based on master and music volumes
            local finalVolume = (SoundSystem.volumes.master / 100) * (SoundSystem.volumes.music / 100)
            SoundSystem.musicSource:setVolume(finalVolume)
            SoundSystem.musicSource:play()
        end
    end
end

function SoundSystem.stopMusic()
    if SoundSystem.musicSource then
        SoundSystem.musicSource:stop()
        SoundSystem.musicSource = nil
    end
end

return SoundSystem
