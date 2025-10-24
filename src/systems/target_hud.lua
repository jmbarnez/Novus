---@diagnostic disable: undefined-global
-- Target HUD System - Shows hover indicators and popups for targets in space

local ECS = require('src.ecs')
local Theme = require('src.ui.theme')
local Scaling = require('src.scaling')
local PlasmaTheme = require('src.ui.plasma_theme')

local TargetHUD = {
    hoveredItem = nil,
    hoveredEnemy = nil,
    hoveredAsteroid = nil,
    hoverRadius = 30,  -- World units
}

-- Update hover detection
function TargetHUD.update()
    local mouseX, mouseY = love.mouse.getPosition()
    
    -- Convert screen coordinates to world coordinates
    local cameraEntities = ECS.getEntitiesWith({"Camera", "Position"})
    if #cameraEntities == 0 then
        TargetHUD.hoveredItem = nil
        TargetHUD.hoveredEnemy = nil
        TargetHUD.hoveredAsteroid = nil
        return
    end
    
    local cameraComp = ECS.getComponent(cameraEntities[1], "Camera")
    local cameraPos = ECS.getComponent(cameraEntities[1], "Position")
    if not cameraComp or not cameraPos then
        TargetHUD.hoveredItem = nil
        TargetHUD.hoveredEnemy = nil
        TargetHUD.hoveredAsteroid = nil
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
    
    -- Prioritize items > asteroids > enemies if multiple are hovered
    if closestItem then
        TargetHUD.hoveredItem = closestItem
        TargetHUD.hoveredEnemy = nil
        TargetHUD.hoveredAsteroid = nil
    elseif closestAsteroid then
        TargetHUD.hoveredItem = nil
        TargetHUD.hoveredEnemy = nil
        TargetHUD.hoveredAsteroid = closestAsteroid
    elseif closestEnemy then
        TargetHUD.hoveredItem = nil
        TargetHUD.hoveredEnemy = closestEnemy
        TargetHUD.hoveredAsteroid = nil
    else
        TargetHUD.hoveredItem = nil
        TargetHUD.hoveredEnemy = nil
        TargetHUD.hoveredAsteroid = nil
    end
end

-- Draw hover indicator (circle around item/enemy/asteroid - in world space)
function TargetHUD.drawWorldIndicator()
    -- Use plasma cyan color for all hover indicators (consistent with theme)
    local cyanColor = Theme.colors.borderNeon
    
    -- Draw indicator for hovered item
    if TargetHUD.hoveredItem then
        local position = ECS.getComponent(TargetHUD.hoveredItem, "Position")
        local collidable = ECS.getComponent(TargetHUD.hoveredItem, "Collidable")
        local polygonShape = ECS.getComponent(TargetHUD.hoveredItem, "PolygonShape")
        if position then
            love.graphics.setColor(cyanColor[1], cyanColor[2], cyanColor[3], 0.6)
            love.graphics.setLineWidth(2)
            if polygonShape and polygonShape.vertices then
                -- Polygonal highlight
                local flatVertices = {}
                for i = 1, #polygonShape.vertices do
                    local v = polygonShape.vertices[i]
                    table.insert(flatVertices, v.x)
                    table.insert(flatVertices, v.y)
                end
                local rotation = polygonShape.rotation or 0
                love.graphics.push()
                love.graphics.translate(position.x, position.y)
                love.graphics.rotate(rotation)
                love.graphics.polygon("line", flatVertices)
                love.graphics.pop()
            else
                -- Fallback: circle
                love.graphics.circle("line", position.x, position.y, (collidable and collidable.radius) or 20)
            end
            love.graphics.setLineWidth(1)
        end
    end
    
    -- Draw indicator for hovered asteroid
    if TargetHUD.hoveredAsteroid then
        local position = ECS.getComponent(TargetHUD.hoveredAsteroid, "Position")
        local collidable = ECS.getComponent(TargetHUD.hoveredAsteroid, "Collidable")
        local polygonShape = ECS.getComponent(TargetHUD.hoveredAsteroid, "PolygonShape")
        
        if position then
            love.graphics.setColor(cyanColor[1], cyanColor[2], cyanColor[3], 0.6)
            love.graphics.setLineWidth(2)
            
            if polygonShape and polygonShape.vertices then
                -- Draw perfect outline using polygon vertices
                -- Flatten vertices table into array of numbers
                local flatVertices = {}
                for i = 1, #polygonShape.vertices do
                    local v = polygonShape.vertices[i]
                    table.insert(flatVertices, v.x)
                    table.insert(flatVertices, v.y)
                end
                
                local rotation = polygonShape.rotation or 0
                love.graphics.push()
                love.graphics.translate(position.x, position.y)
                love.graphics.rotate(rotation)
                love.graphics.polygon("line", flatVertices)
                love.graphics.pop()
            elseif collidable then
                -- Fallback to circle
                love.graphics.circle("line", position.x, position.y, collidable.radius or 30)
            end
            
            love.graphics.setLineWidth(1)
        end
    end
    
    -- Draw indicator for hovered enemy
    if TargetHUD.hoveredEnemy then
        local position = ECS.getComponent(TargetHUD.hoveredEnemy, "Position")
        local collidable = ECS.getComponent(TargetHUD.hoveredEnemy, "Collidable")
        local polygonShape = ECS.getComponent(TargetHUD.hoveredEnemy, "PolygonShape")
        
        if position then
            love.graphics.setColor(cyanColor[1], cyanColor[2], cyanColor[3], 0.6)
            love.graphics.setLineWidth(2)
            
            if polygonShape and polygonShape.vertices then
                -- Draw perfect outline using polygon vertices
                -- Flatten vertices table into array of numbers
                local flatVertices = {}
                for i = 1, #polygonShape.vertices do
                    local v = polygonShape.vertices[i]
                    table.insert(flatVertices, v.x)
                    table.insert(flatVertices, v.y)
                end
                
                local rotation = polygonShape.rotation or 0
                love.graphics.push()
                love.graphics.translate(position.x, position.y)
                love.graphics.rotate(rotation)
                love.graphics.polygon("line", flatVertices)
                love.graphics.pop()
            elseif collidable then
                -- Fallback to circle
                love.graphics.circle("line", position.x, position.y, collidable.radius or 30)
            end
            
            love.graphics.setLineWidth(1)
        end
    end
end

-- Draw popup (in screen space, same style/position as skill notifications)
function TargetHUD.drawPopup()
    -- Only show popup if hovering an item, asteroid, or enemy
    if not TargetHUD.hoveredItem and not TargetHUD.hoveredEnemy and not TargetHUD.hoveredAsteroid then return end
    
    -- Same positioning as skill notifications
    local screenW = love.graphics.getWidth()
    local popupWidth = Scaling.scaleSize(400)
    
    -- Determine popup height based on type
    local popupHeight = Scaling.scaleSize(44) -- Default height
    if TargetHUD.hoveredAsteroid then
        popupHeight = Scaling.scaleSize(72) -- Taller for asteroids to show durability bar
    elseif TargetHUD.hoveredEnemy then
        -- Check if enemy is targeted (will show more info)
        local controllers = ECS.getEntitiesWith({"InputControlled", "Player"})
        local inputComp = (#controllers > 0) and ECS.getComponent(controllers[1], "InputControlled")
        local isTargeted = inputComp and inputComp.targetedEnemy == TargetHUD.hoveredEnemy
        if isTargeted then
            popupHeight = Scaling.scaleSize(70) -- Taller for targeted enemies to show health bar and stats
        end
    end
    
    -- Calculate starting Y position - below any skill notifications
    local startY = Scaling.scaleY(18)
    local y = startY
    
    -- Stack below skill notifications if any are showing -- REMOVE THIS SKILL STACKING LOGIC --
    
    local x = (screenW - popupWidth) / 2
    
    -- Set fonts
    local normalFont = Theme.getFont(Scaling.scaleSize(Theme.fonts.normal))
    
    -- Draw popup background (same style as skill notifications)
    love.graphics.setColor(Theme.colors.bgDark[1], Theme.colors.bgDark[2], Theme.colors.bgDark[3], 0.92)
    love.graphics.rectangle("fill", x, y, popupWidth, popupHeight, Scaling.scaleSize(8), Scaling.scaleSize(8))
    
    -- Draw popup border
    love.graphics.setColor(Theme.colors.borderLight[1], Theme.colors.borderLight[2], Theme.colors.borderLight[3], 1)
    love.graphics.setLineWidth(1)
    love.graphics.rectangle("line", x, y, popupWidth, popupHeight, Scaling.scaleSize(8), Scaling.scaleSize(8))
    
    -- Handle item popup
    if TargetHUD.hoveredItem then
        local item = ECS.getComponent(TargetHUD.hoveredItem, "Item")
        if item and item.def then
            -- Draw item icon (miniature version) - keep icon for items only
            love.graphics.push()
            love.graphics.translate(x + Scaling.scaleSize(24), y + popupHeight / 2)
            love.graphics.scale(0.6, 0.6)
            item.def:draw(0, 0)
            love.graphics.pop()
            
            -- Draw item name
            love.graphics.setFont(normalFont)
            love.graphics.setColor(Theme.colors.textPrimary[1], Theme.colors.textPrimary[2], Theme.colors.textPrimary[3], 1)
            love.graphics.print(string.upper(item.def.name), x + Scaling.scaleX(48), y + Scaling.scaleY(14))
        end
    -- Handle asteroid popup
    elseif TargetHUD.hoveredAsteroid then
        local asteroid = ECS.getComponent(TargetHUD.hoveredAsteroid, "Asteroid")
        local durability = ECS.getComponent(TargetHUD.hoveredAsteroid, "Durability")
        
        if asteroid and durability then
            -- Determine asteroid type name
            local asteroidTypeName = "ASTEROID"
            local iconColor = {0.7, 0.7, 0.5, 1}
            if asteroid.asteroidType == "iron" then
                asteroidTypeName = "IRON ASTEROID"
                iconColor = {0.8, 0.5, 0.2, 1}
            elseif asteroid.asteroidType == "stone" then
                asteroidTypeName = "STONE ASTEROID"
                iconColor = {0.6, 0.6, 0.6, 1}
            end
            
            -- Draw asteroid type name (no icon, just text)
            love.graphics.setFont(normalFont)
            love.graphics.setColor(Theme.colors.textPrimary[1], Theme.colors.textPrimary[2], Theme.colors.textPrimary[3], 1)
            love.graphics.print(asteroidTypeName, x + Scaling.scaleX(14), y + Scaling.scaleY(14))
            
            -- Draw durability bar using PlasmaTheme style
            local barWidth = popupWidth - Scaling.scaleX(28)
            local barHeight = Scaling.scaleSize(8)
            local barX = x + Scaling.scaleX(14)
            local barY = y + Scaling.scaleY(32)
            local durabilityPercent = math.min(durability.current / durability.max, 1.0)
            
            -- Use PlasmaTheme.drawDurabilityBar for consistent ship info style
            PlasmaTheme.drawDurabilityBar(barX, barY, barWidth, barHeight, durabilityPercent, "asteroid")
            
            -- Durability text
            local smallFont = Theme.getFont(Scaling.scaleSize(Theme.fonts.small))
            love.graphics.setFont(smallFont)
            love.graphics.setColor(Theme.colors.textSecondary[1], Theme.colors.textSecondary[2], Theme.colors.textSecondary[3], 1)
            local durabilityText = string.format("%.0f / %.0f", durability.current, durability.max)
            love.graphics.print(durabilityText, barX + barWidth - smallFont:getWidth(durabilityText), barY - Scaling.scaleSize(14))
        end
    -- Handle enemy popup
    elseif TargetHUD.hoveredEnemy then
        local controllers = ECS.getEntitiesWith({"InputControlled", "Player"})
        local inputComp = (#controllers > 0) and ECS.getComponent(controllers[1], "InputControlled")
        local isTargeted = inputComp and inputComp.targetedEnemy == TargetHUD.hoveredEnemy
        
        if isTargeted then
            -- Show detailed info for targeted enemy
            local targetHull = ECS.getComponent(TargetHUD.hoveredEnemy, "Hull")
            local targetShield = ECS.getComponent(TargetHUD.hoveredEnemy, "Shield")
            local targetPos = ECS.getComponent(TargetHUD.hoveredEnemy, "Position")
            local targetVelocity = ECS.getComponent(TargetHUD.hoveredEnemy, "Velocity")
            local playerEntity = inputComp.targetEntity
            local playerPos = playerEntity and ECS.getComponent(playerEntity, "Position")
            
            local hullVal = targetHull and targetHull.current or 0
            local hullMax = targetHull and targetHull.max or 1
            local shieldVal = (targetShield and targetShield.current) or 0
            local shieldMax = (targetShield and targetShield.max) or 0
            
            -- Draw combined hull/shield bar
            local barWidth = popupWidth - Scaling.scaleX(28)
            local barHeight = Scaling.scaleSize(20)
            local barX = x + Scaling.scaleX(14)
            local barY = y + Scaling.scaleY(6)
            
            local hullRatio = math.min(hullVal / hullMax, 1.0)
            PlasmaTheme.drawHealthBar(barX, barY, barWidth, barHeight, hullRatio, false)
            
            if shieldMax > 0 and shieldVal > 0 then
                local sRatio = math.min(shieldVal / shieldMax, 1.0)
                PlasmaTheme.drawHealthBar(barX, barY, barWidth, barHeight, sRatio, true)
            end
            
            -- Draw bar text overlay
            local smallFont = Theme.getFont(Scaling.scaleSize(Theme.fonts.small))
            love.graphics.setFont(smallFont)
            local barText
            if shieldMax > 0 then
                barText = string.format("Hull %d/%d   Shield %d/%d", hullVal, hullMax, shieldVal, shieldMax)
            else
                barText = string.format("Hull %d/%d", hullVal, hullMax)
            end
            local barTextW = smallFont:getWidth(barText)
            local barTextX = barX + (barWidth - barTextW) / 2
            local barTextY = barY + (barHeight - smallFont:getHeight()) / 2
            love.graphics.setColor(Theme.colors.textPrimary[1], Theme.colors.textPrimary[2], Theme.colors.textPrimary[3], 1)
            love.graphics.print(barText, barTextX, barTextY)
            
            -- Draw distance and speed
            love.graphics.setFont(smallFont)
            love.graphics.setColor(Theme.colors.textSecondary[1], Theme.colors.textSecondary[2], Theme.colors.textSecondary[3], 1)
            
            local infoRow = y + Scaling.scaleY(32)
            if playerPos and targetPos then
                local dx, dy = targetPos.x - playerPos.x, targetPos.y - playerPos.y
                local distance = math.sqrt(dx*dx+dy*dy)
                love.graphics.print(string.format("Distance: %.0f u", distance), x + Scaling.scaleX(14), infoRow)
            end
            
            if targetVelocity then
                local speed = math.sqrt((targetVelocity.vx or 0)^2 + (targetVelocity.vy or 0)^2)
                love.graphics.print(string.format("Speed: %.0f u/s", speed), x + Scaling.scaleX(180), infoRow)
            end
        else
            -- Show simple message for untargeted enemies
            local message = "Ctrl+Click to scan"
            if inputComp and inputComp.targetingTarget == TargetHUD.hoveredEnemy then
                local progress = math.floor((inputComp.targetingProgress or 0) * 100)
                message = string.format("Scanning... %d%% (Ctrl+Click to cancel)", progress)
            end
            
            love.graphics.setFont(normalFont)
            love.graphics.setColor(Theme.colors.textPrimary[1], Theme.colors.textPrimary[2], Theme.colors.textPrimary[3], 1)
            love.graphics.print(message, x + Scaling.scaleX(14), y + Scaling.scaleY(14))
        end
    end
end

return TargetHUD

