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
    contextMenu = nil,  -- {itemId, itemDef, x, y, options}
    hoveredItemSlot = nil,
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

    if not self.position then return end

    local alpha = self.animAlpha
    if not alpha or alpha <= 0 then return end

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
    local volumeText = string.format("Cargo: %.2f / %.2f m3", cargo.currentVolume or 0, cargo.capacity or 0)
    local bottomBarH = Theme.window.bottomBarHeight
    local bottomY = windowY + self.height - bottomBarH
    love.graphics.print(volumeText, windowX + Scaling.scaleX(12), bottomY + Scaling.scaleY(5))

    local currencyText = currency and string.format("Credits: %d", currency.amount or 0) or ""
    love.graphics.print(currencyText, windowX + self.width - Scaling.scaleX(140), bottomY + Scaling.scaleY(5))

    -- Draw items grid
    self:drawItemsGrid(windowX, windowY, cargo, alpha)

    -- Draw context menu if active
    if self.contextMenu then
        self:drawContextMenu(self.contextMenu.x, self.contextMenu.y, alpha)
    end

    -- Draw dragged item icon at mouse position if dragging (use UI coords)
    if self.draggedItem and self.draggedItem.itemDef then
        local mx, my
        if Scaling._lastMouseUI and Scaling._lastMouseUI[1] then
            mx, my = Scaling._lastMouseUI[1], Scaling._lastMouseUI[2]
        else
            mx, my = Scaling.toUI(love.mouse.getPosition())
        end
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

-- Check if item can be equipped in a specific slot type
function CargoWindow:canEquipInSlot(itemId, slotType)
    local ItemDefs = require('src.items.item_loader')
    local itemDef = ItemDefs[itemId]
    if not itemDef then return false end

    if slotType == "Turret Module" then
        return itemDef.type == "turret"
    elseif slotType == "Defensive Module" then
        return string.match(itemId, "shield") or itemDef.type == "shield"
    elseif slotType == "Generator Module" then
        return itemDef.type == "generator"
    end

    return false
end

-- Get compatible equipment slots for an item
function CargoWindow:getCompatibleSlots(itemId)
    local compatibleSlots = {}

    if self:canEquipInSlot(itemId, "Turret Module") then
        table.insert(compatibleSlots, "Turret Module")
    end
    if self:canEquipInSlot(itemId, "Defensive Module") then
        table.insert(compatibleSlots, "Defensive Module")
    end
    if self:canEquipInSlot(itemId, "Generator Module") then
        table.insert(compatibleSlots, "Generator Module")
    end

    return compatibleSlots
end

-- Open context menu for cargo items
function CargoWindow:openContextMenu(itemId, itemDef, x, y)
    local compatibleSlots = self:getCompatibleSlots(itemId)
    local options = {}

    -- Determine drone and slot occupancy so we can show "Swap" when occupied
    local pilotEntities = ECS.getEntitiesWith({"Player", "InputControlled"})
    local droneId = nil
    if #pilotEntities > 0 then
        local pilotId = pilotEntities[1]
        local input = ECS.getComponent(pilotId, "InputControlled")
        if input and input.targetEntity then droneId = input.targetEntity end
    end

    for _, slotType in ipairs(compatibleSlots) do
        local occupied = false
        if droneId then
            if slotType == "Turret Module" then
                local turretSlots = ECS.getComponent(droneId, "TurretSlots")
                occupied = (turretSlots and turretSlots.slots and turretSlots.slots[1]) ~= nil
            elseif slotType == "Defensive Module" then
                local defensiveSlots = ECS.getComponent(droneId, "DefensiveSlots")
                occupied = (defensiveSlots and defensiveSlots.slots and defensiveSlots.slots[1]) ~= nil
            elseif slotType == "Generator Module" then
                local generatorSlots = ECS.getComponent(droneId, "GeneratorSlots")
                occupied = (generatorSlots and generatorSlots.slots and generatorSlots.slots[1]) ~= nil
            end
        end

        local itemName = (itemDef and itemDef.name) or tostring(itemId)
        local optionText
        if occupied then
            optionText = "Swap " .. itemName .. " with " .. slotType
        else
            optionText = "Equip " .. itemName .. " to " .. slotType
        end

        table.insert(options, {
            text = optionText,
            action = "equip",
            slotType = slotType
        })
    end

    if #options == 0 then
        table.insert(options, { text = "No compatible slots", action = "noop" })
    end

    local menuWidth = 300
    local menuHeight = 8 + (#options * 24)

    self.contextMenu = {
        itemId = itemId,
        itemDef = itemDef,
        x = x,
        y = y,
        options = options,
        hoveredOption = nil,
        width = menuWidth,
        height = menuHeight
    }
end

-- Handle context menu option clicks
function CargoWindow:handleContextMenuClick(optionIndex)
    if not self.contextMenu or not self.contextMenu.options[optionIndex] then return end

    local option = self.contextMenu.options[optionIndex]
    if option.action == "equip" and option.slotType then
        -- Switch to ship window and trigger equip
        local ShipWindow = require('src.ui.ship_window')
        if ShipWindow.getOpen and not ShipWindow:getOpen() then
            ShipWindow:toggle()  -- Open ship window
        end
        -- Set active tab to loadout
        ShipWindow.activeTab = "loadout"
        -- Equip the module
        ShipWindow:equipModule(self.contextMenu.itemId)
    end

    self.contextMenu = nil
end

-- Draw context menu for cargo items
function CargoWindow:drawContextMenu(x, y, alpha)
    local menuWidth = (self.contextMenu and self.contextMenu.width) or 200
    local menuHeight = (self.contextMenu and self.contextMenu.height) or (8 + (#self.contextMenu.options * 24))

    -- Background
    love.graphics.setColor(Theme.colors.bgDark[1], Theme.colors.bgDark[2], Theme.colors.bgDark[3], alpha * 0.95)
    love.graphics.rectangle("fill", x, y, menuWidth, menuHeight, 5, 5)

    -- Border
    love.graphics.setColor(Theme.colors.borderMedium[1], Theme.colors.borderMedium[2], Theme.colors.borderMedium[3], alpha)
    love.graphics.rectangle("line", x, y, menuWidth, menuHeight, 5, 5)

    -- Minimal: render one-line commands only (each option already contains the item name)
    love.graphics.setFont(Theme.getFont(Theme.fonts.small))
    for i, option in ipairs(self.contextMenu.options) do
        local optionY = y + 8 + (i-1) * 24
        local isHovered = self.contextMenu.hoveredOption == i

        if isHovered then
            love.graphics.setColor(Theme.colors.bgMedium[1], Theme.colors.bgMedium[2], Theme.colors.bgMedium[3], alpha * 0.8)
            love.graphics.rectangle("fill", x + 5, optionY - 2, menuWidth - 10, 20, 3, 3)
        end

        local textColor = Theme.colors.textPrimary
        if option.action == "equip" and option.slotType then
            if option.slotType == "Turret Module" then
                textColor = Theme.colors.textAccent
            elseif option.slotType == "Defensive Module" then
                textColor = Theme.colors.textSecondary
            elseif option.slotType == "Generator Module" then
                textColor = Theme.colors.textPrimary
            end
        elseif option.action == "noop" then
            textColor = {Theme.colors.textSecondary[1] * 0.6, Theme.colors.textSecondary[2] * 0.6, Theme.colors.textSecondary[3] * 0.6}
        end
        love.graphics.setColor(textColor[1], textColor[2], textColor[3], alpha)

        love.graphics.printf(option.text, x + 8, optionY + 2, menuWidth - 16, "left")
    end
end

function CargoWindow:drawItemsGrid(windowX, windowY, cargo, alpha)
    local slotSize = Theme.spacing.slotSize  -- Cargo slot size
    local padding = Theme.spacing.iconGridPadding
    local gridTop = windowY + Theme.window.topBarHeight + padding
    local bottomBarH = Theme.window.bottomBarHeight

    -- Compute available vertical space (account for top and bottom bars)
    local availableHeight = self.height - Theme.window.topBarHeight - bottomBarH - padding * 2
    local labelHeight = 14 -- approximate label height in pixels (small font)
    local rowSpacing = 12 -- extra space between rows to avoid label overlap
    local labelOffset = 8 -- vertical offset for label from slot
    local cellHeight = slotSize + padding + labelHeight + rowSpacing

    -- Collect and sort item keys for deterministic layout
    local ItemDefs = require('src.items.item_loader')
    local itemKeys = {}
    for itemId, _ in pairs(cargo.items) do table.insert(itemKeys, itemId) end
    table.sort(itemKeys)
    local totalItems = #itemKeys

    -- Determine how many rows fit vertically, then compute columns needed
    local maxRows = math.max(1, math.floor(availableHeight / cellHeight))
    local cols = math.max(1, math.ceil(totalItems / maxRows))

    local mx, my
    if Scaling._lastMouseUI and Scaling._lastMouseUI[1] then
        mx, my = Scaling._lastMouseUI[1], Scaling._lastMouseUI[2]
    else
        mx, my = Scaling.toUI(love.mouse.getPosition())
    end
    self.hoveredItemSlot = nil

    local i = 0
    local gridLeftX = windowX + padding

    for _, itemId in ipairs(itemKeys) do
        local count = cargo.items[itemId]
        -- Layout column-first so rows fill vertically and nothing gets clipped
        local col = math.floor(i / maxRows)
        local row = i % maxRows
        local iconX = gridLeftX + padding + col * (slotSize + padding)
        local iconY = gridTop + row * cellHeight
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
        end

        -- Update context menu hover state for this slot
        if self.contextMenu and isHovering then
            self.contextMenu.hoveredOption = nil  -- Clear hover when over the item slot
        end

        -- Draw slot background with subtle compatibility indicator
        local compatibleSlots = self:getCompatibleSlots(itemId)
        if #compatibleSlots > 0 then
            -- Subtle green tint for compatible items
            love.graphics.setColor(0.1, 0.25, 0.1, alpha * 0.4)
            love.graphics.rectangle("fill", iconX - 1, iconY - 1, slotSize + 2, slotSize + 2, 5, 5)
            love.graphics.setColor(Theme.colors.bgDark[1], Theme.colors.bgDark[2], Theme.colors.bgDark[3], alpha * 0.8)
        else
            love.graphics.setColor(Theme.colors.bgDark[1], Theme.colors.bgDark[2], Theme.colors.bgDark[3], alpha * 0.8)
        end
        love.graphics.rectangle("fill", iconX, iconY, slotSize, slotSize, 4, 4)

        -- Hover highlight (shows over the subtle tint)
        if isHovering then
            -- Draw hover highlight
            local color = (TurretModule and TurretModule.design and TurretModule.design.color) or (itemDef and itemDef.design and itemDef.design.color) or {0.7, 0.7, 0.8, 1}
            love.graphics.setColor(color[1] * 1.5, color[2] * 1.5, color[3] * 1.5, 0.3 * alpha)
            love.graphics.rectangle("fill", iconX, iconY, slotSize, slotSize, 4, 4)
        end

        -- Draw slot border with subtle green for compatible items
        if #compatibleSlots > 0 then
            love.graphics.setColor(0.15, 0.35, 0.15, alpha * 0.6)
        else
            love.graphics.setColor(Theme.colors.borderMedium[1], Theme.colors.borderMedium[2], Theme.colors.borderMedium[3], alpha * 0.3)
        end
        love.graphics.rectangle("line", iconX, iconY, slotSize, slotSize, 4, 4)

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

        -- Draw item name at bottom center of the slot (helps finding new items like railgun)
        love.graphics.setColor(Theme.colors.textPrimary[1], Theme.colors.textPrimary[2], Theme.colors.textPrimary[3], alpha)
        love.graphics.setFont(Theme.getFont(Theme.fonts.small))
        local label = (itemDef and itemDef.name) or tostring(itemId)
        -- Center label under the slot and keep within slot width
        love.graphics.printf(label, uiIconX, uiIconY + uiIconSize + labelOffset, uiIconSize, "center")

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

    -- Close context menu if clicking outside of it (any button)
    if self.contextMenu then
        local uiX, uiY = Scaling.toUI(mx, my)
        local cmW = (self.contextMenu and self.contextMenu.width) or 200
        local cmH = (self.contextMenu and self.contextMenu.height) or (8 + (#self.contextMenu.options * 24))
        if not (uiX >= self.contextMenu.x and uiX <= self.contextMenu.x + cmW and
                uiY >= self.contextMenu.y and uiY <= self.contextMenu.y + cmH) then
            self.contextMenu = nil
            return
        end
    end

    -- WindowBase handles close button clicks
    -- Start dragging any item from cargo grid
    if button == 1 and self.hoveredItemSlot then
        self.draggedItem = {
            itemId = self.hoveredItemSlot.itemId,
            itemDef = self.hoveredItemSlot.itemDef,
            slotIndex = self.hoveredItemSlot.slotIndex,
            count = self.hoveredItemSlot.count
        }
    -- Right click: open context menu for cargo items (only if no existing context menu)
    elseif button == 2 and self.hoveredItemSlot and not self.contextMenu then
        self:openContextMenu(self.hoveredItemSlot.itemId, self.hoveredItemSlot.itemDef, Scaling.toUI(mx, my))
    end

    WindowBase.mousepressed(self, x, y, button)
end

---@diagnostic disable-next-line: duplicate-set-field
function CargoWindow:mousereleased(x, y, button)
    if button == 1 then
        self.isDragging = false
    end

    -- Handle context menu clicks
    if self.contextMenu and button == 1 then
        local mx, my = Scaling.toUI(x, y)
        local cmW = (self.contextMenu and self.contextMenu.width) or 200
        local cmH = (self.contextMenu and self.contextMenu.height) or (8 + (#self.contextMenu.options * 24))
        if mx >= self.contextMenu.x and mx <= self.contextMenu.x + cmW and
           my >= self.contextMenu.y and my <= self.contextMenu.y + cmH then
            -- Find which option was clicked
            local optionIndex = math.floor((my - self.contextMenu.y - 8) / 24) + 1
            if optionIndex >= 1 and optionIndex <= #self.contextMenu.options then
                self:handleContextMenuClick(optionIndex)
                return
            end
        end
        -- Click outside menu - close it
        self.contextMenu = nil
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
                if cargo then
                    cargo:removeItem(itemId, 1)
                end
            end
        end

        self.draggedItem = nil

    WindowBase.mousereleased(self, x, y, button)
end

---@diagnostic disable-next-line: duplicate-set-field
function CargoWindow:mousemoved(x, y, dx, dy)
    -- Handle context menu hover detection
    if self.contextMenu then
        local mx, my = Scaling.toUI(x, y)
        local cmW = (self.contextMenu and self.contextMenu.width) or 200
        local cmH = (self.contextMenu and self.contextMenu.height) or (8 + (#self.contextMenu.options * 24))
        if mx >= self.contextMenu.x and mx <= self.contextMenu.x + cmW and
           my >= self.contextMenu.y and my <= self.contextMenu.y + cmH then
            -- Find which option is hovered
            local optionIndex = math.floor((my - self.contextMenu.y - 8) / 24) + 1
            if optionIndex >= 1 and optionIndex <= #self.contextMenu.options then
                self.contextMenu.hoveredOption = optionIndex
            else
                self.contextMenu.hoveredOption = nil
            end
        else
            self.contextMenu.hoveredOption = nil
        end
    end

    WindowBase.mousemoved(self, x, y, dx, dy)
end

---@diagnostic disable-next-line: duplicate-set-field
function CargoWindow:keypressed(key)
    -- Close context menu on escape
    if key == "escape" and self.contextMenu then
        self.contextMenu = nil
        return
    end

    WindowBase.keypressed(self, key)
end

return CargoWindow
