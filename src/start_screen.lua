---@diagnostic disable: undefined-global
-- src/start_screen.lua
-- Start screen module

local Constants = require('src.constants')
local Theme = require('src.ui.theme')
local ShaderManager = require('src.shader_manager')
local HoverSound = require('src.ui.hover_sound')
local start_screen = {}

-- Play the start screen intro music immediately (no fade)
function start_screen.playIntro()
    local ok, Systems = pcall(require, 'src.systems')
    if ok and Systems and Systems.SoundSystem and Systems.SoundSystem.playMusic then
        Systems.SoundSystem.playMusic("assets/music/intro.mp3", {volume = 100})
    end
end

-- Aurora colors for the shader
local auroraColors = {
    {0.2, 0.9, 0.4}, -- bright green
    {0.4, 0.8, 0.9}, -- teal
    {0.6, 0.3, 0.8}, -- purple
    {0.9, 0.2, 0.7}, -- magenta
    {0.3, 0.6, 0.9}, -- blue
    {0.8, 0.6, 0.2}, -- orange
    {0.5, 0.9, 0.6}, -- light green
    {0.7, 0.4, 0.9}, -- violet
}

-- Nebula colors for background shader
local nebulaColors = {
    {0.3, 0.1, 0.4}, -- deep purple
    {0.1, 0.2, 0.5}, -- deep blue
    {0.2, 0.1, 0.3}, -- dark violet
    {0.1, 0.3, 0.2}, -- dark teal
    {0.4, 0.1, 0.2}, -- deep red
    {0.2, 0.2, 0.1}, -- dark olive
}

-- Comet parameters
local cometCount = 4
local comets = {}
local cometParticles = {}
local cometSpeed = 120
local cometColor = {0.85, 0.95, 1, 0.35}
local cometParticleLife = 0.7
local cometParticleRate = 0.012

-- Floating particles for atmosphere
local particleCount = 20
local particles = {}
for i = 1, particleCount do
    particles[i] = {
        x = math.random(0, Constants.getScreenWidth()),
        y = math.random(0, Constants.getScreenHeight()),
        vx = math.random(-10, 10),
        vy = math.random(-5, 5),
        size = math.random(1, 3),
        alpha = math.random(20, 60) / 100,
        life = math.random(50, 100) / 100
    }
end

-- Initialize comets
local function resetComet(i, width, height)
    local angle = math.rad(25 + i * 10)
    local x = math.random(-120, width)
    local y = math.random(-120, height/2)
    local speed = cometSpeed + math.random(-40, 40)
    comets[i] = {
        x = x,
        y = y,
        dx = math.cos(angle) * speed,
        dy = math.sin(angle) * speed,
        angle = angle,
        particleTimer = 0
    }
    cometParticles[i] = {}
end

function start_screen.update(dt)
    -- Update shader time for aurora animation
    ShaderManager.updateTime()

    local width, height = love.graphics.getDimensions()
    for i = 1, cometCount do
        if not comets[i] then
            resetComet(i, width, height)
        end
        local c = comets[i]
        c.x = c.x + c.dx * dt
        c.y = c.y + c.dy * dt
        -- Emit particles for trail
        c.particleTimer = (c.particleTimer or 0) + dt
        while c.particleTimer > cometParticleRate do
            c.particleTimer = c.particleTimer - cometParticleRate
            local px = c.x - math.cos(c.angle) * 8
            local py = c.y - math.sin(c.angle) * 8
            table.insert(cometParticles[i], {
                x = px,
                y = py,
                life = cometParticleLife,
                maxLife = cometParticleLife,
                size = math.random(1, 2)
            })
        end
        -- Respawn if off screen
        if c.x > width + 120 or c.y > height + 120 then
            resetComet(i, width, height)
        end
    end
    -- Update comet particles
    for i = 1, cometCount do
        local particles = cometParticles[i]
        for j = #particles, 1, -1 do
            local p = particles[j]
            p.life = p.life - dt
            if p.life <= 0 then
                table.remove(particles, j)
            end
        end
    end
    
    -- Update floating particles
    for i = 1, particleCount do
        local p = particles[i]
        p.x = p.x + p.vx * dt
        p.y = p.y + p.vy * dt
        
        -- Wrap around screen
        if p.x < 0 then p.x = width end
        if p.x > width then p.x = 0 end
        if p.y < 0 then p.y = height end
        if p.y > height then p.y = 0 end
        
        -- Subtle life cycle
        p.life = p.life + dt * 0.1
        if p.life > 1.0 then p.life = 0.0 end
    end
end

local title = "Novus"
local buttonText = "New Game"
local loadButtonText = "Load Game"
local buttonWidth = 220
local buttonHeight = 40
local buttonSpacing = 12
local buttonY = nil -- will be set in draw
local buttonX = nil -- will be set in draw
local buttonHovered = false
local loadButtonHovered = false

-- Twinkling stars
local starCount = 150
local stars = {}
for i = 1, starCount do
    -- Much more varied brightness distribution for start screen stars
    local brightnessRoll = math.random()
    local brightness
    if brightnessRoll < 0.08 then
        -- 8% chance for very bright stars (like Sirius, Vega)
        brightness = math.random(85, 100) / 100
    elseif brightnessRoll < 0.20 then
        -- 12% chance for bright stars (like Polaris, Arcturus)
        brightness = math.random(70, 85) / 100
    elseif brightnessRoll < 0.45 then
        -- 25% chance for medium stars (most visible stars)
        brightness = math.random(50, 70) / 100
    elseif brightnessRoll < 0.75 then
        -- 30% chance for dim stars (faint but visible)
        brightness = math.random(25, 50) / 100
    else
        -- 25% chance for very dim stars (barely visible)
        brightness = math.random(10, 25) / 100
    end
    
    local colorType = math.random(1, 4)
    local color
    if colorType == 1 then
        color = {1, 1, 1} -- white
    elseif colorType == 2 then
        color = {0.7, 0.8, 1} -- blue-white
    elseif colorType == 3 then
        color = {1, 0.95, 0.85} -- yellow-white
    else
        color = {1, 0.8, 0.6} -- orange-white
    end
    
    stars[i] = {
        x = math.random(0, Constants.getScreenWidth()),
        y = math.random(0, Constants.getScreenHeight()),
        -- Base alpha varies more widely now (20% - 100% of brightness)
        baseAlpha = brightness * math.random(20, 100) / 100,
        -- Per-star twinkle speed, amplitude and phase for more variance
        twinkleSpeed = math.random(3, 50) / 10, -- 0.3 .. 5.0
        twinkleAmplitude = math.random(15, 80) / 100, -- 0.15 .. 0.80
        twinklePhase = math.random() * (2 * math.pi),
        size = math.random(1, 4), -- Slightly larger size range
        color = color,
        brightness = brightness
    }
end

    -- Twinkling stars don't need update

function start_screen.draw()
    love.graphics.clear(0.01, 0.02, 0.05)
    local width, height = love.graphics.getDimensions()
    
    -- Background gradient removed to eliminate visible lines
    
    -- Nebula background intentionally disabled on start screen.
    -- Keeping nebula shader assets in the project but not drawing them here.
    -- Draw twinkling stars
    local t = love.timer.getTime()
    -- Render stars as points for a sharper look, like in-game
    local starCoords = {}
    local starColors = {}
    for i = 1, starCount do
        local s = stars[i]
        -- Use per-star amplitude and phase for larger, varied twinkles
        local twinkle = s.baseAlpha + s.twinkleAmplitude * math.abs(math.sin(t * s.twinkleSpeed + s.twinklePhase))
        -- Cap alpha to 1.0 after applying brightness
        local alpha = math.min(1, twinkle * s.brightness)
        table.insert(starCoords, s.x)
        table.insert(starCoords, s.y)
        table.insert(starColors, {s.color[1], s.color[2], s.color[3], alpha})
    end
    for i = 1, starCount do
        local idx = (i-1)*2+1
        local c = starColors[i]
        love.graphics.setColor(c)
        love.graphics.points(starCoords[idx], starCoords[idx+1])
    end

    -- Draw comet trails as fading particles
    for i = 1, cometCount do
        local particles = cometParticles[i]
        if particles then
            for _, p in ipairs(particles) do
                local alpha = 0.18 + 0.22 * (p.life / p.maxLife)
                love.graphics.setColor(cometColor[1], cometColor[2], cometColor[3], alpha)
                love.graphics.circle('fill', p.x, p.y, p.size * (p.life / p.maxLife))
            end
        end
    end
    -- Draw comet heads
    for i = 1, cometCount do
        local c = comets[i]
        if c then
            love.graphics.setColor(1, 1, 1, 0.5)
            love.graphics.circle('fill', c.x, c.y, 4)
        end
    end
    
    -- Draw floating particles
    for i = 1, particleCount do
        local p = particles[i]
        local alpha = p.alpha * (0.5 + 0.5 * math.sin(p.life * math.pi * 2))
        love.graphics.setColor(1, 1, 1, alpha)
        love.graphics.circle('fill', p.x, p.y, p.size)
    end

    -- Draw title with aurora shader effect
    local font = Theme.getFontBold(192)
    love.graphics.setFont(font)
    local titleText = title
    local titleWidth = font:getWidth(titleText)
    local titleX = width/2 - titleWidth/2
    local titleY = height * 0.25

    -- Calculate text bounds for shader (extend bounds for aurora glow effect)
    local textHeight = font:getHeight() * 1.5 -- Make taller for aurora effect
    local glowPadding = titleWidth * 0.3 -- Add horizontal padding for glow

    -- Set up aurora shader
    local auroraShader = ShaderManager.getAuroraShader()
    if auroraShader then
        local t = love.timer.getTime()

        -- Cycle through aurora colors over time (slower for better visibility)
        local colorIndex1 = math.floor(t * 0.1) % #auroraColors + 1
        local colorIndex2 = (colorIndex1) % #auroraColors + 1
        local colorIndex3 = (colorIndex2 + 1) % #auroraColors + 1

        local color1 = auroraColors[colorIndex1]
        local color2 = auroraColors[colorIndex2]
        local color3 = auroraColors[colorIndex3]

        -- Update shader uniforms
        ShaderManager.setAuroraColors(color1, color2, color3)
        ShaderManager.setAuroraResolution(width, height)

        -- Draw title text with aurora shader applied directly to the letters
        love.graphics.setShader(auroraShader)
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.print(titleText, titleX, titleY)
        love.graphics.setShader() -- Reset shader
    else
        -- Fallback if shader not available
        love.graphics.setColor(0.5, 0.8, 1.0, 1)
        love.graphics.print(titleText, titleX, titleY)
    end

    -- Draw 'New Game' and 'Load Game' buttons using theme colors and styling
    local totalButtonsHeight = buttonHeight * 2 + buttonSpacing
    local topY = height * 0.55 - totalButtonsHeight / 2

    -- New Game button layout
    buttonY = topY
    buttonX = width/2 - buttonWidth/2
    -- Load Game button layout
    local loadButtonY = topY + buttonHeight + buttonSpacing

    -- Check hover for both buttons
    local mx, my = love.mouse.getPosition()
    buttonHovered = mx >= buttonX and mx <= buttonX + buttonWidth and my >= buttonY and my <= buttonY + buttonHeight
    loadButtonHovered = mx >= buttonX and mx <= buttonX + buttonWidth and my >= loadButtonY and my <= loadButtonY + buttonHeight

    HoverSound.update("start_screen:new_game", buttonHovered, {
        bounds = {x = buttonX, y = buttonY, w = buttonWidth, h = buttonHeight},
        space = "screen",
    })
    HoverSound.update("start_screen:load_game", loadButtonHovered, {
        bounds = {x = buttonX, y = loadButtonY, w = buttonWidth, h = buttonHeight},
        space = "screen",
    })

    -- Draw both buttons (shared styling) using semantic colors
    local baseColor = Theme.colors.surfaceAlt
    local hoverColor = Theme.colors.hover

    local function drawButton(x, y, w, h, hovered, text)
        if hovered then
            love.graphics.setColor(hoverColor[1], hoverColor[2], hoverColor[3], hoverColor[4])
        else
            love.graphics.setColor(baseColor[1], baseColor[2], baseColor[3], baseColor[4])
        end
        love.graphics.rectangle("fill", x, y, w, h)
        love.graphics.setColor(unpack(Theme.colors.border))
        love.graphics.setLineWidth(2)
        love.graphics.rectangle("line", x, y, w, h)
        love.graphics.setLineWidth(1)
        local buttonFont = Theme.getFontBold("lg")  -- Use semantic size
        love.graphics.setColor(unpack(Theme.colors.text))
        love.graphics.setFont(buttonFont)
        local textHeight = buttonFont:getHeight()
        local textYOffset = (h - textHeight) / 2
        love.graphics.printf(text, x, y + textYOffset, w, "center")
    end

    drawButton(buttonX, buttonY, buttonWidth, buttonHeight, buttonHovered, buttonText)
    drawButton(buttonX, loadButtonY, buttonWidth, buttonHeight, loadButtonHovered, loadButtonText)
end

function start_screen.mousepressed(x, y, button)
    if button ~= 1 then
        return
    end

    -- If New Game clicked, signal to enter loading state
    if buttonHovered then
        return true
    end

    -- If Load Game clicked, attempt to load the most recent save and enter game
    if loadButtonHovered then
        -- Try to load using global Game.load; fall back silently if unavailable
        if _G.Game and _G.Game.load then
            -- attempt to load default slot name 'slot1' (adjust as needed)
            local ok, err = _G.Game.load('slot1')
            if ok then
                return false -- don't trigger loading screen; Game.load will set state
            end
        end
    end
end

function start_screen.keypressed(key)
    if key == "escape" then
        love.event.quit()
    end
end

-- ...existing code...

return start_screen
