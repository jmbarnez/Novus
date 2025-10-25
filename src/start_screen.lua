-- src/start_screen.lua
-- Start screen module

local Constants = require('src.constants')
local Theme = require('src.ui.theme')
local ShaderManager = require('src.shader_manager')
local start_screen = {}

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

-- Comet parameters
local cometCount = 4
local comets = {}
local cometParticles = {}
local cometSpeed = 120
local cometColor = {0.85, 0.95, 1, 0.35}
local cometParticleLife = 0.7
local cometParticleRate = 0.012

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
end

local title = "Novus"
local buttonText = "New Game"
local buttonWidth = 220
local buttonHeight = 40
local buttonY = nil -- will be set in draw
local buttonX = nil -- will be set in draw
local buttonHovered = false

-- Twinkling stars
local starCount = 80
local stars = {}
for i = 1, starCount do
    local brightness = math.random(70, 100) / 100
    local colorType = math.random(1, 3)
    local color
    if colorType == 1 then
        color = {1, 1, 1} -- white
    elseif colorType == 2 then
        color = {0.7, 0.8, 1} -- blue-white
    else
        color = {1, 0.95, 0.85} -- yellow-white
    end
    stars[i] = {
        x = math.random(0, Constants.getScreenWidth()),
        y = math.random(0, Constants.getScreenHeight()),
        baseAlpha = brightness * math.random(12, 32) / 100,
        twinkleSpeed = math.random(12, 32) / 10,
        size = math.random(1, 2),
        color = color,
        brightness = brightness
    }
end

    -- Twinkling stars don't need update

function start_screen.draw()
    love.graphics.clear(0, 0, 0)
    local width, height = love.graphics.getDimensions()
    -- Draw twinkling stars
    local t = love.timer.getTime()
    -- Render stars as points for a sharper look, like in-game
    local starCoords = {}
    local starColors = {}
    for i = 1, starCount do
        local s = stars[i]
        local twinkle = s.baseAlpha + 0.18 * math.abs(math.sin(t * s.twinkleSpeed + i))
        table.insert(starCoords, s.x)
        table.insert(starCoords, s.y)
        table.insert(starColors, {s.color[1], s.color[2], s.color[3], twinkle * s.brightness})
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

    -- Draw title with aurora shader effect
    local font = Theme.getFontBold(192)
    love.graphics.setFont(font)
    local titleText = title
    local titleWidth = font:getWidth(titleText)
    local titleX = width/2 - titleWidth/2
    local titleY = height * 0.25

    -- Set up aurora shader
    local auroraShader = ShaderManager.getAuroraShader()
    if auroraShader then
        local t = love.timer.getTime()

        -- Cycle through aurora colors over time
        local colorIndex1 = math.floor(t * 0.3) % #auroraColors + 1
        local colorIndex2 = (colorIndex1) % #auroraColors + 1
        local colorIndex3 = (colorIndex2 + 1) % #auroraColors + 1

        local color1 = auroraColors[colorIndex1]
        local color2 = auroraColors[colorIndex2]
        local color3 = auroraColors[colorIndex3]

        -- Update shader uniforms
        ShaderManager.setAuroraColors(color1, color2, color3)
        ShaderManager.setAuroraResolution(width, height)

        -- Calculate text bounds for shader
        local textHeight = font:getHeight()
        ShaderManager.setAuroraTextBounds(titleX, titleY, titleWidth, textHeight)

        -- Apply shader and draw title
        love.graphics.setShader(auroraShader)
        love.graphics.setColor(1, 1, 1, 1) -- White base, shader handles coloring
        love.graphics.print(titleText, titleX, titleY)
        love.graphics.setShader() -- Reset shader
    else
        -- Fallback if shader not available
        love.graphics.setColor(0.5, 0.8, 1.0, 1)
        love.graphics.print(titleText, titleX, titleY)
    end

    -- Draw 'New Game' button
    local buttonFont = Theme.getFontBold(22)
    love.graphics.setFont(buttonFont)
    buttonY = height * 0.55
    buttonX = width/2 - buttonWidth/2
    -- Check hover
    local mx, my = love.mouse.getPosition()
    buttonHovered = mx >= buttonX and mx <= buttonX + buttonWidth and my >= buttonY and my <= buttonY + buttonHeight
    -- Minimal button: flat color, small corner radius, no shadow
    -- Monochrome button: use theme background and border colors
    local bgColor = buttonHovered and Theme.colors.bgLight or Theme.colors.bgMedium
    local borderColor = {1, 1, 1, 1} -- white border
    local cornerRadius = 0
    -- Draw button background
    love.graphics.setColor(bgColor)
    love.graphics.rectangle('fill', buttonX, buttonY, buttonWidth, buttonHeight, cornerRadius, cornerRadius)
    -- Draw button border
    love.graphics.setColor(borderColor)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle('line', buttonX, buttonY, buttonWidth, buttonHeight, cornerRadius, cornerRadius)
    -- Draw button text
    love.graphics.setColor(Theme.colors.textPrimary)
    love.graphics.printf(buttonText, buttonX, buttonY + (buttonHeight - buttonFont:getHeight())/2, buttonWidth, "center")
end

function start_screen.mousepressed(x, y, button)
    if button == 1 and buttonHovered then
        return true -- signal to start game
    end
end

function start_screen.keypressed(key)
    if key == "escape" then
        love.event.quit()
    end
end

-- ...existing code...

return start_screen
