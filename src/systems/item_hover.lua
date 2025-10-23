---@diagnostic disable: undefined-global
-- Item Hover System - Shows hover indicators and popups for items in space

local ECS = require('src.ecs')
local Theme = require('src.ui.theme')
local Scaling = require('src.scaling')
local PlasmaTheme = require('src.ui.plasma_theme')

local ItemHover = {
    hoveredItem = nil,
    hoveredEnemy = nil,
    hoveredAsteroid = nil,
    hoverRadius = 30,  -- World units
}

-- Update hover detection
function ItemHover.update()
    local mouseX, mouseY = love.mouse.getPosition()
    
    -- Convert screen coordinates to world coordinates
    local cameraEntities = ECS.getEntitiesWith({"Camera", "Position"})
    if #cameraEntities == 0 then
        ItemHover.hoveredItem = nil
        ItemHover.hoveredEnemy = nil
        ItemHover.hoveredAsteroid = nil
        return
    end
    
    local cameraComp = ECS.getComponent(cameraEntities[1], "Camera")
    local cameraPos = ECS.getComponent(cameraEntities[1], "Position")
    if not cameraComp or not cameraPos then
        ItemHover.hoveredItem = nil
        ItemHover.hoveredEnemy = nil
        ItemHover.hoveredAsteroid = nil
        return
    end
    
    local worldX, worldY = Scaling.toWorld(mouseX, mouseY, cameraComp, cameraPos)
    
    -- Find closest item
    local items = ECS.getEntitiesWith({"Item", "Position"})
    local closestItem = nil
    local closestItemDist = math.huge
    
    for _, itemId in ipairs(items) do
        local position = ECS.getComponent(itemId, "Position")
        if position then
            local dx = worldX - position.x
            local dy = worldY - position.y
            local dist = math.sqrt(dx * dx + dy * dy)
            
            if dist < ItemHover.hoverRadius and dist < closestItemDist then
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
        ItemHover.hoveredItem = closestItem
        ItemHover.hoveredEnemy = nil
        ItemHover.hoveredAsteroid = nil
    elseif closestAsteroid then
        ItemHover.hoveredItem = nil
        ItemHover.hoveredEnemy = nil
        ItemHover.hoveredAsteroid = closestAsteroid
    elseif closestEnemy then
        ItemHover.hoveredItem = nil
        ItemHover.hoveredEnemy = closestEnemy
        ItemHover.hoveredAsteroid = nil
    else
        ItemHover.hoveredItem = nil
        ItemHover.hoveredEnemy = nil
        ItemHover.hoveredAsteroid = nil
    end
end

-- Draw hover indicator (circle around item/enemy/asteroid - in world space)
function ItemHover.drawWorldIndicator()
    -- Use cyan color for all hover indicators
    local cyanColor = PlasmaTheme.colors.shieldBarFill
    
    -- Draw indicator for hovered item
    if ItemHover.hoveredItem then
        local position = ECS.getComponent(ItemHover.hoveredItem, "Position")
        if position then
            -- Draw circle around hovered item
            love.graphics.setColor(cyanColor[1], cyanColor[2], cyanColor[3], 0.6)
            love.graphics.setLineWidth(2)
            love.graphics.circle("line", position.x, position.y, 20)
            love.graphics.setLineWidth(1)
        end
    end
    
    -- Draw indicator for hovered asteroid
    if ItemHover.hoveredAsteroid then
        local position = ECS.getComponent(ItemHover.hoveredAsteroid, "Position")
        local collidable = ECS.getComponent(ItemHover.hoveredAsteroid, "Collidable")
        if position and collidable then
            -- Draw circle around hovered asteroid
            love.graphics.setColor(cyanColor[1], cyanColor[2], cyanColor[3], 0.6)
            love.graphics.setLineWidth(2)
            love.graphics.circle("line", position.x, position.y, collidable.radius or 30)
            love.graphics.setLineWidth(1)
        end
    end
    
    -- Draw indicator for hovered enemy
    if ItemHover.hoveredEnemy then
        local position = ECS.getComponent(ItemHover.hoveredEnemy, "Position")
        local collidable = ECS.getComponent(ItemHover.hoveredEnemy, "Collidable")
        if position and collidable then
            -- Draw circle around hovered enemy
            love.graphics.setColor(cyanColor[1], cyanColor[2], cyanColor[3], 0.6)
            love.graphics.setLineWidth(2)
            love.graphics.circle("line", position.x, position.y, collidable.radius or 30)
            love.graphics.setLineWidth(1)
        end
    end
end

-- Draw popup (in screen space, same style/position as skill notifications)
function ItemHover.drawPopup()
    -- Only show popup if hovering an item, asteroid, or enemy
    if not ItemHover.hoveredItem and not ItemHover.hoveredEnemy and not ItemHover.hoveredAsteroid then return end
    
    -- Same positioning as skill notifications
    local screenW = love.graphics.getWidth()
    local popupWidth = Scaling.scaleSize(400)
    local popupHeight = Scaling.scaleSize(ItemHover.hoveredAsteroid and 72 or 44) -- Taller for asteroids to show durability bar
    
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
    if ItemHover.hoveredItem then
        local item = ECS.getComponent(ItemHover.hoveredItem, "Item")
        if item and item.def then
            -- Draw item icon (miniature version)
            love.graphics.push()
            love.graphics.translate(x + Scaling.scaleSize(24), y + popupHeight / 2)
            love.graphics.scale(0.6, 0.6)
            item.def:draw(0, 0)
            love.graphics.pop()
            
            -- Draw item name
            love.graphics.setFont(normalFont)
            love.graphics.setColor(Theme.colors.textPrimary[1], Theme.colors.textPrimary[2], Theme.colors.textPrimary[3], 1)
            love.graphics.print(string.upper(item.def.name), x + Scaling.scaleX(56), y + Scaling.scaleY(14))
        end
    -- Handle asteroid popup
    elseif ItemHover.hoveredAsteroid then
        local asteroid = ECS.getComponent(ItemHover.hoveredAsteroid, "Asteroid")
        local durability = ECS.getComponent(ItemHover.hoveredAsteroid, "Durability")
        
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
            
            -- Draw asteroid icon (colored circle)
            love.graphics.setColor(iconColor)
            love.graphics.circle("fill", x + Scaling.scaleSize(24), y + Scaling.scaleSize(14), Scaling.scaleSize(8))
            
            -- Draw asteroid type name
            love.graphics.setFont(normalFont)
            love.graphics.setColor(Theme.colors.textPrimary[1], Theme.colors.textPrimary[2], Theme.colors.textPrimary[3], 1)
            love.graphics.print(asteroidTypeName, x + Scaling.scaleX(48), y + Scaling.scaleY(14))
            
            -- Draw durability bar using PlasmaTheme style
            local barWidth = popupWidth - Scaling.scaleX(96)
            local barHeight = Scaling.scaleSize(8)
            local barX = x + Scaling.scaleX(48)
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
    elseif ItemHover.hoveredEnemy then
        -- Check targeting state
        local controllers = ECS.getEntitiesWith({"InputControlled", "Player"})
        local message = "Ctrl+Click to scan"
        local iconColor = {1, 0.3, 0.1, 1}
        
        if #controllers > 0 then
            local inputComp = ECS.getComponent(controllers[1], "InputControlled")
            if inputComp then
                if inputComp.targetingTarget == ItemHover.hoveredEnemy then
                    -- Currently scanning this enemy
                    local progress = math.floor((inputComp.targetingProgress or 0) * 100)
                    message = string.format("Scanning... %d%% (Ctrl+Click to cancel)", progress)
                    iconColor = {0.7, 0.8, 1, 1} -- Blue for scanning
                elseif inputComp.targetedEnemy == ItemHover.hoveredEnemy then
                    -- Already targeted this enemy
                    message = "Target locked. Ctrl+Click to release"
                    iconColor = {0.2, 1, 0.2, 1} -- Green for locked
                end
            end
        end
        
        -- Draw enemy icon placeholder
        love.graphics.setColor(iconColor)
        love.graphics.circle("fill", x + Scaling.scaleSize(24), y + popupHeight / 2, Scaling.scaleSize(8))
        
        -- Draw message
        love.graphics.setFont(normalFont)
        love.graphics.setColor(Theme.colors.textPrimary[1], Theme.colors.textPrimary[2], Theme.colors.textPrimary[3], 1)
        love.graphics.print(message, x + Scaling.scaleX(48), y + Scaling.scaleY(14))
    end
end

return ItemHover

