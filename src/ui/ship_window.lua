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
    local contentX = windowX + 10
    local contentY = windowY + Theme.window.topBarHeight + TAB_HEIGHT + 10
    local contentWidth = self.width - 20
    local contentHeight = self.height - Theme.window.topBarHeight - Theme.window.bottomBarHeight - TAB_HEIGHT - 20

    -- Reset hovered items
    self.hoveredItemSlot = nil
    self.hoveredEquipmentSlot = nil

    -- Get ship equipment and cargo
    local pilotEntities = ECS.getEntitiesWith({"Player", "InputControlled"})
    if #pilotEntities == 0 then return end
    local pilotId = pilotEntities[1]
    local input = ECS.getComponent(pilotId, "InputControlled")
    if not input or not input.targetEntity then return end
    local droneId = input.targetEntity

    local turretSlots = ECS.getComponent(droneId, "TurretSlots")
    local defensiveSlots = ECS.getComponent(droneId, "DefensiveSlots")
    local generatorSlots = ECS.getComponent(droneId, "GeneratorSlots")
    local cargo = ECS.getComponent(droneId, "Cargo")
    local hull = ECS.getComponent(droneId, "Hull")
    local shield = ECS.getComponent(droneId, "Shield")
    local polygonShape = ECS.getComponent(droneId, "PolygonShape")
    local position = ECS.getComponent(droneId, "Position")

    -- Use the full content area for stats + equipment (no right-side cargo in this tab)
    local leftPanelWidth = contentWidth

    -- LEFT PANEL: Ship Stats and Equipment
    local slotSize = Theme.spacing.slotSize
    local slotPadding = Theme.spacing.iconGridPadding
    local sectionHeight = 95  -- Height for each stat section

    -- Get all stats first
    local Constants = require('src.constants')
    local physics = ECS.getComponent(droneId, "Physics")
    local mass = physics and physics.mass or 1
    local baseMaxVelocity = Constants.player_max_speed
    local maxVelocity = baseMaxVelocity / mass
    local acceleration = maxVelocity / 2.0
    
    local totalEffectiveHP = (hull and hull.max or 0) + (shield and shield.max or 0)
    local survivalTime = 0
    if totalEffectiveHP > 0 then
        local typicalEnemyDPS = 5
        survivalTime = totalEffectiveHP / typicalEnemyDPS
    end
    
    local turret = ECS.getComponent(droneId, "Turret")
    local turretDPS = 0
    local turretRange = 0
    local turretCooldown = 0
    local effectiveDPS = 0
    
    if turret and turret.moduleName and turret.moduleName ~= "" then
        local turretModule = TurretRegistry.getModule(turret.moduleName)
        if turretModule then
            turretDPS = turretModule.DPS or 0
            turretRange = turretModule.RANGE or 0
            
            if turretModule.CONTINUOUS then
                effectiveDPS = turretDPS
            else
                turretCooldown = turretModule.COOLDOWN or 1
                effectiveDPS = turretDPS / turretCooldown
            end
        end
    end
    
    -- Helper function to draw a stat section
    local function drawStatSection(sectionY, label, stats)
        local sectionX = contentX + 10
        local boxWidth = leftPanelWidth - 20
        local boxHeight = sectionHeight - 8
        
        -- Section background with subtle border
        love.graphics.setColor(Theme.colors.bgDark[1], Theme.colors.bgDark[2], Theme.colors.bgDark[3], alpha * 0.4)
        love.graphics.rectangle("fill", sectionX, sectionY, boxWidth, boxHeight, 3, 3)
        love.graphics.setColor(Theme.colors.borderMedium[1], Theme.colors.borderMedium[2], Theme.colors.borderMedium[3], alpha * 0.2)
        love.graphics.rectangle("line", sectionX, sectionY, boxWidth, boxHeight, 3, 3)
        
        -- Section label
        love.graphics.setFont(Theme.getFont(Theme.fonts.small))
        love.graphics.setColor(Theme.colors.textAccent[1], Theme.colors.textAccent[2], Theme.colors.textAccent[3], alpha)
        love.graphics.printf(label, sectionX + 5, sectionY + 8, boxWidth - 10, "left")
        
        -- Stats
        love.graphics.setFont(Theme.getFont(Theme.fonts.tiny))
        love.graphics.setColor(Theme.colors.textSecondary[1], Theme.colors.textSecondary[2], Theme.colors.textSecondary[3], alpha)
        
        local statY = sectionY + 26
        for i, stat in ipairs(stats) do
            love.graphics.printf(stat, sectionX + 8, statY, boxWidth - 16, "left")
            statY = statY + 16
        end
    end
    
    -- SECTION 1: Combat
    drawStatSection(contentY, "COMBAT", {
        string.format("Damage: %.0f", turretDPS),
        string.format("DPS: %.1f", effectiveDPS),
        string.format("Range: %d", turretRange)
    })
    
    -- SECTION 2: Survival
    local survivalStats = {
        string.format("Eff. HP: %d", totalEffectiveHP),
    }
    if shield and shield.max > 0 then
        table.insert(survivalStats, string.format("Shield: +%d", shield.max))
        table.insert(survivalStats, string.format("Regen: %.1f/s", shield.regenRate or 0))
    end
    table.insert(survivalStats, string.format("Uptime: ~%.0fs", survivalTime))
    
    drawStatSection(contentY + sectionHeight, "SURVIVAL", survivalStats)
    
    -- SECTION 3: Movement
    drawStatSection(contentY + sectionHeight * 2, "MOVEMENT", {
        string.format("Max Vel: %.0f u/s", maxVelocity),
        string.format("Accel: %.0f u/s²", acceleration),
        string.format("Mass: %.1f", mass)
    })
    
    -- EQUIPMENT SLOTS at bottom
    local equipmentY = contentY + sectionHeight * 3 + 10
    
    -- Turret Slot
    love.graphics.setFont(Theme.getFont(Theme.fonts.tiny))
    love.graphics.setColor(Theme.colors.textSecondary[1], Theme.colors.textSecondary[2], Theme.colors.textSecondary[3], alpha * 0.7)
    love.graphics.printf("TURRET", contentX + 10, equipmentY, leftPanelWidth - 20, "left")
    self:drawEquipmentSlot("Turret Module", turretSlots and turretSlots.slots[1], contentX + (leftPanelWidth - slotSize) / 2, equipmentY + 12, slotSize, alpha, droneId)
    
    -- Defensive Slot
    local defenseY = equipmentY + slotSize + 12
    love.graphics.setColor(Theme.colors.textSecondary[1], Theme.colors.textSecondary[2], Theme.colors.textSecondary[3], alpha * 0.7)
    love.graphics.printf("DEFENSE", contentX + 10, defenseY, leftPanelWidth - 20, "left")
    self:drawEquipmentSlot("Defensive Module", defensiveSlots and defensiveSlots.slots[1], contentX + (leftPanelWidth - slotSize) / 2, defenseY + 12, slotSize, alpha, droneId)
    
    -- Generator Slot
    local generatorY = defenseY + slotSize + 12
    love.graphics.setColor(Theme.colors.textSecondary[1], Theme.colors.textSecondary[2], Theme.colors.textSecondary[3], alpha * 0.7)
    love.graphics.printf("GENERATOR", contentX + 10, generatorY, leftPanelWidth - 20, "left")
    self:drawEquipmentSlot("Generator Module", generatorSlots and generatorSlots.slots[1], contentX + (leftPanelWidth - slotSize) / 2, generatorY + 12, slotSize, alpha, droneId)

    -- (Cargo is intentionally not drawn here; use the Cargo tab for full cargo view)

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
    local contentX = windowX + 10
    local contentY = windowY + Theme.window.topBarHeight + TAB_HEIGHT + 10
    local contentWidth = self.width - 20
    local contentHeight = self.height - Theme.window.topBarHeight - Theme.window.bottomBarHeight - TAB_HEIGHT - 20

    -- Get player and cargo
    local pilotEntities = ECS.getEntitiesWith({"Player", "InputControlled"})
    if #pilotEntities == 0 then return end
    local pilotId = pilotEntities[1]
    local input = ECS.getComponent(pilotId, "InputControlled")
    if not input or not input.targetEntity then return end
    local droneId = input.targetEntity
    local cargo = ECS.getComponent(droneId, "Cargo")
    if not cargo then return end

    -- Draw a full-area cargo grid
    self.hoveredItemSlot = nil
    self:drawCargoGrid(cargo.items, contentX, contentY, contentWidth, contentHeight, alpha)

    -- Draw context menu if active
    if self.contextMenu then
        self:drawContextMenu(self.contextMenu.x, self.contextMenu.y, alpha)
    end
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
    local mx, my = Scaling.toUI(love.mouse.getPosition())
    
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

    -- Close context menu if right-clicking outside of it
    if button == 2 and self.contextMenu then
        local mx, my = Scaling.toUI(x, y)
        if not (mx >= self.contextMenu.x and mx <= self.contextMenu.x + 200 and
                my >= self.contextMenu.y and my <= self.contextMenu.y + 40 + (#self.contextMenu.options * 25)) then
            self.contextMenu = nil
        end
    end

    -- Delegate mouse events to the appropriate tab content
    if self.activeTab == "loadout" then
        -- Left click: start dragging from cargo or equipment slots
        if button == 1 then
            if self.hoveredItemSlot then
                -- Dragging from cargo
                self.draggedItem = {
                    itemId = self.hoveredItemSlot.itemId,
                    itemDef = self.hoveredItemSlot.itemDef,
                    slotIndex = self.hoveredItemSlot.slotIndex,
                    count = self.hoveredItemSlot.count,
                    fromEquipment = false
                }
            elseif self.hoveredEquipmentSlot then
                -- Dragging from equipment slot
                local ItemDefs = require('src.items.item_loader')
                local itemDef = ItemDefs[self.hoveredEquipmentSlot.itemId]
                if itemDef then
                    self.draggedItem = {
                        itemId = self.hoveredEquipmentSlot.itemId,
                        itemDef = itemDef,
                        slotName = self.hoveredEquipmentSlot.slotName,
                        fromEquipment = true
                    }
                end
            end
        -- Right click: remove from equipment slot
        elseif button == 2 and self.hoveredEquipmentSlot then
            self:unequipModule(self.hoveredEquipmentSlot.slotName, self.hoveredEquipmentSlot.itemId)
        end
    elseif self.activeTab == "cargo" then
        -- Right click: open context menu for cargo items (only if no existing context menu)
        if button == 2 and self.hoveredItemSlot and not self.contextMenu then
            self:openContextMenu(self.hoveredItemSlot.itemId, self.hoveredItemSlot.itemDef, x, y)
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

    -- Handle context menu clicks
    if self.contextMenu and button == 1 then
        local mx, my = Scaling.toUI(x, y)
        if mx >= self.contextMenu.x and mx <= self.contextMenu.x + 200 and
           my >= self.contextMenu.y and my <= self.contextMenu.y + 40 + (#self.contextMenu.options * 25) then
            -- Find which option was clicked
            local optionIndex = math.floor((my - self.contextMenu.y - 40) / 25) + 1
            if optionIndex >= 1 and optionIndex <= #self.contextMenu.options then
                self:handleContextMenuClick(optionIndex)
                return
            end
        end
        -- Click outside menu - close it
        self.contextMenu = nil
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
                       (slotName == "Defensive Module" and string.match(self.draggedItem.itemId, "shield")) or
                       (slotName == "Generator Module" and itemDef.type == "generator") then
                        -- If dragging from equipment slot, unequip first
                        if self.draggedItem.fromEquipment and self.draggedItem.slotName then
                            self:unequipModule(self.draggedItem.slotName, self.draggedItem.itemId)
                        end
                        -- Equip the item
                        self:equipModule(self.draggedItem.itemId)
                        equippedToSlot = true
                        break
                    end
                end
            end
        end

        -- If not equipped
        if not equippedToSlot then
            local windowX, windowY = self.position.x, self.position.y
            local windowW, windowH = self.width, self.height
            local isOutsideBounds = x < windowX or x > windowX + windowW or y < windowY or y > windowY + windowH

            if self.draggedItem.fromEquipment then
                -- Dragging from equipment slot: return to cargo if not dropped outside
                if not isOutsideBounds then
                    -- Unequip the module and return to cargo
                    if self.draggedItem.slotName then
                        self:unequipModule(self.draggedItem.slotName, self.draggedItem.itemId)
                    end
                else
                    -- Dropped outside window - destroy the item
                    if self.draggedItem.slotName then
                        self:unequipModule(self.draggedItem.slotName, self.draggedItem.itemId)
                        -- Remove from cargo
                        local itemId = self.draggedItem.itemId
                        if cargo and cargo.items and cargo.items[itemId] then
                            cargo.items[itemId] = cargo.items[itemId] - 1
                            if cargo.items[itemId] <= 0 then
                                cargo.items[itemId] = nil
                            end
                        end
                    end
                end
            else
                -- Dragging from cargo: destroy if dropped outside window
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
        end

        self.draggedItem = nil
    end

    WindowBase.mousereleased(self, x, y, button)
end

---@diagnostic disable-next-line: duplicate-set-field
function ShipWindow:mousemoved(x, y, dx, dy)
    -- Handle context menu hover detection
    if self.contextMenu then
        local mx, my = Scaling.toUI(x, y)
        if mx >= self.contextMenu.x and mx <= self.contextMenu.x + 200 and
           my >= self.contextMenu.y and my <= self.contextMenu.y + 40 + (#self.contextMenu.options * 25) then
            -- Find which option is hovered
            local optionIndex = math.floor((my - self.contextMenu.y - 40) / 25) + 1
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
function ShipWindow:keypressed(key)
    -- Close context menu on escape
    if key == "escape" and self.contextMenu then
        self.contextMenu = nil
        return
    end

    WindowBase.keypressed(self, key)
end


return ShipWindow