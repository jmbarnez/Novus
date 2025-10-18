-- UI Cargo Window Module - Handles cargo inventory display and interaction
-- Derives from WindowBase for universal effects (neon border, fade, elasticity)

local ECS = require('src.ecs')
local Components = require('src.components')
local Theme = require('src.ui.theme')
local WindowBase = require('src.ui.window_base')

-- Create cargo window instance inheriting from WindowBase
local CargoWindow = WindowBase:new{
    width = 650,
    height = 500,
    isOpen = false,
    animAlphaSpeed = 2.5,
    elasticitySpring = 18,
    elasticityDamping = 0.7,
}

-- Public interface for toggling
function CargoWindow:toggle()
    self:setOpen(not self.isOpen)
end

function CargoWindow:getOpen()
    return self.isOpen
end

-- Override draw to add cargo-specific content on top of universal window
function CargoWindow:draw(viewportWidth, viewportHeight)
    -- Check if should be visible
    if not self.isOpen and not self.animAlphaActive then return end
    
    local alpha = self.animAlpha
    if alpha <= 0 then return end
    
    -- Draw universal window frame (border, background)
    local x, y = self.position.x, self.position.y
    local w, h = self.width, self.height
    love.graphics.setColor(1, 1, 1, alpha)
    Theme.draw3DBorder(x, y, w, h)
    -- Integrated top bar: use a subtle gradient or slightly darker fill, no hard border
    local topBarColor = {Theme.colors.bgDark[1]*0.92, Theme.colors.bgDark[2]*0.92, Theme.colors.bgDark[3]*0.92, alpha}
    -- Inset top bar by border thickness to fit inside border
    local border = 3
    love.graphics.setColor(topBarColor)
    love.graphics.rectangle("fill", x+border, y+border, w-2*border, Theme.window.topBarHeight-2*border)
    -- Subtle shadow line below top bar
    love.graphics.setColor(0,0,0,0.10*alpha)
    love.graphics.rectangle("fill", x+border, y+border+Theme.window.topBarHeight-2*border-1, w-2*border, 1)
    
    local cargoEntities = ECS.getEntitiesWith({"Player", "Cargo"})
    if #cargoEntities == 0 then return end
    
    local playerId = cargoEntities[1]
    local cargo = ECS.getComponent(playerId, "Cargo")
    if not cargo then return end
    
    local currency = ECS.getComponent(playerId, "Currency")
    
    -- Draw close button
    self:drawCloseButton(x, y, alpha)
    
    -- Draw bottom bar
    local bottomY = y + h - Theme.window.bottomBarHeight
    local bottomBarColor = Theme.colors.bgMedium
    love.graphics.setColor(bottomBarColor[1], bottomBarColor[2], bottomBarColor[3], alpha)
    love.graphics.rectangle("fill", x, bottomY, w, Theme.window.bottomBarHeight)
    
    -- Draw cargo info
    love.graphics.setColor(Theme.colors.textPrimary[1], Theme.colors.textPrimary[2], Theme.colors.textPrimary[3], alpha)
    love.graphics.setFont(Theme.getFont(Theme.fonts.normal))
    local itemCount = 0
    for _, v in pairs(cargo.items) do itemCount = itemCount + v end
    local capText = string.format("Cargo: %d / %d", itemCount, cargo.capacity or 0)
    love.graphics.print(capText, x + 12, bottomY + 5)
    
    local currencyText = currency and string.format("Credits: %d", currency.amount or 0) or ""
    love.graphics.print(currencyText, x + w - 140, bottomY + 5)
    
    -- Draw items grid
    self:drawItemsGrid(x, y, cargo, alpha)
    
    -- Draw skills panel on the right side
    self:drawSkillsPanel(x, y, cargo, alpha)
    
    -- Draw turret panel on the left side
    self:drawTurretPanel(x, y, cargo, alpha)

    -- Draw dragged item icon at mouse position if dragging
    if self.draggedItem and self.draggedItem.itemDef and self.draggedItem.itemDef.draw then
        local mx, my = love.mouse.getPosition()
        love.graphics.setColor(1, 1, 1, 0.8 * alpha)
        self.draggedItem.itemDef:draw(mx, my)
        love.graphics.setColor(1, 1, 1, 1) -- reset color
    end
end

function CargoWindow:drawSkillsPanel(windowX, windowY, cargo, alpha)
    local panelWidth = 130
    local panelX = windowX + self.width - panelWidth - 3  -- 3 for border
    local panelY = windowY + Theme.window.topBarHeight + 3
    local panelHeight = self.height - Theme.window.topBarHeight - Theme.window.bottomBarHeight - 6
    
    -- Draw skills panel background
    love.graphics.setColor(Theme.colors.bgMedium[1], Theme.colors.bgMedium[2], Theme.colors.bgMedium[3], alpha * 0.9)
    love.graphics.rectangle("fill", panelX, panelY, panelWidth, panelHeight)
    
    -- Draw panel border
    love.graphics.setColor(Theme.colors.borderLight[1], Theme.colors.borderLight[2], Theme.colors.borderLight[3], alpha)
    love.graphics.setLineWidth(1)
    love.graphics.rectangle("line", panelX, panelY, panelWidth, panelHeight)
    
    -- Get player skills
    local cargoEntities = ECS.getEntitiesWith({"Player", "Skills"})
    if #cargoEntities == 0 then return end
    
    local playerId = cargoEntities[1]
    local skills = ECS.getComponent(playerId, "Skills")
    if not skills then return end
    
    -- Draw title
    love.graphics.setColor(Theme.colors.textPrimary[1], Theme.colors.textPrimary[2], Theme.colors.textPrimary[3], alpha)
    love.graphics.setFont(Theme.getFont(Theme.fonts.normal))
    love.graphics.printf("Skills", panelX + 4, panelY + 8, panelWidth - 8, "center")
    
    -- Draw divider line
    love.graphics.setColor(Theme.colors.borderDark[1], Theme.colors.borderDark[2], Theme.colors.borderDark[3], alpha)
    love.graphics.line(panelX + 8, panelY + 28, panelX + panelWidth - 8, panelY + 28)
    
    -- Draw mining skill
    local miningSkill = skills.skills.mining
    if miningSkill then
        local skillY = panelY + 38
        
        -- Skill name
        love.graphics.setColor(Theme.colors.textPrimary[1], Theme.colors.textPrimary[2], Theme.colors.textPrimary[3], alpha)
        love.graphics.setFont(Theme.getFont(Theme.fonts.small))
        love.graphics.print("Mining", panelX + 8, skillY)
        
        -- Skill level
        love.graphics.printf("Lvl " .. miningSkill.level, panelX + 8, skillY + 12, panelWidth - 16, "right")
        
        -- Experience bar background
        local barX = panelX + 8
        local barY = skillY + 28
        local barWidth = panelWidth - 16
        local barHeight = 12
        
        love.graphics.setColor(0.1, 0.1, 0.1, alpha)
        love.graphics.rectangle("fill", barX, barY, barWidth, barHeight)
        
        -- Experience bar border
        love.graphics.setColor(Theme.colors.borderMedium[1], Theme.colors.borderMedium[2], Theme.colors.borderMedium[3], alpha)
        love.graphics.rectangle("line", barX, barY, barWidth, barHeight)
        
        -- Experience bar fill (gradient blue-cyan)
        local xpRatio = miningSkill.experience / miningSkill.requiredXp
        local fillWidth = math.max(0, math.min(barWidth - 2, (barWidth - 2) * xpRatio))
        love.graphics.setColor(0.2, 0.6, 1.0, alpha)
        love.graphics.rectangle("fill", barX + 1, barY + 1, fillWidth, barHeight - 2)
    end
end

function CargoWindow:drawTurretPanel(windowX, windowY, cargo, alpha)
    local panelWidth = 130
    local panelX = windowX + 3
    local panelY = windowY + Theme.window.topBarHeight + 3
    local panelHeight = self.height - Theme.window.topBarHeight - Theme.window.bottomBarHeight - 6

    love.graphics.setColor(Theme.colors.bgMedium[1], Theme.colors.bgMedium[2], Theme.colors.bgMedium[3], alpha * 0.9)
    love.graphics.rectangle("fill", panelX, panelY, panelWidth, panelHeight)
    love.graphics.setColor(Theme.colors.borderLight[1], Theme.colors.borderLight[2], Theme.colors.borderLight[3], alpha)
    love.graphics.setLineWidth(1)
    love.graphics.rectangle("line", panelX, panelY, panelWidth, panelHeight)

    -- Find pilot and their controlled drone's turret slots
    local pilotEntities = ECS.getEntitiesWith({"Player", "InputControlled"})
    if #pilotEntities == 0 then return end
    local pilotId = pilotEntities[1]
    local input = ECS.getComponent(pilotId, "InputControlled")
    if not input or not input.targetEntity then return end
    local droneId = input.targetEntity
    local turretSlots = ECS.getComponent(droneId, "TurretSlots")
    if not turretSlots then return end

    love.graphics.setColor(Theme.colors.textPrimary[1], Theme.colors.textPrimary[2], Theme.colors.textPrimary[3], alpha)
    love.graphics.setFont(Theme.getFont(Theme.fonts.normal))
    love.graphics.printf("Turret Slot", panelX + 4, panelY + 8, panelWidth - 8, "center")
    love.graphics.setColor(Theme.colors.borderDark[1], Theme.colors.borderDark[2], Theme.colors.borderDark[3], alpha)
    love.graphics.line(panelX + 8, panelY + 28, panelX + panelWidth - 8, panelY + 28)

    -- Equipment slot for turret modules (drag and drop)
    local slotSize = Theme.spacing.iconSize  -- Use same size as cargo slots (48x48)
    local slotX = panelX + (panelWidth - slotSize) / 2  -- Center horizontally
    local slotY = panelY + 38
    local slotWidth = slotSize
    local slotHeight = slotSize
    
    -- Store slot rect for drag-drop handling
    if not self.turretSlotRect then self.turretSlotRect = {} end
    self.turretSlotRect = {x = slotX, y = slotY, w = slotWidth, h = slotHeight}
    
    -- Check if dragging a turret item over this slot
    local isDragOverSlot = false
    local mx, my = love.mouse.getPosition()
    if self.draggedItem and string.match(self.draggedItem.itemId, "turret") then
        if mx >= slotX and mx <= slotX + slotWidth and my >= slotY and my <= slotY + slotHeight then
            isDragOverSlot = true
        end
    end
    
    -- Check if hovering for tooltip
    local isHoveringSlot = mx >= slotX and mx <= slotX + slotWidth and my >= slotY and my <= slotY + slotHeight
    if isHoveringSlot and turretSlots.slots[1] then
        local ItemDefs = require('src.items.item_loader')
        self.hoveredTurretSlot = {
            itemId = turretSlots.slots[1],
            itemDef = ItemDefs[turretSlots.slots[1]],
            count = 1,
            mouseX = mx,
            mouseY = my
        }
    else
        self.hoveredTurretSlot = nil
    end
    
    -- Draw slot background
    love.graphics.setColor(0.1, 0.1, 0.15, alpha * 0.95)
    love.graphics.rectangle("fill", slotX, slotY, slotWidth, slotHeight, 8, 8)
    
    -- Draw slot border (highlight if dragging over)
    local borderColor = isDragOverSlot and {0.4, 1, 0.4, 1} or (turretSlots.slots[1] and {0.2, 0.8, 1.0, 1} or {0.5, 0.5, 0.5, 1})
    love.graphics.setColor(borderColor[1], borderColor[2], borderColor[3], alpha)
    love.graphics.setLineWidth(isDragOverSlot and 3 or 2)
    love.graphics.rectangle("line", slotX, slotY, slotWidth, slotHeight, 8, 8)
    love.graphics.setLineWidth(1)
    
    -- Draw equipped module icon or placeholder
    if turretSlots.slots[1] then
        local ItemDefs = require('src.items.item_loader')
        local itemDef = ItemDefs[turretSlots.slots[1]]
        if itemDef and itemDef.draw then
            -- Draw the item icon in the center of the slot
            itemDef:draw(slotX + slotWidth / 2, slotY + slotHeight / 2)
        else
            -- Fallback: draw a circle if no draw method
            love.graphics.setColor(0.5, 0.5, 0.8, alpha)
            love.graphics.circle("fill", slotX + slotWidth / 2, slotY + slotHeight / 2, 20)
        end
    end
end

function CargoWindow:drawCloseButton(x, y, alpha)
    local border = 3
    local closeSize = 18
    local closeX = x + self.width - closeSize - 8 - border
    local closeY = y + border + (Theme.window.topBarHeight - 2*border - closeSize) / 2
    local mx, my = love.mouse.getPosition()
    local closeHover = mx >= closeX and mx <= closeX + closeSize and my >= closeY and my <= closeY + closeSize
    -- Minimal X: black by default, red on hover, no background
    local xColor = closeHover and {1,0.15,0.15,alpha} or {0,0,0,alpha}
    love.graphics.setLineWidth(2)
    love.graphics.setColor(xColor)
    love.graphics.line(closeX+4, closeY+4, closeX+closeSize-4, closeY+closeSize-4)
    love.graphics.line(closeX+closeSize-4, closeY+4, closeX+4, closeY+closeSize-4)
    love.graphics.setLineWidth(1)
    self.closeButtonRect = {x = closeX, y = closeY, w = closeSize, h = closeSize}
end

function CargoWindow:drawItemsGrid(windowX, windowY, cargo, alpha)
    local iconSize = Theme.spacing.iconSize
    local padding = Theme.spacing.iconGridPadding
    local gridTop = windowY + Theme.window.topBarHeight + padding
    local skillsPanelWidth = 130 + 6  -- panel width + padding/border
    local turretPanelWidth = 130 + 6  -- panel width + padding/border
    local availableWidth = self.width - skillsPanelWidth - turretPanelWidth - padding * 3
    local cols = math.max(1, math.floor(availableWidth / (iconSize + padding)))
    
    local mx, my = love.mouse.getPosition()
    self.hoveredItemSlot = nil
    
    local ItemDefs = require('src.items.item_loader')
    local i = 0
    
    -- Grid starts after the turret panel on the left
    local gridLeftX = windowX + turretPanelWidth + padding
    
    for itemId, count in pairs(cargo.items) do
        local row = math.floor(i / cols)
        local col = i % cols
        local iconX = gridLeftX + padding + col * (iconSize + padding)
        local iconY = gridTop + row * (iconSize + padding)
        
        local isHovering = mx >= iconX and mx <= iconX + iconSize and my >= iconY and my <= iconY + iconSize
        
        local itemDef = ItemDefs[itemId]
        
        if isHovering then
            self.hoveredItemSlot = {itemId = itemId, itemDef = itemDef, count = count, mouseX = mx, mouseY = my}
            -- Draw hover highlight
            local color = itemDef and itemDef.design and itemDef.design.color or {0.7, 0.7, 0.8, 1}
            love.graphics.setColor(color[1] * 1.5, color[2] * 1.5, color[3] * 1.5, 0.3 * alpha)
            love.graphics.rectangle("fill", iconX, iconY, iconSize, iconSize, 4, 4)
        end
        
        -- Draw item using its draw method
        if itemDef and itemDef.draw then
            itemDef:draw(iconX + iconSize / 2, iconY + iconSize / 2)
        else
            -- Fallback to circle if no draw method
            local color = itemDef and itemDef.design and itemDef.design.color or {0.7, 0.7, 0.8, 1}
            love.graphics.setColor(color[1], color[2], color[3], (color[4] or 1) * alpha)
            love.graphics.circle("fill", iconX + iconSize / 2, iconY + iconSize / 2, iconSize / 2)
        end
        
        if count > 1 then
            love.graphics.setColor(Theme.colors.textPrimary[1], Theme.colors.textPrimary[2], Theme.colors.textPrimary[3], alpha)
            love.graphics.setFont(Theme.getFont(Theme.fonts.small))
            love.graphics.printf(tostring(count), iconX, iconY + iconSize - 8, iconSize, "center")
            love.graphics.setFont(Theme.getFont(Theme.fonts.title))
        end
        
        i = i + 1
    end
end

-- Handle mouse events (delegate to base, handle cargo-specific actions)
function CargoWindow:mousepressed(x, y, button)
    if not self.isOpen then return end
    
    -- Check close button click
    if self.closeButtonRect and button == 1 then
        if x >= self.closeButtonRect.x and x <= self.closeButtonRect.x + self.closeButtonRect.w
           and y >= self.closeButtonRect.y and y <= self.closeButtonRect.y + self.closeButtonRect.h then
            self:setOpen(false)
            return
        end
    end
    
    -- Check if clicking on inventory item (for drag start)
    if button == 1 and self.hoveredItemSlot then
        local itemId = self.hoveredItemSlot.itemId
        if string.match(itemId, "turret") then
            self.draggedItem = {itemId = itemId, itemDef = self.hoveredItemSlot.itemDef}
        end
    end
    
    -- Delegate drag handling to base class
    WindowBase.mousepressed(self, x, y, button)
end

function CargoWindow:mousereleased(x, y, button)
    if self.isOpen and button == 1 and self.draggedItem then
        -- Check if dropped on turret slot
        if self.turretSlotRect then
            if x >= self.turretSlotRect.x and x <= self.turretSlotRect.x + self.turretSlotRect.w
               and y >= self.turretSlotRect.y and y <= self.turretSlotRect.y + self.turretSlotRect.h then
                -- Equip the module on the drone controlled by the pilot
                local pilotEntities = ECS.getEntitiesWith({"Player", "InputControlled"})
                if #pilotEntities > 0 then
                    local pilotId = pilotEntities[1]
                    local input = ECS.getComponent(pilotId, "InputControlled")
                    if input and input.targetEntity then
                        local droneId = input.targetEntity
                        local playerTurretSlots = ECS.getComponent(droneId, "TurretSlots")
                        local playerCargo = ECS.getComponent(pilotId, "Cargo")
                        local playerTurret = ECS.getComponent(droneId, "Turret")
                        if playerTurretSlots and playerCargo and playerTurret then
                            playerTurretSlots.slots[1] = self.draggedItem.itemId
                            -- Map itemId to turret module name
                            local turretModuleMap = {
                                mining_laser_turret = "mining_laser",
                                basic_cannon_turret = "basic_cannon",
                                combat_laser_turret = "combat_laser"
                            }
                            playerTurret.moduleName = turretModuleMap[self.draggedItem.itemId] or self.draggedItem.itemId
                            -- Remove from cargo
                            if playerCargo.items[self.draggedItem.itemId] then
                                playerCargo.items[self.draggedItem.itemId] = playerCargo.items[self.draggedItem.itemId] - 1
                                if playerCargo.items[self.draggedItem.itemId] <= 0 then
                                    playerCargo.items[self.draggedItem.itemId] = nil
                                end
                            end
                        end
                    end
                end
            end
        end
        self.draggedItem = nil
    end

    -- If turret slot is empty, set Turret.moduleName to empty string
    local pilotEntities = ECS.getEntitiesWith({"Player", "InputControlled"})
    if #pilotEntities > 0 then
        local pilotId = pilotEntities[1]
        local input = ECS.getComponent(pilotId, "InputControlled")
        if input and input.targetEntity then
            local droneId = input.targetEntity
            local playerTurretSlots = ECS.getComponent(droneId, "TurretSlots")
            local playerTurret = ECS.getComponent(droneId, "Turret")
            if playerTurretSlots and playerTurret then
                if not playerTurretSlots.slots[1] or playerTurretSlots.slots[1] == "" then
                    playerTurret.moduleName = ""
                end
            end
        end
    end
    WindowBase.mousereleased(self, x, y, button)
end

function CargoWindow:mousemoved(x, y, dx, dy)
    WindowBase.mousemoved(self, x, y, dx, dy)
end

return CargoWindow
