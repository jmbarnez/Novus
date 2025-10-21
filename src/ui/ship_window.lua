---@diagnostic disable: undefined-global
-- UI Ship Window Module - Simple ship equipment management
-- Derives from WindowBase for universal effects (neon border, fade, elasticity)

local ECS = require('src.ecs')
local Components = require('src.components')
local Theme = require('src.ui.theme')
local WindowBase = require('src.ui.window_base')
local Scaling = require('src.scaling')

-- Helper function to truncate text with "..." if it doesn't fit in the given width
local function truncateText(text, maxWidth, font)
    if not font then font = love.graphics.getFont() end
    local textWidth = font:getWidth(text)
    if textWidth <= maxWidth then
        return text
    end

    -- Binary search to find the maximum characters that fit
    local low = 1
    local high = #text
    local bestFit = ""

    while low <= high do
        local mid = math.floor((low + high) / 2)
        local testText = text:sub(1, mid) .. "..."
        local testWidth = font:getWidth(testText)

        if testWidth <= maxWidth then
            bestFit = testText
            low = mid + 1
        else
            high = mid - 1
        end
    end

    return bestFit ~= "" and bestFit or "..."
end

-- Create ship window instance inheriting from WindowBase
local ShipWindow = WindowBase:new{
    width = 800,
    height = 800,
    isOpen = false,
    animAlphaSpeed = 2.5,
    elasticitySpring = 18,
    elasticityDamping = 0.7,
}

-- Public interface for toggling
function ShipWindow:toggle()
    self:setOpen(not self.isOpen)
end

function ShipWindow:getOpen()
    return self.isOpen
end

-- Override draw to add ship-specific content on top of universal window
---@diagnostic disable-next-line: duplicate-set-field
function ShipWindow:draw(viewportWidth, viewportHeight)
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

    -- Draw ship equipment content
    self:drawShipContent(x, y, alpha)
end

function ShipWindow:drawShipContent(windowX, windowY, alpha)
    local contentX = windowX + 10
    local contentY = windowY + Theme.window.topBarHeight + 10
    local contentWidth = self.width - 20
    local contentHeight = self.height - Theme.window.topBarHeight - Theme.window.bottomBarHeight - 20

    -- Get ship equipment
    local pilotEntities = ECS.getEntitiesWith({"Player", "InputControlled"})
    if #pilotEntities == 0 then return end
    local pilotId = pilotEntities[1]
    local input = ECS.getComponent(pilotId, "InputControlled")
    if not input or not input.targetEntity then return end
    local droneId = input.targetEntity

    local turretSlots = ECS.getComponent(droneId, "TurretSlots")
    local defensiveSlots = ECS.getComponent(droneId, "DefensiveSlots")
    local cargo = ECS.getComponent(droneId, "Cargo")

    -- Draw title
    love.graphics.setColor(Theme.colors.textPrimary[1], Theme.colors.textPrimary[2], Theme.colors.textPrimary[3], alpha)
    love.graphics.setFont(Theme.getFont(Theme.fonts.normal))
    love.graphics.printf("Ship Equipment", contentX, contentY, contentWidth, "center")

    -- Draw current equipment
    local yPos = contentY + 30
    self:drawEquipmentSlot("Turret Module", turretSlots and turretSlots.slots[1], contentX, yPos, contentWidth, alpha)
    yPos = yPos + 60
    self:drawEquipmentSlot("Defensive Module", defensiveSlots and defensiveSlots.slots[1], contentX, yPos, contentWidth, alpha)

    -- Draw available modules from cargo
    yPos = yPos + 50
    if cargo and cargo.items then
        self:drawAvailableModules(cargo.items, contentX, yPos, contentWidth, alpha)
    end
end

function ShipWindow:drawEquipmentSlot(slotName, equippedItemId, x, y, width, alpha)
    -- Slot background
    love.graphics.setColor(Theme.colors.bgDark[1], Theme.colors.bgDark[2], Theme.colors.bgDark[3], alpha * 0.8)
    love.graphics.rectangle("fill", x, y, width, 50, 4, 4)
    love.graphics.setColor(Theme.colors.borderMedium[1], Theme.colors.borderMedium[2], Theme.colors.borderMedium[3], alpha)
    love.graphics.rectangle("line", x, y, width, 50, 4, 4)

    -- Slot name
    love.graphics.setColor(Theme.colors.textPrimary[1], Theme.colors.textPrimary[2], Theme.colors.textPrimary[3], alpha)
    love.graphics.setFont(Theme.getFont(Theme.fonts.small))
    love.graphics.print(slotName .. ":", x + 10, y + 5)

    if equippedItemId then
        -- Show equipped item
        local ItemDefs = require('src.items.item_loader')
        local itemDef = ItemDefs[equippedItemId]
        if itemDef then
            love.graphics.print(itemDef.name or equippedItemId, x + 10, y + 20)
        end

        -- Unequip button
        local buttonX = x + width - 80
        local buttonY = y + 15
        local buttonW = 70
        local buttonH = 20

        -- Check if hovering
        local mx, my = Scaling.toUI(love.mouse.getPosition())
        local isHovering = mx >= buttonX and mx <= buttonX + buttonW and my >= buttonY and my <= buttonY + buttonH

        love.graphics.setColor(isHovering and {1, 0.5, 0.5, alpha} or {1, 0.3, 0.3, alpha})
        love.graphics.rectangle("fill", buttonX, buttonY, buttonW, buttonH, 2, 2)
        love.graphics.setColor(1, 1, 1, alpha)
        love.graphics.setFont(Theme.getFont(Theme.fonts.tiny))
        local buttonText = truncateText("UNEQUIP", buttonW - 4, Theme.getFont(Theme.fonts.tiny))
        love.graphics.printf(buttonText, buttonX, buttonY + 2, buttonW, "center")

        -- Store button rect for click handling
        self.unequipButtons = self.unequipButtons or {}
        self.unequipButtons[slotName] = {x = buttonX, y = buttonY, w = buttonW, h = buttonH, itemId = equippedItemId, slotType = slotName}
    else
        -- Empty slot
        love.graphics.setColor(Theme.colors.textSecondary[1], Theme.colors.textSecondary[2], Theme.colors.textSecondary[3], alpha)
        love.graphics.print("Empty", x + 10, y + 20)
    end
end

function ShipWindow:drawAvailableModules(cargoItems, x, y, width, alpha)
    love.graphics.setColor(Theme.colors.textPrimary[1], Theme.colors.textPrimary[2], Theme.colors.textPrimary[3], alpha)
    love.graphics.setFont(Theme.getFont(Theme.fonts.small))
    love.graphics.print("Available Modules:", x, y)

    local ItemDefs = require('src.items.item_loader')
    local slotSize = Theme.spacing.slotSize
    local padding = Theme.spacing.iconGridPadding
    local gridTop = y + 20
    local availableWidth = width
    local cols = math.max(1, math.floor(availableWidth / (slotSize + padding)))
    local mx, my = Scaling.toUI(love.mouse.getPosition())

    self.equipButtons = {}
    self.hoveredItemSlot = nil
    local i = 0

    -- Grid starts from the left edge
    local gridLeftX = x

    for itemId, count in pairs(cargoItems) do
        local itemDef = ItemDefs[itemId]
        if itemDef and (itemDef.type == "turret" or string.match(itemId, "shield")) then
            local row = math.floor(i / cols)
            local col = i % cols
            local slotX = gridLeftX + col * (slotSize + padding)
            local slotY = gridTop + row * (slotSize + padding)

            -- Draw slot background
            love.graphics.setColor(Theme.colors.bgDark[1], Theme.colors.bgDark[2], Theme.colors.bgDark[3], alpha * 0.8)
            love.graphics.rectangle("fill", slotX, slotY, slotSize, slotSize, 4, 4)
            love.graphics.setColor(Theme.colors.borderMedium[1], Theme.colors.borderMedium[2], Theme.colors.borderMedium[3], alpha)
            love.graphics.rectangle("line", slotX, slotY, slotSize, slotSize, 4, 4)

            -- Check if hovering over slot
            local isHoveringSlot = mx >= slotX and mx <= slotX + slotSize and my >= slotY and my <= slotY + slotSize

            if isHoveringSlot then
                self.hoveredItemSlot = {itemId = itemId, itemDef = itemDef, count = count, mouseX = mx, mouseY = my, slotIndex = i}
            end

            -- Draw item icon
            love.graphics.push()
            love.graphics.translate(slotX + slotSize / 2, slotY + slotSize / 2)
            love.graphics.scale(1, 1)  -- Scale icons 1x to fit the smaller slots
            if itemDef.module and itemDef.module.draw then
                -- If it's a turret, draw from the module
                love.graphics.setColor(1, 1, 1, alpha)
                itemDef.module.draw(itemDef.module, 0, 0)
            elseif itemDef.draw then
                -- For non-turret items, use their itemDef.draw
                itemDef:draw(0, 0)
            else
                -- Fallback if no draw function exists
                local color = itemDef.design and itemDef.design.color or {0.7, 0.7, 0.8, 1}
                love.graphics.setColor(color[1], color[2], color[3], (color[4] or 1) * alpha)
                love.graphics.circle("fill", 0, 0, slotSize / 4)
            end
            love.graphics.pop()

            -- Draw count if > 1
            if count > 1 then
                love.graphics.setColor(Theme.colors.textPrimary[1], Theme.colors.textPrimary[2], Theme.colors.textPrimary[3], alpha)
                love.graphics.setFont(Theme.getFont(Theme.fonts.small))
                love.graphics.printf(tostring(count), slotX, slotY + slotSize - 8, slotSize, "center")
            end

            -- Equip button (smaller, positioned at bottom of slot)
            local buttonW = slotSize - 4
            local buttonH = 12
            local buttonX = slotX + 2
            local buttonY = slotY + slotSize - buttonH - 2

            -- Check if hovering over button
            local isHoveringButton = mx >= buttonX and mx <= buttonX + buttonW and my >= buttonY and my <= buttonY + buttonH

            love.graphics.setColor(isHoveringButton and {0.3, 0.8, 0.3, alpha} or {0.2, 0.6, 0.2, alpha})
            love.graphics.rectangle("fill", buttonX, buttonY, buttonW, buttonH, 2, 2)
            love.graphics.setColor(1, 1, 1, alpha)
            love.graphics.setFont(Theme.getFont(Theme.fonts.tiny))
            local buttonText = truncateText("EQUIP", buttonW - 2, Theme.getFont(Theme.fonts.tiny))
            love.graphics.printf(buttonText, buttonX, buttonY + 1, buttonW, "center")

            -- Store button rect for click handling
            table.insert(self.equipButtons, {
                x = buttonX, y = buttonY, w = buttonW, h = buttonH,
                itemId = itemId, count = count
            })

            i = i + 1
        end
    end
end

-- Simple button click handling
---@diagnostic disable-next-line: duplicate-set-field
function ShipWindow:mousepressed(x, y, button)
    if not self.isOpen or button ~= 1 then
        WindowBase.mousepressed(self, x, y, button)
        return
    end

    -- Handle unequip buttons
    if self.unequipButtons then
        for slotName, buttonRect in pairs(self.unequipButtons) do
            if x >= buttonRect.x and x <= buttonRect.x + buttonRect.w and
               y >= buttonRect.y and y <= buttonRect.y + buttonRect.h then

                -- Unequip the module
                self:unequipModule(slotName, buttonRect.itemId)
                return
            end
        end
    end

    -- Handle equip buttons
    if self.equipButtons then
        for _, buttonRect in ipairs(self.equipButtons) do
            if x >= buttonRect.x and x <= buttonRect.x + buttonRect.w and
               y >= buttonRect.y and y <= buttonRect.y + buttonRect.h then

                -- Equip the module
                self:equipModule(buttonRect.itemId)
                return
            end
        end
    end

    WindowBase.mousepressed(self, x, y, button)
end

function ShipWindow:unequipModule(slotType, itemId)
    -- Get ship components
    local pilotEntities = ECS.getEntitiesWith({"Player", "InputControlled"})
    if #pilotEntities == 0 then return end
    local pilotId = pilotEntities[1]
    local input = ECS.getComponent(pilotId, "InputControlled")
    if not input or not input.targetEntity then return end
    local droneId = input.targetEntity

    local cargo = ECS.getComponent(droneId, "Cargo")

    if slotType == "Turret Module" then
        local turretSlots = ECS.getComponent(droneId, "TurretSlots")
        local playerTurret = ECS.getComponent(droneId, "Turret")

        if turretSlots and turretSlots.slots[1] == itemId and cargo then
            -- Remove from slot
            turretSlots.slots[1] = nil
            -- Clear the turret module name so it can't fire
            if playerTurret then
                playerTurret.moduleName = nil
            end
            -- Add to inventory
            cargo.items[itemId] = (cargo.items[itemId] or 0) + 1
        end
    elseif slotType == "Defensive Module" then
        local defensiveSlots = ECS.getComponent(droneId, "DefensiveSlots")

        if defensiveSlots and defensiveSlots.slots[1] == itemId and cargo then
            -- Remove from slot
            defensiveSlots.slots[1] = nil
            -- Unequip the module
            local ItemDefs = require('src.items.item_loader')
            local itemDef = ItemDefs[itemId]
            if itemDef and itemDef.module and itemDef.module.unequip then
                itemDef.module.unequip(droneId)
            end
            -- Add to inventory
            cargo.items[itemId] = (cargo.items[itemId] or 0) + 1
        end
    end
end

function ShipWindow:equipModule(itemId)
    -- Get ship components
    local pilotEntities = ECS.getEntitiesWith({"Player", "InputControlled"})
    if #pilotEntities == 0 then return end
    local pilotId = pilotEntities[1]
    local input = ECS.getComponent(pilotId, "InputControlled")
    if not input or not input.targetEntity then return end
    local droneId = input.targetEntity

    local cargo = ECS.getComponent(droneId, "Cargo")
    if not cargo or not cargo.items[itemId] or cargo.items[itemId] <= 0 then return end

    local ItemDefs = require('src.items.item_loader')
    local itemDef = ItemDefs[itemId]
    if not itemDef then return end

    if itemDef.type == "turret" then
        local turretSlots = ECS.getComponent(droneId, "TurretSlots")
        local playerTurret = ECS.getComponent(droneId, "Turret")

        if turretSlots and playerTurret then
            -- If there's an old module, unequip it first
            local oldModuleId = turretSlots.slots[1]
            if oldModuleId then
                cargo.items[oldModuleId] = (cargo.items[oldModuleId] or 0) + 1
            end

            -- Equip the new module
            turretSlots.slots[1] = itemId
            if itemDef.module and itemDef.module.name then
                playerTurret.moduleName = itemDef.module.name
                -- Validate the module exists
                local TurretSystem = require('src.systems.turret')
                if not TurretSystem.turretModules or not TurretSystem.turretModules[playerTurret.moduleName] then
                    playerTurret.moduleName = nil
                end
            else
                playerTurret.moduleName = nil
            end

            -- Remove from inventory
            cargo.items[itemId] = cargo.items[itemId] - 1
            if cargo.items[itemId] <= 0 then
                cargo.items[itemId] = nil
            end
        end
    elseif string.match(itemId, "shield") then
        local defensiveSlots = ECS.getComponent(droneId, "DefensiveSlots")

        if defensiveSlots then
            -- If there's an old module, unequip it first
            local oldModuleId = defensiveSlots.slots[1]
            if oldModuleId then
                cargo.items[oldModuleId] = (cargo.items[oldModuleId] or 0) + 1
                -- Unequip the old module
                local oldItemDef = ItemDefs[oldModuleId]
                if oldItemDef and oldItemDef.module and oldItemDef.module.unequip then
                    oldItemDef.module.unequip(droneId)
                end
            end

            -- Equip the new module
            defensiveSlots.slots[1] = itemId
            if itemDef.module and itemDef.module.equip then
                itemDef.module.equip(droneId)
            end

            -- Remove from inventory
            cargo.items[itemId] = cargo.items[itemId] - 1
            if cargo.items[itemId] <= 0 then
                cargo.items[itemId] = nil
            end
        end
    end
end

---@diagnostic disable-next-line: duplicate-set-field
function ShipWindow:mousereleased(x, y, button)
    WindowBase.mousereleased(self, x, y, button)
end

---@diagnostic disable-next-line: duplicate-set-field
function ShipWindow:mousemoved(x, y, dx, dy)
    WindowBase.mousemoved(self, x, y, dx, dy)
end

return ShipWindow