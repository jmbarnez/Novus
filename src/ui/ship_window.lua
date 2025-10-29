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
local ContextMenu = require('src.ui.context_menu')

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

    if not self.position then return end

    local alpha = self.animAlpha or 0
    if alpha <= 0 then return end

    -- Window variables are in reference/UI space (1920x1080)
    local x = self.position.x
    local y = self.position.y
    local w = self.width
    local h = self.height

    -- Draw close button
    self:drawCloseButton(x, y, alpha, uiMx, uiMy)

    -- Draw tab headers
    self:drawSectionButtons(x, y, alpha)

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

    -- Draw context menu if open
    if ContextMenu.isOpen() then
        ContextMenu.draw(alpha)
    end
end

-- Keep ship tabs compact even if the theme sets a taller default
local NAV_BUTTON_HEIGHT = math.min(Theme.window.tabHeight or 60, 42)

function ShipWindow:drawSectionButtons(windowX, windowY, alpha)
    local tabY = windowY + Theme.window.topBarHeight
    local tabWidth = self.width / #self.tabs
    local mx, my
    if Scaling._lastMouseUI and Scaling._lastMouseUI[1] then
        mx, my = Scaling._lastMouseUI[1], Scaling._lastMouseUI[2]
    else
        mx, my = Scaling.toUI(love.mouse.getPosition())
    end

    self.tabButtons = {}

    local font = Theme.getFontBold(Theme.fonts.normal)
    for i, tabKey in ipairs(self.tabs) do
        local tabX = windowX + (i - 1) * tabWidth
        local isHovered = mx >= tabX and mx <= tabX + tabWidth and my >= tabY and my <= tabY + NAV_BUTTON_HEIGHT
        local isActive = self.activeTab == tabKey and not isHovered

        local baseColor = isActive and Theme.colors.hover or Theme.colors.surfaceAlt
        local hoverColor = Theme.colors.hover
        Theme.drawButton(tabX, tabY, tabWidth, NAV_BUTTON_HEIGHT, self.tabNames[tabKey], isHovered, baseColor, hoverColor, {
            font = font,
            textColor = Theme.colors.text,
        })

        table.insert(self.tabButtons, {
            x = tabX, y = tabY, w = tabWidth, h = NAV_BUTTON_HEIGHT,
            tabKey = tabKey
        })
    end

    local borderColor = Theme.colors.border
    love.graphics.setColor(borderColor[1], borderColor[2], borderColor[3], (borderColor[4] or 1) * alpha)
    love.graphics.line(windowX, tabY + NAV_BUTTON_HEIGHT, windowX + self.width, tabY + NAV_BUTTON_HEIGHT)
end

-- Draw bottom status bar with credits and cargo info
function ShipWindow:drawBottomBar(windowX, windowY, alpha)
    local x = windowX
    local y = windowY + self.height - Theme.window.bottomBarHeight
    local w = self.width
    local h = Theme.window.bottomBarHeight
    local padding = Theme.spacing.sm

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
    love.graphics.setColor(Theme.colors.text[1], Theme.colors.text[2], Theme.colors.text[3], alpha)
    love.graphics.print(creditsText, x + padding, textY)

    -- Draw right side: Cargo capacity
    local cargoText = string.format("Cargo: %.2f/%.2f m^3", currentVolume, maxCapacity)
    love.graphics.setColor(Theme.colors.text[1], Theme.colors.text[2], Theme.colors.text[3], alpha)
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

    ContextMenu.open({
        itemId = itemId,
        itemDef = itemDef,
        x = x,
        y = y,
        options = options
    }, function(option)
        if option.action == "equip" then
            -- Delegate to ShipWindow:equipModule (keeps original behaviour)
            self:equipModule(itemId)
        end
    end)
end

-- Handle context menu option clicks
-- Context menu drawing and input handling delegated to `src.ui.context_menu`

function ShipWindow:drawEquipmentSlot(slotName, equippedItemId, x, y, width, alpha, droneId)
    local LoadoutPanel = require('src.ui.loadout_panel')
    return LoadoutPanel.drawEquipmentSlot(self, slotName, equippedItemId, x, y, width, alpha, droneId)
end


function ShipWindow:unequipModule(slotType, itemId)
    local LoadoutPanel = require('src.ui.loadout_panel')
    return LoadoutPanel.unequipModule(self, slotType, itemId)
end


function ShipWindow:drawSkillsContent(windowX, windowY, alpha)
    SkillsPanelWrapper.draw(self, windowX, windowY, self.width - 20, self.height - Theme.window.topBarHeight - Theme.window.bottomBarHeight - 20, alpha)
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
        if uiY >= tabY and uiY <= tabY + NAV_BUTTON_HEIGHT and uiX >= windowX and uiX <= windowX + self.width then
            local relX = uiX - windowX
            local idx = math.floor(relX / tabWidth) + 1
            local tabKey = self.tabs[idx]
            if tabKey then
                self.activeTab = tabKey
                return
            end
        end
    end

    -- Close context menu if clicking outside of it (any button)
    if ContextMenu.isOpen() then
        local menu = ContextMenu.getMenu()
        local cmW = menu.width or 200
        local cmH = menu.height or ((menu.paddingY or 12) * 2 + (#menu.options * (menu.optionHeight or 24)))
        if not (uiX >= menu.x and uiX <= menu.x + cmW and
            uiY >= menu.y and uiY <= menu.y + cmH) then
            ContextMenu.close()
            return
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
    if button == 1 and ContextMenu.isOpen() then
        local uiX, uiY
        if Scaling._lastMouseUI and Scaling._lastMouseUI[1] then
            uiX, uiY = Scaling._lastMouseUI[1], Scaling._lastMouseUI[2]
        else
            uiX, uiY = Scaling.toUI(x, y)
        end

        if ContextMenu.handleClickAt(uiX, uiY) then
            return
        end

        -- If click wasn't on a selectable option, close the menu
        return
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
    if ContextMenu.isOpen() then
        local uiX, uiY
        if Scaling._lastMouseUI and Scaling._lastMouseUI[1] then
            uiX, uiY = Scaling._lastMouseUI[1], Scaling._lastMouseUI[2]
        else
            uiX, uiY = x, y
        end
        ContextMenu.mousemoved(uiX, uiY)
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
    if key == "escape" and ContextMenu.isOpen() then
        ContextMenu.close()
        return true
    end
    if self.activeTab == "cargo" then
        local CargoPanel = require('src.ui.cargo_panel')
        if CargoPanel and CargoPanel.keypressed then
            local consumed = CargoPanel.keypressed(self, key)
            if consumed then
                return true
            end
        end
    end

    WindowBase.keypressed(self, key)
    return false
end

function ShipWindow:textinput(t)
    if self.activeTab == "cargo" then
        local CargoPanel = require('src.ui.cargo_panel')
        if CargoPanel and CargoPanel.textinput then
            local consumed = CargoPanel.textinput(self, t)
            if consumed then
                return true
            end
        end
    end
    return false
end

-- Handle mouse wheel for scrolling within the ship window (stat area)
function ShipWindow:wheelmoved(x, y)
    if not self.isOpen then return false end
    return false
end

return ShipWindow
