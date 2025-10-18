-- Sound System: Procedural Sound Effects
-- Generates and plays procedural sounds for game events

local SoundSystem = {
    name = "SoundSystem",
    sounds = {}
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

-- Play a named sound. opts: {volume, pitch, loop}
function SoundSystem.play(name, opts)
    local src = SoundSystem.sounds[name]
    if not src then
        return nil
    end
    local clone = src:clone()
    if opts and opts.volume then clone:setVolume(opts.volume) end
    if opts and opts.pitch then clone:setPitch(opts.pitch) end
    if opts and opts.loop then clone:setLooping(true) end
    clone:play()
    return clone

end

-- Music control
local musicSource = nil
function SoundSystem.playMusic(path, opts)
    if musicSource then
        musicSource:stop()
        musicSource = nil
    end
    if love.filesystem.getInfo(path) then
        print("[SoundSystem] Found music file: " .. tostring(path))
        local success, src = pcall(love.audio.newSource, path, "stream")
        if success and src then
            print("[SoundSystem] Playing music: " .. tostring(path))
            musicSource = src
            musicSource:setLooping(true)
            if opts and opts.volume then musicSource:setVolume(opts.volume) end
            musicSource:play()
        else
            print("[SoundSystem] Failed to create music source for: " .. tostring(path))
        end
    else
        print("[SoundSystem] Music file not found: " .. tostring(path))
    end
end

function SoundSystem.stopMusic()
    if musicSource then
        musicSource:stop()
        musicSource = nil
    end
end

return SoundSystem
