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
    width = 1100,
    height = 820,
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
    local CargoPanel = require('src.ui.cargo_panel')
    CargoPanel.drawCargoGrid(self, cargoItems, x, y, width, height, alpha)
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

    -- If no compatible slots, show a single disabled line
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
function ShipWindow:handleContextMenuClick(optionIndex)
    if not self.contextMenu or not self.contextMenu.options[optionIndex] then return end

    local option = self.contextMenu.options[optionIndex]
    if option.action == "equip" and option.slotType then
        -- Delegating to equipModule is sufficient; it will replace existing module and add it to cargo
        self:equipModule(self.contextMenu.itemId)
    end

    -- No-op for "noop" or other actions
    self.contextMenu = nil
end

-- Draw context menu for cargo items
function ShipWindow:drawContextMenu(x, y, alpha)
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

        if option.action == "equip" then
            love.graphics.setColor(0.15, 0.4, 0.15, alpha)
        elseif option.action == "noop" then
            love.graphics.setColor(Theme.colors.textSecondary[1] * 0.6, Theme.colors.textSecondary[2] * 0.6, Theme.colors.textSecondary[3] * 0.6, alpha)
        else
            love.graphics.setColor(Theme.colors.textPrimary[1], Theme.colors.textPrimary[2], Theme.colors.textPrimary[3], alpha)
        end

        love.graphics.printf(option.text, x + 8, optionY + 2, menuWidth - 16, "left")
    end
end

function ShipWindow:drawEquipmentSlot(slotName, equippedItemId, x, y, width, alpha, droneId)
    local LoadoutPanel = require('src.ui.loadout_panel')
    return LoadoutPanel.drawEquipmentSlot(self, slotName, equippedItemId, x, y, width, alpha, droneId)
end


function ShipWindow:unequipModule(slotType, itemId)
    local LoadoutPanel = require('src.ui.loadout_panel')
    return LoadoutPanel.unequipModule(self, slotType, itemId)
end


function ShipWindow:drawSkillsContent(windowX, windowY, alpha)
    SkillsPanelWrapper.draw(self, windowX, windowY, self.width - 20, self.height - Theme.window.topBarHeight - Theme.window.bottomBarHeight - TAB_HEIGHT - 20, alpha)
end

function ShipWindow:equipModule(itemId)
    local LoadoutPanel = require('src.ui.loadout_panel')
    return LoadoutPanel.equipModule(self, itemId)
end

-- Handle tab switching and delegate mouse events to appropriate tab content
---@diagnostic disable-next-line: duplicate-set-field
function ShipWindow:mousepressed(x, y, button)
    if not self.isOpen or not self.position then return end

    local uiX, uiY
    if Scaling._lastMouseUI and Scaling._lastMouseUI[1] then
        uiX, uiY = Scaling._lastMouseUI[1], Scaling._lastMouseUI[2]
    else
        uiX, uiY = x, y
    end

    -- Check for tab clicks first (UI-space coords) - compute deterministically so clicks work even if not drawn yet
    do
        local windowX, windowY = self.position.x, self.position.y
        local tabY = windowY + Theme.window.topBarHeight
        local tabWidth = self.width / #self.tabs
        if uiY >= tabY and uiY <= tabY + TAB_HEIGHT and uiX >= windowX and uiX <= windowX + self.width then
            local relX = uiX - windowX
            local idx = math.floor(relX / tabWidth) + 1
            local tabKey = self.tabs[idx]
            if tabKey then
                self.activeTab = tabKey
                return
            end
        end
    end

    -- Close context menu if right-clicking outside of it (UI-space coords)
    if button == 2 and self.contextMenu then
            local cmW = (self.contextMenu and self.contextMenu.width) or 200
            local cmH = (self.contextMenu and self.contextMenu.height) or (8 + (#self.contextMenu.options * 24))
            if not (uiX >= self.contextMenu.x and uiX <= self.contextMenu.x + cmW and
                uiY >= self.contextMenu.y and uiY <= self.contextMenu.y + cmH) then
            self.contextMenu = nil
        end
    end

    if self.activeTab == "loadout" then
        if LoadoutPanel and LoadoutPanel.mousepressed then LoadoutPanel.mousepressed(self, x, y, button) end
    elseif self.activeTab == "cargo" then
        if CargoPanel and CargoPanel.mousepressed then CargoPanel.mousepressed(self, x, y, button) end
    elseif self.activeTab == "skills" then
        if SkillsPanelWrapper and SkillsPanelWrapper.mousepressed then SkillsPanelWrapper.mousepressed(self, x, y, button) end
    end

    WindowBase.mousepressed(self, x, y, button)
end

---@diagnostic disable-next-line: duplicate-set-field
function ShipWindow:mousereleased(x, y, button)
    -- Handle context menu clicks
    if button == 1 and self.contextMenu and self.contextMenu.hoveredOption then
        self:handleContextMenuClick(self.contextMenu.hoveredOption)
        return -- Don't process as regular click
    end

    if self.activeTab == "loadout" then
        if LoadoutPanel and LoadoutPanel.mousereleased then LoadoutPanel.mousereleased(self, x, y, button) end
    elseif self.activeTab == "cargo" then
        if CargoPanel and CargoPanel.mousereleased then CargoPanel.mousereleased(self, x, y, button) end
    elseif self.activeTab == "skills" then
        if SkillsPanelWrapper and SkillsPanelWrapper.mousereleased then SkillsPanelWrapper.mousereleased(self, x, y, button) end
    end

    WindowBase.mousereleased(self, x, y, button)
end

---@diagnostic disable-next-line: duplicate-set-field
function ShipWindow:mousemoved(x, y, dx, dy)
    -- Handle context menu hover detection
    if self.contextMenu then
        local uiX, uiY
        if Scaling._lastMouseUI and Scaling._lastMouseUI[1] then
            uiX, uiY = Scaling._lastMouseUI[1], Scaling._lastMouseUI[2]
        else
            uiX, uiY = x, y
        end
        
        local menuX = self.contextMenu.x
        local menuY = self.contextMenu.y
        local menuWidth = (self.contextMenu and self.contextMenu.width) or 200
        local menuHeight = (self.contextMenu and self.contextMenu.height) or (8 + (#self.contextMenu.options * 24))

        if uiX >= menuX and uiX <= menuX + menuWidth and uiY >= menuY and uiY <= menuY + menuHeight then
            -- Mouse is over context menu, determine which option
            local optionY = menuY + 8
            local optionHeight = 24
            local optionIndex = math.floor((uiY - optionY) / optionHeight) + 1

            if optionIndex >= 1 and optionIndex <= #self.contextMenu.options then
                self.contextMenu.hoveredOption = optionIndex
            else
                self.contextMenu.hoveredOption = nil
            end
        else
            self.contextMenu.hoveredOption = nil
        end
    end

    if self.activeTab == "loadout" then
        if LoadoutPanel and LoadoutPanel.mousemoved then LoadoutPanel.mousemoved(self, x, y, dx, dy) end
    elseif self.activeTab == "cargo" then
        if CargoPanel and CargoPanel.mousemoved then CargoPanel.mousemoved(self, x, y, dx, dy) end
    elseif self.activeTab == "skills" then
        if SkillsPanelWrapper and SkillsPanelWrapper.mousemoved then SkillsPanelWrapper.mousemoved(self, x, y, dx, dy) end
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

-- Handle mouse wheel for scrolling within the ship window (stat area)
function ShipWindow:wheelmoved(x, y)
    if not self.isOpen then return false end
    return false
end

return ShipWindow
