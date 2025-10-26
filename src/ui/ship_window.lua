---@diagnostic disable: undefined-global
-- UI Ship Window Module - Tabbed container for Ship/Cargo/Skills windows
-- Derives from WindowBase for universal effects (neon border, fade, elasticity)

local Constants = require('src.constants')
local ECS = require('src.ecs')
local Components = require('src.components')
local TurretRegistry = require('src.turret_registry')
local Theme = require('src.ui.theme')
local WindowBase = require('src.ui.window_base')
local Scaling = require('src.scaling')

-- Import the skills panel module
local SkillsPanel = require('src.ui.skills_panel')
local LoadoutPanel = require('src.ui.loadout_panel')
local CargoPanel = require('src.ui.cargo_panel')
local SkillsPanelWrapper = require('src.ui.skills_panel_wrapper')

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
    isOpen = false
}

-- Initialize tab management fields
ShipWindow.activeTab = "loadout" -- "loadout", "cargo", "skills"
ShipWindow.tabs = {"loadout", "cargo", "skills"}
ShipWindow.tabNames = {
    loadout = "Loadout",
    cargo = "Cargo",
    skills = "Skills"
}
ShipWindow.tabButtons = {}

-- Initialize cargo and skills state
ShipWindow.draggedItem = nil
ShipWindow.hoveredItemSlot = nil
ShipWindow.hoveredEquipmentSlot = nil
ShipWindow.contextMenu = nil  -- {itemId, itemDef, x, y, options}

-- Public interface for toggling
function ShipWindow:toggle()
    self:setOpen(not self.isOpen)
end

function ShipWindow:getOpen()
    return self.isOpen
end

-- Override draw to add tabbed ship-specific content on top of universal window
---@diagnostic disable-next-line: duplicate-set-field
function ShipWindow:draw(viewportWidth, viewportHeight, uiMx, uiMy)
    -- Draw base window (background, top/bottom bars, dividers)
    WindowBase.draw(self, uiMx, uiMy)

    -- Only draw when open
    if not self.isOpen then return end

    local alpha = 1

    -- Window variables are in reference/UI space (1920x1080)
    local x = self.position.x
    local y = self.position.y
    local w = self.width
    local h = self.height

    -- Draw close button
    self:drawCloseButton(x, y, alpha, uiMx, uiMy)

    -- Draw tab headers
    self:drawTabHeaders(x, y, alpha)

    -- Draw content based on active tab by delegating to respective window objects
    if self.activeTab == "loadout" then
        self:drawLoadoutContent(x, y, alpha)
    elseif self.activeTab == "cargo" then
        self:drawCargoContent(x, y, alpha)
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
    local mx, my
    if Scaling._lastMouseUI and Scaling._lastMouseUI[1] then
        mx, my = Scaling._lastMouseUI[1], Scaling._lastMouseUI[2]
    else
        mx, my = Scaling.toUI(love.mouse.getPosition())
    end

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
    local currentVolume = cargo and cargo.currentVolume or 0
    local maxCapacity = cargo and cargo.capacity or 0

    love.graphics.setFont(Theme.getFont(Theme.fonts.normal))
    local fontHeight = love.graphics.getFont():getHeight()
    local textY = y + (h - fontHeight) / 2

    -- Draw left side: Credits
    local creditsText = wallet and string.format("Credits: %d", wallet.credits) or "Credits: 0"
    love.graphics.setColor(Theme.colors.textPrimary[1], Theme.colors.textPrimary[2], Theme.colors.textPrimary[3], alpha)
    love.graphics.print(creditsText, x + padding, textY)

    -- Draw right side: Cargo capacity
    local cargoText = string.format("Cargo: %.2f/%.2f m³", currentVolume, maxCapacity)
    love.graphics.setColor(Theme.colors.textPrimary[1], Theme.colors.textPrimary[2], Theme.colors.textPrimary[3], alpha)
    love.graphics.printf(cargoText, x + padding, textY, w - padding * 2, "right")
end

-- Draw the combined equipment + cargo view side-by-side
function ShipWindow:drawLoadoutContent(windowX, windowY, alpha)
    -- Delegate to LoadoutPanel
    LoadoutPanel.draw(self, windowX, windowY, self.width, self.height, alpha)
end

-- Draw the cargo grid showing all items
function ShipWindow:drawCargoGrid(cargoItems, x, y, width, height, alpha)
    local ItemDefs = require('src.items.item_loader')
    local slotSize = Theme.spacing.slotSize
    local padding = Theme.spacing.iconGridPadding
    local cols = math.max(1, math.floor(width / (slotSize + padding)))
    local mx, my
    if Scaling._lastMouseUI and Scaling._lastMouseUI[1] then
        mx, my = Scaling._lastMouseUI[1], Scaling._lastMouseUI[2]
    else
        mx, my = Scaling.toUI(love.mouse.getPosition())
    end

    local i = 0

    for itemId, count in pairs(cargoItems) do
        local itemDef = ItemDefs[itemId]
        if itemDef then
            local row = math.floor(i / cols)
            local col = i % cols
            local slotX = x + col * (slotSize + padding)
            local slotY = y + row * (slotSize + padding)

            -- Removed clipping: allow drawing all items, even if they overflow

            -- Check if hovering over slot
            local isHoveringSlot = mx >= slotX and mx <= slotX + slotSize and my >= slotY and my <= slotY + slotSize

            if isHoveringSlot then
                self.hoveredItemSlot = {itemId = itemId, itemDef = itemDef, count = count, mouseX = mx, mouseY = my, slotIndex = i}
            end

            -- Draw slot background with subtle compatibility indicator
            local compatibleSlots = self:getCompatibleSlots(itemId)
            if #compatibleSlots > 0 then
                -- Subtle green tint for compatible items
                love.graphics.setColor(0.1, 0.25, 0.1, alpha * 0.4)
                love.graphics.rectangle("fill", slotX - 1, slotY - 1, slotSize + 2, slotSize + 2, 5, 5)
                love.graphics.setColor(Theme.colors.bgDark[1], Theme.colors.bgDark[2], Theme.colors.bgDark[3], alpha * 0.8)
            else
                love.graphics.setColor(Theme.colors.bgDark[1], Theme.colors.bgDark[2], Theme.colors.bgDark[3], alpha * 0.8)
            end
            love.graphics.rectangle("fill", slotX, slotY, slotSize, slotSize, 4, 4)

            -- Hover highlight (shows over the subtle tint)
            if isHoveringSlot then
                -- Highlight always gray
                love.graphics.setColor(Theme.colors.bgLight[1], Theme.colors.bgLight[2], Theme.colors.bgLight[3], 0.32 * alpha)
                love.graphics.rectangle("fill", slotX, slotY, slotSize, slotSize, 4, 4)
            end

            -- Draw slot border with subtle green for compatible items
            if #compatibleSlots > 0 then
                love.graphics.setColor(0.15, 0.35, 0.15, alpha * 0.6)
            else
                love.graphics.setColor(Theme.colors.borderMedium[1], Theme.colors.borderMedium[2], Theme.colors.borderMedium[3], alpha * 0.3)
            end
            love.graphics.rectangle("line", slotX, slotY, slotSize, slotSize, 4, 4)

            -- Draw item icon
            love.graphics.push()
            love.graphics.translate(slotX + slotSize / 2, slotY + slotSize / 2)
            love.graphics.scale(1, 1)
            if type(itemDef.module) == "table" and itemDef.module.draw then
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

            -- Draw item name centered at bottom of the slot
            love.graphics.setColor(Theme.colors.textPrimary[1], Theme.colors.textPrimary[2], Theme.colors.textPrimary[3], alpha)
            love.graphics.setFont(Theme.getFont(Theme.fonts.small))
            local label = (itemDef and itemDef.name) or tostring(itemId)
            love.graphics.printf(label, slotX, slotY + slotSize + 4, slotSize, "center")

            i = i + 1
        end
    end
end


-- Check if item can be equipped in a specific slot type
function ShipWindow:canEquipInSlot(itemId, slotType)
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
function ShipWindow:getCompatibleSlots(itemId)
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

-- New: drawCargoContent uses the full content area for cargo listing
function ShipWindow:drawCargoContent(windowX, windowY, alpha)
    CargoPanel.draw(self, windowX, windowY, self.width, self.height, alpha)
end

-- Open context menu for cargo items
function ShipWindow:openContextMenu(itemId, itemDef, x, y)
    local compatibleSlots = self:getCompatibleSlots(itemId)
    local options = {}

    -- Add equip options for each compatible slot
    for _, slotType in ipairs(compatibleSlots) do
        table.insert(options, {
            text = "Equip to " .. slotType,
            action = "equip",
            slotType = slotType
        })
    end

    -- Add cancel option
    table.insert(options, {
        text = "Cancel",
        action = "cancel"
    })

    self.contextMenu = {
        itemId = itemId,
        itemDef = itemDef,
        x = x,
        y = y,
        options = options,
        hoveredOption = nil
    }
end

-- Handle context menu option clicks
function ShipWindow:handleContextMenuClick(optionIndex)
    if not self.contextMenu or not self.contextMenu.options[optionIndex] then return end

    local option = self.contextMenu.options[optionIndex]
    if option.action == "equip" and option.slotType then
        self:equipModule(self.contextMenu.itemId)
    end

    self.contextMenu = nil
end

-- Draw context menu for cargo items
function ShipWindow:drawContextMenu(x, y, alpha)
    local menuWidth = 200
    local menuHeight = 40 + (#self.contextMenu.options * 25)
    local itemDef = self.contextMenu.itemDef

    -- Background
    love.graphics.setColor(Theme.colors.bgDark[1], Theme.colors.bgDark[2], Theme.colors.bgDark[3], alpha * 0.95)
    love.graphics.rectangle("fill", x, y, menuWidth, menuHeight, 5, 5)

    -- Border
    love.graphics.setColor(Theme.colors.borderMedium[1], Theme.colors.borderMedium[2], Theme.colors.borderMedium[3], alpha)
    love.graphics.rectangle("line", x, y, menuWidth, menuHeight, 5, 5)

    -- Item name header
    love.graphics.setColor(Theme.colors.textAccent[1], Theme.colors.textAccent[2], Theme.colors.textAccent[3], alpha)
    love.graphics.setFont(Theme.getFont(Theme.fonts.small))
    local itemName = itemDef and itemDef.name or self.contextMenu.itemId
    love.graphics.printf(itemName, x + 8, y + 8, menuWidth - 16, "left")

    -- Compatibility indicator
    local compatibleSlots = self:getCompatibleSlots(self.contextMenu.itemId)
    if #compatibleSlots > 0 then
        love.graphics.setColor(Theme.colors.textSecondary[1], Theme.colors.textSecondary[2], Theme.colors.textSecondary[3], alpha)
        love.graphics.setFont(Theme.getFont(Theme.fonts.tiny))
        local compatText = "Compatible: " .. table.concat(compatibleSlots, ", ")
        love.graphics.printf(compatText, x + 8, y + 25, menuWidth - 16, "left")
    else
        love.graphics.setColor(Theme.colors.textSecondary[1] * 0.5, Theme.colors.textSecondary[2] * 0.5, Theme.colors.textSecondary[3] * 0.5, alpha)
        love.graphics.setFont(Theme.getFont(Theme.fonts.tiny))
        love.graphics.printf("No compatible slots", x + 8, y + 25, menuWidth - 16, "left")
    end

    -- Menu options
    love.graphics.setFont(Theme.getFont(Theme.fonts.small))
    for i, option in ipairs(self.contextMenu.options) do
        local optionY = y + 40 + (i-1) * 25
        local isHovered = self.contextMenu.hoveredOption == i

        -- Option background
        if isHovered then
            love.graphics.setColor(Theme.colors.bgMedium[1], Theme.colors.bgMedium[2], Theme.colors.bgMedium[3], alpha * 0.8)
            love.graphics.rectangle("fill", x + 5, optionY - 2, menuWidth - 10, 22, 3, 3)
        end

        -- Option text with color coding
        if option.action == "equip" then
            love.graphics.setColor(0.15, 0.4, 0.15, alpha)  -- Subtle green for equip options
        elseif option.action == "cancel" then
            love.graphics.setColor(Theme.colors.textSecondary[1], Theme.colors.textSecondary[2], Theme.colors.textSecondary[3], alpha)
        else
            love.graphics.setColor(Theme.colors.textPrimary[1], Theme.colors.textPrimary[2], Theme.colors.textPrimary[3], alpha)
        end
        love.graphics.printf(option.text, x + 8, optionY + 2, menuWidth - 16, "left")
    end
end

function ShipWindow:drawEquipmentSlot(slotName, equippedItemId, x, y, width, alpha, droneId)
    local slotSize = width
    local mx, my
    if Scaling._lastMouseUI and Scaling._lastMouseUI[1] then
        mx, my = Scaling._lastMouseUI[1], Scaling._lastMouseUI[2]
    else
        mx, my = Scaling.toUI(love.mouse.getPosition())
    end
    
    -- Check if hovering with a dragged item (for drop zone highlighting)
    local isDropZone = false
    if self.draggedItem and self.draggedItem.itemDef then
        local itemDef = self.draggedItem.itemDef
        -- Check if this item can be equipped in this slot
        if (slotName == "Turret Module" and itemDef.type == "turret") or
           (slotName == "Defensive Module" and string.match(self.draggedItem.itemId, "shield")) or
           (slotName == "Generator Module" and itemDef.type == "generator") then
            if mx >= x and mx <= x + width and my >= y and my <= y + slotSize then
                isDropZone = true
            end
        end
    end
    
    -- Check if hovering over this slot (and it has an equipped item)
    local isHoveringSlot = mx >= x and mx <= x + width and my >= y and my <= y + slotSize
    if isHoveringSlot and equippedItemId then
        self.hoveredEquipmentSlot = {
            slotName = slotName,
            itemId = equippedItemId,
            x = x,
            y = y,
            w = width,
            h = slotSize
        }
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
    self.equipmentSlots[slotName] = {x = x, y = y, w = slotSize, h = slotSize, slotType = slotName, itemId = equippedItemId}

    if equippedItemId then
        -- Show equipped item with icon
        local ItemDefs = require('src.items.item_loader')
        local itemDef = ItemDefs[equippedItemId]
        if itemDef then
            -- Highlight if hovering
            if isHoveringSlot then
                local color = (itemDef.module and itemDef.module.design and itemDef.module.design.color) or (itemDef.design and itemDef.design.color) or {0.7, 0.7, 0.8, 1}
                love.graphics.setColor(color[1] * 1.3, color[2] * 1.3, color[3] * 1.3, 0.3 * alpha)
                love.graphics.rectangle("fill", x, y, slotSize, slotSize, 4, 4)
            end
            
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
            -- Add to cargo with capacity checking
            cargo:addItem(itemId, 1)
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
            -- Add to cargo with capacity checking
            cargo:addItem(itemId, 1)
        end
    elseif slotType == "Generator Module" then
        local generatorSlots = ECS.getComponent(droneId, "GeneratorSlots")

        if generatorSlots and generatorSlots.slots[1] == itemId and cargo then
            -- Remove from slot
            generatorSlots.slots[1] = nil
            -- Unequip the module
            local ItemDefs = require('src.items.item_loader')
            local itemDef = ItemDefs[itemId]
            if itemDef and itemDef.module and itemDef.module.unequip then
                itemDef.module.unequip(droneId)
            end
            -- Add to cargo with capacity checking
            cargo:addItem(itemId, 1)
        end
    end
end


function ShipWindow:drawSkillsContent(windowX, windowY, alpha)
    SkillsPanelWrapper.draw(self, windowX, windowY, self.width - 20, self.height - Theme.window.topBarHeight - Theme.window.bottomBarHeight - TAB_HEIGHT - 20, alpha)
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
                cargo:addItem(oldModuleId, 1)
            end

            -- Equip the new module
            turretSlots.slots[1] = itemId
            if itemDef.module and itemDef.module.name then
                playerTurret.moduleName = itemDef.module.name
                -- Validate the module exists
                if not TurretRegistry.hasModule(playerTurret.moduleName) then
                    playerTurret.moduleName = nil
                end
            else
                playerTurret.moduleName = nil
            end

            -- Remove from cargo with volume checking
            cargo:removeItem(itemId, 1)
        end
    elseif string.match(itemId, "shield") then
        local defensiveSlots = ECS.getComponent(droneId, "DefensiveSlots")

        if defensiveSlots then
            -- If there's an old module, unequip it first
            local oldModuleId = defensiveSlots.slots[1]
            if oldModuleId then
                cargo:addItem(oldModuleId, 1)
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

            -- Remove from cargo with volume checking
            cargo:removeItem(itemId, 1)
        end
    elseif itemDef.type == "generator" then
        local generatorSlots = ECS.getComponent(droneId, "GeneratorSlots")

        if generatorSlots then
            -- If there's an old module, unequip it first
            local oldModuleId = generatorSlots.slots[1]
            if oldModuleId then
                cargo:addItem(oldModuleId, 1)
                -- Unequip the old module
                local oldItemDef = ItemDefs[oldModuleId]
                if oldItemDef and oldItemDef.module and oldItemDef.module.unequip then
                    oldItemDef.module.unequip(droneId)
                end
            end

            -- Equip the new module
            generatorSlots.slots[1] = itemId
            if itemDef.module and itemDef.module.equip then
                itemDef.module.equip(droneId)
            end

            -- Remove from cargo with volume checking
            cargo:removeItem(itemId, 1)
        end
    end
end

-- Handle tab switching and delegate mouse events to appropriate tab content
---@diagnostic disable-next-line: duplicate-set-field
function ShipWindow:mousepressed(x, y, button)
    if self.activeTab == "loadout" then
        LoadoutPanel.mousepressed(self, x, y, button)
    elseif self.activeTab == "cargo" then
        CargoPanel.mousepressed(self, x, y, button)
    elseif self.activeTab == "skills" then
        SkillsPanelWrapper.mousepressed(self, x, y, button)
    end

    WindowBase.mousepressed(self, x, y, button)
end

---@diagnostic disable-next-line: duplicate-set-field
function ShipWindow:mousereleased(x, y, button)
    if self.activeTab == "loadout" then
        LoadoutPanel.mousereleased(self, x, y, button)
    elseif self.activeTab == "cargo" then
        CargoPanel.mousereleased(self, x, y, button)
    elseif self.activeTab == "skills" then
        SkillsPanelWrapper.mousereleased(self, x, y, button)
    end

    WindowBase.mousereleased(self, x, y, button)
end

---@diagnostic disable-next-line: duplicate-set-field
function ShipWindow:mousemoved(x, y, dx, dy)
    if self.activeTab == "loadout" then
        LoadoutPanel.mousemoved(self, x, y, dx, dy)
    elseif self.activeTab == "cargo" then
        CargoPanel.mousemoved(self, x, y, dx, dy)
    elseif self.activeTab == "skills" then
        SkillsPanelWrapper.mousemoved(self, x, y, dx, dy)
    end

    WindowBase.mousemoved(self, x, y, dx, dy)
end

---@diagnostic disable-next-line: duplicate-set-field
function ShipWindow:keypressed(key)
    -- Close context menu on escape
    if key == "escape" and self.contextMenu then
        self.contextMenu = nil
        return
    end

    WindowBase.keypressed(self, key)
end


return ShipWindow