---@diagnostic disable: undefined-global
-- Target HUD System - Shows hover indicators and popups for targets in space

local ECS = require('src.ecs')
local Theme = require('src.ui.plasma_theme')
local Scaling = require('src.scaling')
local PlasmaTheme = require('src.ui.plasma_theme')
local BatchRenderer = require('src.ui.batch_renderer')
local ShipLoader = require('src.ship_loader')

local TargetHUD = {
    hoveredItem = nil,
    hoveredEnemy = nil,
    hoveredAsteroid = nil,
    hoveredWreckage = nil,
    hoverRadius = 30,  -- World units
}

local function queuePanelChrome(x, y, w, h, accentHeight, cornerRadius)
    accentHeight = accentHeight or 0
    cornerRadius = cornerRadius or 0

    local bg = Theme.colors.surface
    local accent = Theme.colors.accent
    local border = Theme.colors.borderLight

    BatchRenderer.queueRect(x, y, w, h, bg[1], bg[2], bg[3], 0.95, cornerRadius)

    if accentHeight > 0 then
        BatchRenderer.queueRect(x, y, w, accentHeight, accent[1], accent[2], accent[3], 0.85, 0)
    end

    BatchRenderer.queueRectLine(
        x,
        y,
        w,
        h,
        border[1], border[2], border[3], border[4] or 1,
        math.max(1, Scaling.scaleSize and Scaling.scaleSize(1) or 1),
        cornerRadius
    )
end

local function queueProgressBar(x, y, width, height, ratio, fillColor, backgroundColor, borderColor)
    if width <= 0 or height <= 0 then return end

    ratio = math.max(0, math.min(ratio or 0, 1))

    local bg = backgroundColor or Theme.colors.surfaceAlt
    local border = borderColor or Theme.colors.borderLight
    local fillA = fillColor[4] or 1
    local bgA = bg[4] or 0.8
    local borderA = border[4] or 0.9

    BatchRenderer.queueRect(x, y, width, height, bg[1], bg[2], bg[3], bgA, 0)

    if ratio > 0 then
        local innerWidth = math.max(0, width - 2)
        local innerHeight = math.max(0, height - 2)
        BatchRenderer.queueRect(
            x + 1,
            y + 1,
            innerWidth * ratio,
            innerHeight,
            fillColor[1], fillColor[2], fillColor[3], fillA,
            0
        )
    end

    BatchRenderer.queueRectLine(
        x,
        y,
        width,
        height,
        border[1], border[2], border[3], borderA,
        math.max(1, Scaling.scaleSize and Scaling.scaleSize(1) or 1),
        0
    )
end

local function computeRatioAndPercent(current, max)
    if not current or not max or max <= 0 then
        return 0, 0
    end
    local ratio = math.max(0, math.min(current / max, 1))
    return ratio, math.floor(ratio * 100 + 0.5)
end

-- Update hover detection
function TargetHUD.update()
    local mouseX, mouseY = love.mouse.getPosition()
    
    -- Convert screen coordinates to world coordinates
    local cameraEntities = ECS.getEntitiesWith({"Camera", "Position"})
    if #cameraEntities == 0 then
        TargetHUD.hoveredItem = nil
        TargetHUD.hoveredEnemy = nil
        TargetHUD.hoveredAsteroid = nil
        TargetHUD.hoveredWreckage = nil
        return
    end
    
    local cameraComp = ECS.getComponent(cameraEntities[1], "Camera")
    local cameraPos = ECS.getComponent(cameraEntities[1], "Position")
    if not cameraComp or not cameraPos then
        TargetHUD.hoveredItem = nil
        TargetHUD.hoveredEnemy = nil
        TargetHUD.hoveredAsteroid = nil
        TargetHUD.hoveredWreckage = nil
        return
    end
    
    local worldX, worldY = Scaling.toWorld(mouseX, mouseY, cameraComp, cameraPos)
    
    -- Find closest item
    local items = ECS.getEntitiesWith({"Item", "Position"})
    local closestItem = nil
    local closestItemDist = math.huge
    
    for _, itemId in ipairs(items) do
        local position = ECS.getComponent(itemId, "Position")
        local collidable = ECS.getComponent(itemId, "Collidable")
        if position then
            local dx = worldX - position.x
            local dy = worldY - position.y
            local dist = math.sqrt(dx * dx + dy * dy)
            -- Use bounding radius for hover detection (sufficient for most cases)
            local hoverRadius = (collidable and collidable.radius or 20) + 16 -- extra fudge room
            if dist < hoverRadius and dist < closestItemDist then
                closestItemDist = dist
                closestItem = itemId
            end
        end
    end
    
    -- Find closest enemy (AI-controlled, not controlled by player)
    local allAIEntities = ECS.getEntitiesWith({"AI", "Position", "Collidable"})
    local closestEnemy = nil
    local closestEnemyDist = math.huge
    
    for _, enemyId in ipairs(allAIEntities) do
        -- Filter out enemies controlled by player
        if not ECS.hasComponent(enemyId, "ControlledBy") then
            local position = ECS.getComponent(enemyId, "Position")
            local collidable = ECS.getComponent(enemyId, "Collidable")
            
            if position and collidable then
                local dx = worldX - position.x
                local dy = worldY - position.y
                local dist = math.sqrt(dx * dx + dy * dy)
                
                -- Use collision radius + some tolerance for hover detection
                local hoverThreshold = (collidable.radius or 30) + 20
                
                if dist < hoverThreshold and dist < closestEnemyDist then
                    closestEnemyDist = dist
                    closestEnemy = enemyId
                end
            end
        end
    end
    
    -- Find closest asteroid
    local asteroids = ECS.getEntitiesWith({"Asteroid", "Position", "Collidable"})
    local closestAsteroid = nil
    local closestAsteroidDist = math.huge
    
    for _, asteroidId in ipairs(asteroids) do
        local position = ECS.getComponent(asteroidId, "Position")
        local collidable = ECS.getComponent(asteroidId, "Collidable")
        
        if position and collidable then
            local dx = worldX - position.x
            local dy = worldY - position.y
            local dist = math.sqrt(dx * dx + dy * dy)
            
            -- Use collision radius + some tolerance for hover detection
            local hoverThreshold = (collidable.radius or 30) + 20
            
            if dist < hoverThreshold and dist < closestAsteroidDist then
                closestAsteroidDist = dist
                closestAsteroid = asteroidId
            end
        end
    end
    
    -- Find closest wreckage (salvageable pieces)
    local wreckages = ECS.getEntitiesWith({"Wreckage", "Position", "Durability", "Collidable"})
    local closestWreckage = nil
    local closestWreckageDist = math.huge

    for _, wreckId in ipairs(wreckages) do
        local position = ECS.getComponent(wreckId, "Position")
        local collidable = ECS.getComponent(wreckId, "Collidable")
        if position and collidable then
            local dx = worldX - position.x
            local dy = worldY - position.y
            local dist = math.sqrt(dx * dx + dy * dy)
            local hoverThreshold = (collidable.radius or 20) + 20
            if dist < hoverThreshold and dist < closestWreckageDist then
                closestWreckageDist = dist
                closestWreckage = wreckId
            end
        end
    end

    -- Prioritize items > wreckage > asteroids > enemies if multiple are hovered
    if closestItem then
        TargetHUD.hoveredItem = closestItem
        TargetHUD.hoveredEnemy = nil
        TargetHUD.hoveredAsteroid = nil
        TargetHUD.hoveredWreckage = nil
    elseif closestWreckage then
        TargetHUD.hoveredItem = nil
        TargetHUD.hoveredEnemy = nil
        TargetHUD.hoveredAsteroid = nil
        TargetHUD.hoveredWreckage = closestWreckage
    elseif closestAsteroid then
        TargetHUD.hoveredItem = nil
        TargetHUD.hoveredEnemy = nil
        TargetHUD.hoveredAsteroid = closestAsteroid
        TargetHUD.hoveredWreckage = nil
    elseif closestEnemy then
        TargetHUD.hoveredItem = nil
        TargetHUD.hoveredEnemy = closestEnemy
        TargetHUD.hoveredAsteroid = nil
        TargetHUD.hoveredWreckage = nil
    else
        TargetHUD.hoveredItem = nil
        TargetHUD.hoveredEnemy = nil
        TargetHUD.hoveredAsteroid = nil
        TargetHUD.hoveredWreckage = nil
    end
end

local function drawEntityOutline(entityId)
    local position = ECS.getComponent(entityId, "Position")
    if not position then return end

    local polygonShape = ECS.getComponent(entityId, "PolygonShape")
    local collidable = ECS.getComponent(entityId, "Collidable")

    if polygonShape and polygonShape.vertices and #polygonShape.vertices > 2 then
        local flatVertices = {}
        for i = 1, #polygonShape.vertices do
            local v = polygonShape.vertices[i]
            flatVertices[#flatVertices + 1] = v.x
            flatVertices[#flatVertices + 1] = v.y
        end

        local rotation = polygonShape.rotation or 0
        love.graphics.push()
        love.graphics.translate(position.x, position.y)
        love.graphics.rotate(rotation)
        love.graphics.polygon("line", flatVertices)
        love.graphics.pop()
    elseif collidable then
        love.graphics.circle("line", position.x, position.y, collidable.radius or 30)
    end
end

-- Draw world-space indicator around hovered objects
function TargetHUD.drawWorldIndicator()
    local indicatorColor = Theme.colors.accent

    love.graphics.setColor(indicatorColor[1], indicatorColor[2], indicatorColor[3], 0.8)
    love.graphics.setLineWidth(2)

    if TargetHUD.hoveredItem then
        drawEntityOutline(TargetHUD.hoveredItem)
    end

    if TargetHUD.hoveredWreckage then
        drawEntityOutline(TargetHUD.hoveredWreckage)
    end

    if TargetHUD.hoveredAsteroid then
        drawEntityOutline(TargetHUD.hoveredAsteroid)
    end

    if TargetHUD.hoveredEnemy then
        drawEntityOutline(TargetHUD.hoveredEnemy)
    end

    love.graphics.setLineWidth(1)
end

-- Draw popup (in screen space, same style/position as skill notifications)
function TargetHUD.drawPopup()
    -- Only show popup if hovering an item, asteroid, enemy, or wreckage
    if not TargetHUD.hoveredItem and not TargetHUD.hoveredEnemy and not TargetHUD.hoveredAsteroid and not TargetHUD.hoveredWreckage then return end
    
    -- Same positioning as skill notifications
    local screenW = Scaling.getCurrentWidth()
    local popupWidth = Scaling.scaleSize(420)
    local cornerRadius = Scaling.scaleSize(8)
    local accentHeight = math.max(Scaling.scaleSize(4), 2)

    -- Layout metrics
    local padX = Scaling.scaleX(18)
    local padTop = Scaling.scaleY(16)
    local padBottom = Scaling.scaleY(18)
    local lineGap = Scaling.scaleY(6)
    local sectionGap = Scaling.scaleY(12)
    local barLabelGap = Scaling.scaleY(4)
    local barSpacing = Scaling.scaleY(10)
    local barHeight = Scaling.scaleSize(8)

    -- Fonts & palette
    local normalFont = Theme.getFont(Scaling.scaleSize(Theme.fonts.normal))
    local titleFont = Theme.getFontBold(Scaling.scaleSize(Theme.fonts.normal))
    local smallFont = Theme.getFont(Scaling.scaleSize(Theme.fonts.small))

    local textPrimary = Theme.colors.text
    local textSecondary = Theme.colors.textSecondary
    local accentColor = Theme.colors.accent

    -- Calculate starting Y position - below any skill notifications
    local y = Scaling.scaleY(18)
    local x = (screenW - popupWidth) / 2
    local popupHeight = accentHeight + padTop + padBottom + titleFont:getHeight()

    local content = { type = nil }

    if TargetHUD.hoveredItem then
        local item = ECS.getComponent(TargetHUD.hoveredItem, "Item")
        if not item or not item.def then return end

        content.type = "item"
        content.title = string.upper(item.def.name or "UNKNOWN ITEM")

        local metaParts = {}
        if item.def.value then
            table.insert(metaParts, string.format("Value: %d", math.floor(item.def.value + 0.5)))
        end
        if item.def.volume then
            table.insert(metaParts, string.format("Volume: %.3f m^3", item.def.volume))
        end
        if item.def.stackable then
            table.insert(metaParts, "Stackable")
        end

        if #metaParts > 0 then
            content.metaText = table.concat(metaParts, "   ")
            popupHeight = popupHeight + lineGap + smallFont:getHeight()
        end

        popupHeight = math.max(popupHeight, Scaling.scaleSize(78))

    elseif TargetHUD.hoveredAsteroid then
        local asteroid = ECS.getComponent(TargetHUD.hoveredAsteroid, "Asteroid")
        local durability = ECS.getComponent(TargetHUD.hoveredAsteroid, "Durability")
        if not asteroid or not durability then return end

        content.type = "asteroid"
        if asteroid.asteroidType == "iron" then
            content.title = "IRON ASTEROID"
        elseif asteroid.asteroidType == "stone" then
            content.title = "STONE ASTEROID"
        else
            content.title = "ASTEROID"
        end

        content.ratio, content.percent = computeRatioAndPercent(durability.current, durability.max)
        content.percentText = string.format("%d%%", content.percent)
        content.barLabel = "DURABILITY"
        content.fillColor = PlasmaTheme.colors.asteroidBarFill
        content.barBackground = PlasmaTheme.colors.asteroidBarBg

        popupHeight = popupHeight + sectionGap + smallFont:getHeight() + barLabelGap + barHeight
        popupHeight = math.max(popupHeight, Scaling.scaleSize(96))

    elseif TargetHUD.hoveredWreckage then
        local wreck = ECS.getComponent(TargetHUD.hoveredWreckage, "Wreckage")
        local durability = ECS.getComponent(TargetHUD.hoveredWreckage, "Durability")
        if not wreck or not durability then return end

        content.type = "wreckage"

        local displayName = "WRECKAGE"
        if wreck.sourceShip then
            local design = ShipLoader.getDesign(wreck.sourceShip)
            if design and design.name then
                displayName = string.format("%s WRECKAGE", design.name)
            else
                displayName = string.format("%s WRECKAGE", wreck.sourceShip)
            end
        end
        content.title = string.upper(displayName)

        content.ratio, content.percent = computeRatioAndPercent(durability.current, durability.max)
        content.percentText = string.format("%d%%", content.percent)
        content.barLabel = "SALVAGE INTEGRITY"
        content.fillColor = PlasmaTheme.colors.wreckageBarFill
        content.barBackground = PlasmaTheme.colors.wreckageBarBg

        popupHeight = popupHeight + sectionGap + smallFont:getHeight() + barLabelGap + barHeight
        popupHeight = math.max(popupHeight, Scaling.scaleSize(100))

    elseif TargetHUD.hoveredEnemy then
        local controllers = ECS.getEntitiesWith({"InputControlled", "Player"})
        local inputComp = (#controllers > 0) and ECS.getComponent(controllers[1], "InputControlled")
        local isTargeted = inputComp and inputComp.targetedEnemy == TargetHUD.hoveredEnemy

        if isTargeted then
            content.type = "enemy-targeted"

            local wreck = ECS.getComponent(TargetHUD.hoveredEnemy, "Wreckage")
            local name = "ENEMY"
            if wreck and wreck.sourceShip then
                local design = ShipLoader.getDesign(wreck.sourceShip)
                if design and design.name then
                    name = string.upper(design.name)
                else
                    name = string.upper(wreck.sourceShip)
                end
            end
            content.title = name

            local levelComp = ECS.getComponent(TargetHUD.hoveredEnemy, "Level")
            content.levelText = levelComp and string.format("Lv %d", levelComp.level) or ""

            local bars = {}
            local hull = ECS.getComponent(TargetHUD.hoveredEnemy, "Hull")
            if hull and hull.max and hull.max > 0 then
                local ratio, percent = computeRatioAndPercent(hull.current, hull.max)
                table.insert(bars, {
                    label = "HULL",
                    ratio = ratio,
                    percentText = string.format("%d%%", percent),
                    fillColor = PlasmaTheme.colors.healthBarFill,
                    bgColor = PlasmaTheme.colors.healthBarBg
                })
            end

            local shield = ECS.getComponent(TargetHUD.hoveredEnemy, "Shield")
            if shield and shield.max and shield.max > 0 then
                local ratio, percent = computeRatioAndPercent(shield.current, shield.max)
                table.insert(bars, {
                    label = "SHIELD",
                    ratio = ratio,
                    percentText = string.format("%d%%", percent),
                    fillColor = PlasmaTheme.colors.shieldBarFill,
                    bgColor = PlasmaTheme.colors.healthBarBg
                })
            end

            content.bars = bars

            if #bars > 0 then
                local barBlockHeight = 0
                for i = 1, #bars do
                    barBlockHeight = barBlockHeight + smallFont:getHeight() + barLabelGap + barHeight
                    if i < #bars then
                        barBlockHeight = barBlockHeight + barSpacing
                    end
                end
                popupHeight = popupHeight + sectionGap + barBlockHeight
            else
                popupHeight = popupHeight + sectionGap + normalFont:getHeight()
            end

            popupHeight = math.max(popupHeight, Scaling.scaleSize(112))

        else
            content.type = "enemy-scan"
            local message = "Ctrl+Click to scan"
            if inputComp and inputComp.targetingTarget == TargetHUD.hoveredEnemy then
                local progress = math.floor((inputComp.targetingProgress or 0) * 100)
                message = string.format("Scanning... %d%%  (Ctrl+Click to cancel)", progress)
            end
            content.message = message

            popupHeight = accentHeight + padTop + padBottom + normalFont:getHeight()
            popupHeight = math.max(popupHeight, Scaling.scaleSize(72))
        end
    end

    -- Draw panel
    queuePanelChrome(x, y, popupWidth, popupHeight, accentHeight, cornerRadius)

    -- Content baseline
    local cursorY = y + accentHeight + padTop
    local textX = x + padX
    local contentWidth = popupWidth - padX * 2

    if content.type == "item" then
        BatchRenderer.queueText(content.title, textX, cursorY, titleFont, textPrimary[1], textPrimary[2], textPrimary[3], 1)

        if content.metaText then
            cursorY = cursorY + titleFont:getHeight() + lineGap
            BatchRenderer.queueText(content.metaText, textX, cursorY, smallFont, textSecondary[1], textSecondary[2], textSecondary[3], 1)
        end

    elseif content.type == "asteroid" or content.type == "wreckage" then
        local percentWidth = titleFont:getWidth(content.percentText)
        BatchRenderer.queueText(content.title, textX, cursorY, titleFont, textPrimary[1], textPrimary[2], textPrimary[3], 1)
        BatchRenderer.queueText(
            content.percentText,
            x + popupWidth - padX - percentWidth,
            cursorY,
            titleFont,
            textSecondary[1], textSecondary[2], textSecondary[3], 1
        )

        cursorY = cursorY + titleFont:getHeight() + sectionGap
        BatchRenderer.queueText(content.barLabel, textX, cursorY, smallFont, accentColor[1], accentColor[2], accentColor[3], 1)

        cursorY = cursorY + smallFont:getHeight() + barLabelGap
        queueProgressBar(
            textX,
            cursorY,
            contentWidth,
            barHeight,
            content.ratio,
            content.fillColor,
            content.barBackground,
            Theme.colors.borderLight
        )

    elseif content.type == "enemy-targeted" then
        BatchRenderer.queueText(content.title, textX, cursorY, titleFont, textPrimary[1], textPrimary[2], textPrimary[3], 1)

        if content.levelText and content.levelText ~= "" then
            local levelWidth = smallFont:getWidth(content.levelText)
            local levelY = cursorY + titleFont:getHeight() - smallFont:getHeight()
            BatchRenderer.queueText(
                content.levelText,
                x + popupWidth - padX - levelWidth,
                levelY,
                smallFont,
                textSecondary[1], textSecondary[2], textSecondary[3], 1
            )
        end

        cursorY = cursorY + titleFont:getHeight() + sectionGap

        if content.bars and #content.bars > 0 then
            for index, bar in ipairs(content.bars) do
                BatchRenderer.queueText(bar.label, textX, cursorY, smallFont, accentColor[1], accentColor[2], accentColor[3], 1)

                local percentWidth = smallFont:getWidth(bar.percentText)
                BatchRenderer.queueText(
                    bar.percentText,
                    x + popupWidth - padX - percentWidth,
                    cursorY,
                    smallFont,
                    textSecondary[1], textSecondary[2], textSecondary[3], 1
                )

                cursorY = cursorY + smallFont:getHeight() + barLabelGap
                queueProgressBar(
                    textX,
                    cursorY,
                    contentWidth,
                    barHeight,
                    bar.ratio,
                    bar.fillColor,
                    bar.bgColor,
                    Theme.colors.borderLight
                )

                cursorY = cursorY + barHeight
                if index < #content.bars then
                    cursorY = cursorY + barSpacing
                end
            end
        else
            BatchRenderer.queueText("No telemetry", textX, cursorY, normalFont, textSecondary[1], textSecondary[2], textSecondary[3], 1)
        end

    elseif content.type == "enemy-scan" then
        BatchRenderer.queueText(content.message, textX, cursorY, normalFont, accentColor[1], accentColor[2], accentColor[3], 1)
    end
end

return TargetHUD
