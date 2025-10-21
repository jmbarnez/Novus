---@diagnostic disable: undefined-global
-- UI Ship Window Module - Tabbed container for Ship/Cargo/Skills windows
-- Derives from WindowBase for universal effects (neon border, fade, elasticity)

local ECS = require('src.ecs')
local Components = require('src.components')
local Theme = require('src.ui.theme')
local WindowBase = require('src.ui.window_base')
local Scaling = require('src.scaling')

-- Import the skills panel module
local SkillsPanel = require('src.ui.skills_panel')

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
    width = 900,
    height = 700,
    isOpen = false,
    animAlphaSpeed = 2.5,
    elasticitySpring = 18,
    elasticityDamping = 0.7
}

-- Initialize tab management fields
ShipWindow.activeTab = "loadout" -- "loadout", "skills"
ShipWindow.tabs = {"loadout", "skills"}
ShipWindow.tabNames = {
    loadout = "Loadout & Cargo",
    skills = "Skills"
}
ShipWindow.tabButtons = {}

-- Initialize cargo and skills state
ShipWindow.draggedItem = nil
ShipWindow.hoveredItemSlot = nil

-- Public interface for toggling
function ShipWindow:toggle()
    self:setOpen(not self.isOpen)
end

function ShipWindow:getOpen()
    return self.isOpen
end

-- Override draw to add tabbed ship-specific content on top of universal window
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

    -- Draw tab headers
    self:drawTabHeaders(x, y, alpha)

    -- Draw content based on active tab by delegating to respective window objects
    if self.activeTab == "loadout" then
        self:drawLoadoutContent(x, y, alpha)
    elseif self.activeTab == "skills" then
        self:drawSkillsContent(x, y, alpha)
    end

    -- Draw bottom bar with status info
    self:drawBottomBar(x, y, alpha)
end

-- Tab management
local TAB_HEIGHT = 40

function ShipWindow:drawTabHeaders(windowX, windowY, alpha)
    local tabY = windowY + Theme.window.topBarHeight
    local tabWidth = self.width / #self.tabs
    local mx, my = Scaling.toUI(love.mouse.getPosition())

    self.tabButtons = {}

    for i, tabKey in ipairs(self.tabs) do
        local tabX = windowX + (i - 1) * tabWidth
        local isActive = self.activeTab == tabKey
        local isHovered = mx >= tabX and mx <= tabX + tabWidth and my >= tabY and my <= tabY + TAB_HEIGHT

        -- Tab background
        if isActive then
            love.graphics.setColor(Theme.colors.bgMedium[1], Theme.colors.bgMedium[2], Theme.colors.bgMedium[3], alpha)
        elseif isHovered then
            love.graphics.setColor(Theme.colors.bgDark[1], Theme.colors.bgDark[2], Theme.colors.bgDark[3], alpha * 0.8)
        else
            love.graphics.setColor(Theme.colors.bgDark[1], Theme.colors.bgDark[2], Theme.colors.bgDark[3], alpha * 0.6)
        end
        love.graphics.rectangle("fill", tabX, tabY, tabWidth, TAB_HEIGHT)

        -- Tab border
        love.graphics.setColor(Theme.colors.borderMedium[1], Theme.colors.borderMedium[2], Theme.colors.borderMedium[3], alpha)
        love.graphics.rectangle("line", tabX, tabY, tabWidth, TAB_HEIGHT)

        -- Tab text - centered vertically
        love.graphics.setColor(Theme.colors.textPrimary[1], Theme.colors.textPrimary[2], Theme.colors.textPrimary[3], alpha)
        love.graphics.setFont(Theme.getFont(Theme.fonts.small))
        love.graphics.printf(self.tabNames[tabKey], tabX, tabY + TAB_HEIGHT/2 - 8, tabWidth, "center")

        -- Store tab button for click handling
        table.insert(self.tabButtons, {
            x = tabX, y = tabY, w = tabWidth, h = TAB_HEIGHT,
            tabKey = tabKey
        })
    end

    -- Tab separator line
    love.graphics.setColor(Theme.colors.borderDark[1], Theme.colors.borderDark[2], Theme.colors.borderDark[3], alpha)
    love.graphics.line(windowX, tabY + TAB_HEIGHT, windowX + self.width, tabY + TAB_HEIGHT)
end

-- Draw bottom status bar with credits and cargo info
function ShipWindow:drawBottomBar(windowX, windowY, alpha)
    local x = windowX
    local y = windowY + self.height - Theme.window.bottomBarHeight
    local w = self.width
    local h = Theme.window.bottomBarHeight
    local padding = Theme.spacing.padding

    -- Get player and ship data
    local pilotEntities = ECS.getEntitiesWith({"Player", "InputControlled"})
    if #pilotEntities == 0 then return end
    local pilotId = pilotEntities[1]
    local input = ECS.getComponent(pilotId, "InputControlled")
    if not input or not input.targetEntity then return end
    local droneId = input.targetEntity

    local wallet = ECS.getComponent(pilotId, "Wallet")
    local cargo = ECS.getComponent(droneId, "Cargo")

    -- Calculate cargo usage
    local itemCount = 0
    local maxCapacity = cargo and cargo.capacity or 0
    if cargo then
        for _, v in pairs(cargo.items) do
            itemCount = itemCount + v
        end
    end

    love.graphics.setFont(Theme.getFont(Theme.fonts.normal))
    local fontHeight = love.graphics.getFont():getHeight()
    local textY = y + (h - fontHeight) / 2

    -- Draw left side: Credits
    local creditsText = wallet and string.format("Credits: %d", wallet.credits) or "Credits: 0"
    love.graphics.setColor(Theme.colors.textPrimary[1], Theme.colors.textPrimary[2], Theme.colors.textPrimary[3], alpha)
    love.graphics.print(creditsText, x + padding, textY)

    -- Draw right side: Cargo capacity
    local cargoText = string.format("Cargo: %d/%d", itemCount, maxCapacity)
    love.graphics.setColor(Theme.colors.textPrimary[1], Theme.colors.textPrimary[2], Theme.colors.textPrimary[3], alpha)
    love.graphics.printf(cargoText, x + padding, textY, w - padding * 2, "right")
end

-- Draw the combined equipment + cargo view side-by-side
function ShipWindow:drawLoadoutContent(windowX, windowY, alpha)
    local contentX = windowX + 10
    local contentY = windowY + Theme.window.topBarHeight + TAB_HEIGHT + 10
    local contentWidth = self.width - 20
    local contentHeight = self.height - Theme.window.topBarHeight - Theme.window.bottomBarHeight - TAB_HEIGHT - 20

    -- Get ship equipment and cargo
    local pilotEntities = ECS.getEntitiesWith({"Player", "InputControlled"})
    if #pilotEntities == 0 then return end
    local pilotId = pilotEntities[1]
    local input = ECS.getComponent(pilotId, "InputControlled")
    if not input or not input.targetEntity then return end
    local droneId = input.targetEntity

    local turretSlots = ECS.getComponent(droneId, "TurretSlots")
    local defensiveSlots = ECS.getComponent(droneId, "DefensiveSlots")
    local cargo = ECS.getComponent(droneId, "Cargo")
    local hull = ECS.getComponent(droneId, "Hull")
    local shield = ECS.getComponent(droneId, "Shield")
    local polygonShape = ECS.getComponent(droneId, "PolygonShape")
    local position = ECS.getComponent(droneId, "Position")

    -- Split the view: 25% equipment, 75% cargo
    local equipmentWidth = math.floor(contentWidth * 0.25)
    local cargoWidth = contentWidth - equipmentWidth - 10
    local dividerX = contentX + equipmentWidth + 5

    -- Draw vertical divider
    love.graphics.setColor(Theme.colors.borderMedium[1], Theme.colors.borderMedium[2], Theme.colors.borderMedium[3], alpha * 0.6)
    love.graphics.rectangle("fill", dividerX - 1, contentY, 2, contentHeight)

    -- LEFT PANEL: Ship Stats and Equipment
    local slotSize = Theme.spacing.slotSize
    local slotPadding = Theme.spacing.iconGridPadding

    local statsY = contentY + 30
    love.graphics.setFont(Theme.getFont(Theme.fonts.tiny))
    love.graphics.setColor(Theme.colors.textSecondary[1], Theme.colors.textSecondary[2], Theme.colors.textSecondary[3], alpha)

    -- Hull Bar
    if hull then
        local barWidth = equipmentWidth - 20
        local barHeight = 12
        local hullRatio = math.max(0, math.min(1, hull.current / hull.max))
        love.graphics.setColor(0.3, 0.7, 0.3, alpha)
        love.graphics.rectangle("fill", contentX + 10, statsY, barWidth * hullRatio, barHeight)
        love.graphics.setColor(0.2, 0.3, 0.2, alpha)
        love.graphics.rectangle("line", contentX + 10, statsY, barWidth, barHeight)
        love.graphics.setColor(Theme.colors.textSecondary[1], Theme.colors.textSecondary[2], Theme.colors.textSecondary[3], alpha)
        love.graphics.printf(string.format("Hull: %d/%d", hull.current, hull.max), contentX + 10, statsY, barWidth, "center")
        statsY = statsY + barHeight + 8
    end

    -- Shield Bar
    if shield and shield.max > 0 then
        local barWidth = equipmentWidth - 20
        local barHeight = 12
        local shieldRatio = math.max(0, math.min(1, shield.current / shield.max))
        love.graphics.setColor(0.3, 0.5, 0.9, alpha)
        love.graphics.rectangle("fill", contentX + 10, statsY, barWidth * shieldRatio, barHeight)
        love.graphics.setColor(0.2, 0.2, 0.3, alpha)
        love.graphics.rectangle("line", contentX + 10, statsY, barWidth, barHeight)
        love.graphics.setColor(Theme.colors.textSecondary[1], Theme.colors.textSecondary[2], Theme.colors.textSecondary[3], alpha)
        love.graphics.printf(string.format("Shield: %d/%d", shield.current, shield.max), contentX + 10, statsY, barWidth, "center")
        statsY = statsY + barHeight + 8
    end

    -- Max Speed and Thrust Force
    love.graphics.setFont(Theme.getFont(Theme.fonts.tiny))
    love.graphics.setColor(Theme.colors.textSecondary[1], Theme.colors.textSecondary[2], Theme.colors.textSecondary[3], alpha)
    local Constants = require('src.constants')
    local thrustMultiplier = 1
    local mass = 1
    local shipDesign = ECS.getComponent(droneId, "ShipDesign")
    if shipDesign then
        if shipDesign.thrustMultiplier then
            thrustMultiplier = shipDesign.thrustMultiplier
        end
        if shipDesign.mass then
            mass = shipDesign.mass
        end
    end
    local maxVelocity = Constants.player_max_speed * thrustMultiplier
    local thrustForce = mass * thrustMultiplier * Constants.player_max_speed
    love.graphics.printf(string.format("Max Velocity: %.0f units/s", maxVelocity), contentX + 10, statsY, equipmentWidth - 20, "center")
    statsY = statsY + 14
    love.graphics.printf(string.format("Thrust Force: %.0f", thrustForce), contentX + 10, statsY, equipmentWidth - 20, "center")
    statsY = statsY + 14
    love.graphics.printf(string.format("Thrust Multiplier: %.2f", thrustMultiplier), contentX + 10, statsY, equipmentWidth - 20, "center")
    statsY = statsY + 18

    -- Turret Module Section
    love.graphics.setColor(Theme.colors.textPrimary[1], Theme.colors.textPrimary[2], Theme.colors.textPrimary[3], alpha)
    love.graphics.setFont(Theme.getFont(Theme.fonts.small))
    love.graphics.printf("Turret", contentX, statsY, equipmentWidth, "center")
    self:drawEquipmentSlot("Turret Module", turretSlots and turretSlots.slots[1], contentX + (equipmentWidth - slotSize) / 2, statsY + 20, slotSize, alpha, droneId)

    -- Defensive Module Section
    local defensiveY = statsY + slotSize + slotPadding + 15
    love.graphics.setColor(Theme.colors.textPrimary[1], Theme.colors.textPrimary[2], Theme.colors.textPrimary[3], alpha)
    love.graphics.setFont(Theme.getFont(Theme.fonts.small))
    love.graphics.printf("Defense", contentX, defensiveY, equipmentWidth, "center")
    self:drawEquipmentSlot("Defensive Module", defensiveSlots and defensiveSlots.slots[1], contentX + (equipmentWidth - slotSize) / 2, defensiveY + 20, slotSize, alpha, droneId)

    -- RIGHT PANEL: Cargo
    local cargoX = dividerX + 5
    love.graphics.setColor(Theme.colors.textPrimary[1], Theme.colors.textPrimary[2], Theme.colors.textPrimary[3], alpha)
    love.graphics.setFont(Theme.getFont(Theme.fonts.normal))
    love.graphics.printf("Cargo", cargoX, contentY, cargoWidth, "center")


    -- Draw cargo grid
    if cargo then
        self:drawCargoGrid(cargo.items, cargoX, contentY + 45, cargoWidth, contentHeight - 45, alpha)
    end

    -- Draw dragged item at mouse position
    if self.draggedItem and self.draggedItem.itemDef then
        local mx, my = Scaling.toUI(love.mouse.getPosition())
        love.graphics.setColor(1, 1, 1, 0.8 * alpha)
        local itemDef = self.draggedItem.itemDef
        love.graphics.push()
        love.graphics.translate(mx, my)
        love.graphics.scale(1.2, 1.2)
        if itemDef.module and itemDef.module.draw then
            itemDef.module.draw(itemDef.module, 0, 0)
        elseif itemDef.draw then
            itemDef:draw(0, 0)
        else
            local color = itemDef.design and itemDef.design.color or {0.7, 0.7, 0.8, 1}
            love.graphics.setColor(color[1], color[2], color[3], (color[4] or 1) * 0.8 * alpha)
            love.graphics.circle("fill", 0, 0, 10)
        end
        love.graphics.pop()
    end
end

-- Draw the cargo grid showing all items
function ShipWindow:drawCargoGrid(cargoItems, x, y, width, height, alpha)
    local ItemDefs = require('src.items.item_loader')
    local slotSize = Theme.spacing.slotSize
    local padding = Theme.spacing.iconGridPadding
    local cols = math.max(1, math.floor(width / (slotSize + padding)))
    local mx, my = Scaling.toUI(love.mouse.getPosition())

    self.hoveredItemSlot = nil
    local i = 0

    for itemId, count in pairs(cargoItems) do
        local itemDef = ItemDefs[itemId]
        if itemDef then
            local row = math.floor(i / cols)
            local col = i % cols
            local slotX = x + col * (slotSize + padding)
            local slotY = y + row * (slotSize + padding)

            -- Check if slot is visible in available height
            if slotY + slotSize > y + height then
                break -- Simple clipping for now
            end

            -- Draw slot background
            love.graphics.setColor(Theme.colors.bgDark[1], Theme.colors.bgDark[2], Theme.colors.bgDark[3], alpha * 0.8)
            love.graphics.rectangle("fill", slotX, slotY, slotSize, slotSize, 4, 4)
            
            -- Check if hovering over slot
            local isHoveringSlot = mx >= slotX and mx <= slotX + slotSize and my >= slotY and my <= slotY + slotSize
            
            if isHoveringSlot then
                self.hoveredItemSlot = {itemId = itemId, itemDef = itemDef, count = count, mouseX = mx, mouseY = my, slotIndex = i}
                -- Highlight on hover
                local color = (itemDef.module and itemDef.module.design and itemDef.module.design.color) or (itemDef.design and itemDef.design.color) or {0.7, 0.7, 0.8, 1}
                love.graphics.setColor(color[1] * 1.5, color[2] * 1.5, color[3] * 1.5, 0.3 * alpha)
                love.graphics.rectangle("fill", slotX, slotY, slotSize, slotSize, 4, 4)
            end
            
            love.graphics.setColor(Theme.colors.borderMedium[1], Theme.colors.borderMedium[2], Theme.colors.borderMedium[3], alpha)
            love.graphics.rectangle("line", slotX, slotY, slotSize, slotSize, 4, 4)

            -- Draw item icon
            love.graphics.push()
            love.graphics.translate(slotX + slotSize / 2, slotY + slotSize / 2)
            love.graphics.scale(1, 1)
            if itemDef.module and itemDef.module.draw then
                love.graphics.setColor(1, 1, 1, alpha)
                itemDef.module.draw(itemDef.module, 0, 0)
            elseif itemDef.draw then
                itemDef:draw(0, 0)
            else
                local color = itemDef.design and itemDef.design.color or {0.7, 0.7, 0.8, 1}
                love.graphics.setColor(color[1], color[2], color[3], (color[4] or 1) * alpha)
                love.graphics.circle("fill", 0, 0, slotSize / 4)
            end
            love.graphics.pop()

            -- Draw count if > 1
            if count > 1 then
                love.graphics.setColor(Theme.colors.textPrimary[1], Theme.colors.textPrimary[2], Theme.colors.textPrimary[3], alpha)
                love.graphics.setFont(Theme.getFont(Theme.fonts.small))
                love.graphics.printf(tostring(count), slotX, slotY + slotSize - 16, slotSize, "center")
            end

            i = i + 1
        end
    end
end

function ShipWindow:drawEquipmentSlot(slotName, equippedItemId, x, y, width, alpha, droneId)
    local slotSize = width
    local mx, my = Scaling.toUI(love.mouse.getPosition())
    
    -- Check if hovering with a dragged item (for drop zone highlighting)
    local isDropZone = false
    if self.draggedItem and self.draggedItem.itemDef then
        local itemDef = self.draggedItem.itemDef
        -- Check if this item can be equipped in this slot
        if (slotName == "Turret Module" and itemDef.type == "turret") or
           (slotName == "Defensive Module" and string.match(self.draggedItem.itemId, "shield")) then
            if mx >= x and mx <= x + width and my >= y and my <= y + slotSize then
                isDropZone = true
            end
        end
    end
    
    -- Slot background (highlight if valid drop zone)
    if isDropZone then
        love.graphics.setColor(0.3, 0.8, 0.3, alpha * 0.5)
    else
        love.graphics.setColor(Theme.colors.bgDark[1], Theme.colors.bgDark[2], Theme.colors.bgDark[3], alpha * 0.8)
    end
    love.graphics.rectangle("fill", x, y, slotSize, slotSize, 4, 4)

    local borderColor = isDropZone and {0.3, 1, 0.3, alpha} or {Theme.colors.borderMedium[1], Theme.colors.borderMedium[2], Theme.colors.borderMedium[3], alpha}
    love.graphics.setColor(borderColor)
    love.graphics.rectangle("line", x, y, slotSize, slotSize, 4, 4)

    -- Store drop zone for mouse handling
    self.equipmentSlots = self.equipmentSlots or {}
    self.equipmentSlots[slotName] = {x = x, y = y, w = slotSize, h = slotSize, slotType = slotName}

    if equippedItemId then
        -- Show equipped item with icon
        local ItemDefs = require('src.items.item_loader')
        local itemDef = ItemDefs[equippedItemId]
        if itemDef then
            -- Draw item icon centered in slot
            local iconSize = slotSize * 0.8
            local iconX = x + (slotSize - iconSize) / 2
            local iconY = y + (slotSize - iconSize) / 2
            love.graphics.push()
            love.graphics.translate(iconX + iconSize/2, iconY + iconSize/2)
            love.graphics.scale(iconSize/48, iconSize/48)
            if itemDef.module and itemDef.module.draw then
                love.graphics.setColor(1, 1, 1, alpha)
                itemDef.module.draw(itemDef.module, 0, 0)
            elseif itemDef.draw then
                itemDef:draw(0, 0)
            else
                local color = itemDef.design and itemDef.design.color or {0.7, 0.7, 0.8, 1}
                love.graphics.setColor(color[1], color[2], color[3], (color[4] or 1) * alpha)
                love.graphics.circle("fill", 0, 0, iconSize / 4)
            end
            love.graphics.pop()
        end
        -- No equip/unequip button
    end
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
            -- Add to cargo
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
            -- Add to cargo
            cargo.items[itemId] = (cargo.items[itemId] or 0) + 1
        end
    end
end


function ShipWindow:drawSkillsContent(windowX, windowY, alpha)
    -- Use the skills panel to draw the content
    local contentX = windowX + 10
    local contentY = windowY + Theme.window.topBarHeight + TAB_HEIGHT + 10
    local contentWidth = self.width - 20
    local contentHeight = self.height - Theme.window.topBarHeight - Theme.window.bottomBarHeight - TAB_HEIGHT - 20

    SkillsPanel.draw(contentX, contentY, contentWidth, contentHeight, alpha)
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

            -- Remove from cargo
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

            -- Remove from cargo
            cargo.items[itemId] = cargo.items[itemId] - 1
            if cargo.items[itemId] <= 0 then
                cargo.items[itemId] = nil
            end
        end
    end
end

-- Handle tab switching and delegate mouse events to appropriate tab content
---@diagnostic disable-next-line: duplicate-set-field
function ShipWindow:mousepressed(x, y, button)
    if not self.isOpen or not self.position then return end

    -- Check for tab clicks first
    if self.tabButtons then
        for _, tabButton in ipairs(self.tabButtons) do
            if x >= tabButton.x and x <= tabButton.x + tabButton.w and
               y >= tabButton.y and y <= tabButton.y + tabButton.h then
                self.activeTab = tabButton.tabKey
                return -- Don't process as regular click
            end
        end
    end

    -- Delegate mouse events to the appropriate tab content
    if self.activeTab == "loadout" then
        -- Equip/unequip buttons removed; only allow drag from cargo
        if button == 1 and self.hoveredItemSlot then
            self.draggedItem = {
                itemId = self.hoveredItemSlot.itemId,
                itemDef = self.hoveredItemSlot.itemDef,
                slotIndex = self.hoveredItemSlot.slotIndex,
                count = self.hoveredItemSlot.count
            }
        end
    elseif self.activeTab == "skills" then
        -- Skills tab doesn't have interactive elements currently
    end

    WindowBase.mousepressed(self, x, y, button)
end

---@diagnostic disable-next-line: duplicate-set-field
function ShipWindow:mousereleased(x, y, button)
    if button == 1 then
        self.isDragging = false
    end

    -- Handle drag-and-drop release in loadout tab
    if self.activeTab == "loadout" and button == 1 and self.draggedItem then
        -- Get the player's controlled ship for cargo access
        local controllers = ECS.getEntitiesWith({"InputControlled", "Player"})
        if #controllers == 0 then
            self.draggedItem = nil
            WindowBase.mousereleased(self, x, y, button)
            return
        end
        local pilotId = controllers[1]
        local inputComp = ECS.getComponent(pilotId, "InputControlled")
        local shipId = inputComp and inputComp.targetEntity or nil
        if not shipId then
            self.draggedItem = nil
            WindowBase.mousereleased(self, x, y, button)
            return
        end

        local cargo = ECS.getComponent(shipId, "Cargo")
        if not cargo then
            self.draggedItem = nil
            WindowBase.mousereleased(self, x, y, button)
            return
        end

        -- Check if dropped on an equipment slot
        local equippedToSlot = false
        if self.equipmentSlots then
            for slotName, slotRect in pairs(self.equipmentSlots) do
                if x >= slotRect.x and x <= slotRect.x + slotRect.w and
                   y >= slotRect.y and y <= slotRect.y + slotRect.h then
                    -- Check if item is valid for this slot
                    local itemDef = self.draggedItem.itemDef
                    if (slotName == "Turret Module" and itemDef.type == "turret") or
                       (slotName == "Defensive Module" and string.match(self.draggedItem.itemId, "shield")) then
                        -- Equip the item
                        self:equipModule(self.draggedItem.itemId)
                        equippedToSlot = true
                        break
                    end
                end
            end
        end

        -- If not equipped and dropped outside window, destroy the item
        if not equippedToSlot then
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
    end

    WindowBase.mousereleased(self, x, y, button)
end

---@diagnostic disable-next-line: duplicate-set-field
function ShipWindow:mousemoved(x, y, dx, dy)
    WindowBase.mousemoved(self, x, y, dx, dy)
end

return ShipWindow