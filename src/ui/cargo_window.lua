---@diagnostic disable: undefined-global
-- UI Cargo Window Module - Handles cargo inventory display and interaction
-- Derives from WindowBase for universal effects (neon border, fade, elasticity)

local ECS = require('src.ecs')
local Components = require('src.components')
local Theme = require('src.ui.theme')
local WindowBase = require('src.ui.window_base')
local Scaling = require('src.scaling')

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
---@diagnostic disable-next-line: duplicate-set-field
function CargoWindow:draw(viewportWidth, viewportHeight)
    -- Draw base window (background, top/bottom bars, dividers)
    WindowBase.draw(self)

    -- Check if should be visible
    if not self.isOpen and not self.animAlphaActive then return end

    local alpha = self.animAlpha
    if alpha <= 0 then return end

    -- Window variables are in reference/UI space (1920x1080)
    local x = self.position.x
    local y = self.position.y
    local w = self.width
    local h = self.height

    -- Draw close button
    self:drawCloseButton(x, y, alpha)

    -- Draw cargo content
    self:drawCargoContentOnly(x, y, alpha)
end

-- Draw only the cargo content without window frame (for tabbed interface)
function CargoWindow:drawCargoContentOnly(windowX, windowY, alpha)
    -- Get the player's controlled ship
    local controllers = ECS.getEntitiesWith({"InputControlled", "Player"})
    if #controllers == 0 then return end
    local pilotId = controllers[1]
    local inputComp = ECS.getComponent(pilotId, "InputControlled")
    local shipId = inputComp and inputComp.targetEntity or nil
    if not shipId then return end

    local cargo = ECS.getComponent(shipId, "Cargo")
    if not cargo then return end

    local currency = ECS.getComponent(pilotId, "Currency")

    -- Draw cargo info (bottom bar background provided by WindowBase)
    love.graphics.setColor(Theme.colors.textPrimary[1], Theme.colors.textPrimary[2], Theme.colors.textPrimary[3], alpha)
    love.graphics.setFont(Theme.getFont(Theme.fonts.normal))
    local itemCount = 0
    for _, v in pairs(cargo.items) do itemCount = itemCount + v end
    local capText = string.format("Cargo: %d / %d", itemCount, cargo.capacity or 0)
    local bottomBarH = Theme.window.bottomBarHeight
    local bottomY = windowY + self.height - bottomBarH
    love.graphics.print(capText, windowX + Scaling.scaleX(12), bottomY + Scaling.scaleY(5))

    local currencyText = currency and string.format("Credits: %d", currency.amount or 0) or ""
    love.graphics.print(currencyText, windowX + self.width - Scaling.scaleX(140), bottomY + Scaling.scaleY(5))

    -- Draw items grid
    self:drawItemsGrid(windowX, windowY, cargo, alpha)

    -- Draw dragged item icon at mouse position if dragging (use UI coords)
    if self.draggedItem and self.draggedItem.itemDef then
        local mx, my = Scaling.toUI(love.mouse.getPosition())
        love.graphics.setColor(1, 1, 1, 0.8 * alpha)

        local itemDef = self.draggedItem.itemDef
        love.graphics.push()
        love.graphics.translate(mx, my)
        love.graphics.scale(1, 1)
        if itemDef.module and itemDef.module.draw then
            -- If it's a turret, draw from the module
            itemDef.module.draw(itemDef.module, 0, 0)
        elseif itemDef.draw then
            -- For non-turret items, use their itemDef.draw
            itemDef:draw(0, 0)
        else
            -- Fallback if no draw function exists anywhere
            local color = itemDef.design and itemDef.design.color or {0.7, 0.7, 0.8, 1}
            love.graphics.setColor(color[1], color[2], color[3], (color[4] or 1) * 0.8 * alpha)
            love.graphics.circle("fill", 0, 0, 10)
        end
        love.graphics.pop()
        love.graphics.setColor(1, 1, 1, 1) -- reset color
    end
end


-- Close button is handled by WindowBase:drawCloseButton

function CargoWindow:drawItemsGrid(windowX, windowY, cargo, alpha)
    local slotSize = Theme.spacing.slotSize  -- Cargo slot size
    local padding = Theme.spacing.iconGridPadding
    local gridTop = windowY + Theme.window.topBarHeight + padding
    local availableWidth = self.width - padding * 2
    local cols = math.max(1, math.floor(availableWidth / (slotSize + padding)))

    local mx, my = Scaling.toUI(love.mouse.getPosition())
    self.hoveredItemSlot = nil

    local ItemDefs = require('src.items.item_loader')
    local i = 0

    -- Grid starts from the left edge
    local gridLeftX = windowX + padding
    
    for itemId, count in pairs(cargo.items) do
        local row = math.floor(i / cols)
        local col = i % cols
        local iconX = gridLeftX + padding + col * (slotSize + padding)
        local iconY = gridTop + row * (slotSize + padding)
        love.graphics.setFont(Theme.getFont(Theme.fonts.normal))
        
        local uiIconX, uiIconY = iconX, iconY
        local uiIconSize = slotSize
        
        local isHovering = mx >= uiIconX and mx <= uiIconX + uiIconSize and my >= uiIconY and my <= uiIconY + uiIconSize
        
        local itemDef = ItemDefs[itemId]
        local TurretModule = nil
        if itemDef and itemDef.type == "turret" and itemDef.module then
            TurretModule = itemDef.module
        end
        
        if isHovering then
            self.hoveredItemSlot = {itemId = itemId, itemDef = itemDef, count = count, mouseX = mx, mouseY = my, slotIndex = i}
            -- Draw hover highlight
            local color = (TurretModule and TurretModule.design and TurretModule.design.color) or (itemDef and itemDef.design and itemDef.design.color) or {0.7, 0.7, 0.8, 1}
            love.graphics.setColor(color[1] * 1.5, color[2] * 1.5, color[3] * 1.5, 0.3 * alpha)
            love.graphics.rectangle("fill", iconX, iconY, slotSize, slotSize, 4, 4)
        end
        
        -- Draw item using its draw method, scaled to slot size
        love.graphics.push()
        love.graphics.translate(iconX + slotSize / 2, iconY + slotSize / 2)
            love.graphics.scale(1, 1)  -- Scale icons 1x to fit the smaller slots
        if TurretModule and TurretModule.draw then
            love.graphics.setColor(1, 1, 1, alpha)
            TurretModule.draw(TurretModule, 0, 0)
        elseif itemDef and itemDef.draw then
            itemDef:draw(0, 0)
        else
            -- Fallback to circle if no draw method
            local color = (TurretModule and TurretModule.design and TurretModule.design.color) or (itemDef and itemDef.design and itemDef.design.color) or {0.7, 0.7, 0.8, 1}
            love.graphics.setColor(color[1], color[2], color[3], (color[4] or 1) * alpha)
            love.graphics.circle("fill", 0, 0, slotSize / 4)
        end
        love.graphics.pop()
        
        if count > 1 then
            love.graphics.setColor(Theme.colors.textPrimary[1], Theme.colors.textPrimary[2], Theme.colors.textPrimary[3], alpha)
            love.graphics.setFont(Theme.getFont(Theme.fonts.small))
            love.graphics.printf(tostring(count), iconX, iconY + slotSize - 8, slotSize, "center")
        end
        
        i = i + 1
    end
end

-- Drag and drop logic for cargo items
---@diagnostic disable-next-line: duplicate-set-field
function CargoWindow:mousepressed(x, y, button)
    if not self.isOpen or not self.position then return end
    local mx, my = x, y
    -- WindowBase handles close button clicks
    -- Start dragging any item from cargo grid
    if button == 1 and self.hoveredItemSlot then
        self.draggedItem = {
            itemId = self.hoveredItemSlot.itemId,
            itemDef = self.hoveredItemSlot.itemDef,
            slotIndex = self.hoveredItemSlot.slotIndex,
            count = self.hoveredItemSlot.count
        }
    end

    WindowBase.mousepressed(self, x, y, button)
end

---@diagnostic disable-next-line: duplicate-set-field
function CargoWindow:mousereleased(x, y, button)
    if button == 1 then
        self.isDragging = false
    end
    local mx, my = x, y
    
    -- Get the player's controlled ship for cargo access
    local controllers = ECS.getEntitiesWith({"InputControlled", "Player"})
    if #controllers == 0 then 
        WindowBase.mousereleased(self, x, y, button)
        return 
    end
    local pilotId = controllers[1]
    local inputComp = ECS.getComponent(pilotId, "InputControlled")
    local shipId = inputComp and inputComp.targetEntity or nil
    if not shipId then 
        WindowBase.mousereleased(self, x, y, button)
        return 
    end
    
    local cargo = ECS.getComponent(shipId, "Cargo")
    if not cargo then 
        WindowBase.mousereleased(self, x, y, button)
        return 
    end

        -- If dragging an item and dropped outside cargo window bounds, destroy it permanently
        if self.isOpen and button == 1 and self.draggedItem then
            -- Check if mouse is outside cargo window bounds
            local windowX, windowY = self.position.x, self.position.y
            local windowW, windowH = self.width, self.height
            local isOutsideBounds = x < windowX or x > windowX + windowW or y < windowY or y > windowY + windowH

            if isOutsideBounds then
                -- Remove the item from cargo permanently
                local itemId = self.draggedItem.itemId
                if cargo and cargo.items and cargo.items[itemId] then
                    cargo.items[itemId] = cargo.items[itemId] - 1
                    if cargo.items[itemId] <= 0 then
                        cargo.items[itemId] = nil
                    end
                end
            end
        end

        self.draggedItem = nil
    
    WindowBase.mousereleased(self, x, y, button)
end

---@diagnostic disable-next-line: duplicate-set-field
function CargoWindow:mousemoved(x, y, dx, dy)
    WindowBase.mousemoved(self, x, y, dx, dy)
end

return CargoWindow
