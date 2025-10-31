---@diagnostic disable: undefined-global
local WindowBase = require('src.ui.window_base')
local ContextMenu = require('src.ui.context_menu')
local ECS = require('src.ecs')
local Theme = require('src.ui.plasma_theme')
local Scaling = require('src.scaling')
local DragState = require('src.ui.drag_state')

local CargoWindow = WindowBase:new{
    width = 900,
    height = 650,
    isOpen = false
}

-- Helper function for point-in-rectangle test
local function pointInRect(px, py, rx, ry, rw, rh)
    return px >= rx and px <= rx + rw and py >= ry and py <= ry + rh
end

function CargoWindow.drawEmbedded(shipWin, windowX, windowY, width, height, alpha)
    return shipWin:drawCargoContent(windowX, windowY, width, height, alpha)
end

function CargoWindow.drawCargoGrid(shipWin, cargoItems, x, y, width, height, alpha)
    return shipWin:drawCargoGridInternal(cargoItems, x, y, width, height, alpha)
end

function CargoWindow.getCompatibleSlots(shipWin, itemId)
    return shipWin:getCompatibleSlotsInternal(itemId)
end

function CargoWindow.mousepressedEmbedded(shipWin, x, y, button)
    return shipWin:handleCargoMousepressed(x, y, button)
end
function CargoWindow.mousereleasedEmbedded(shipWin, x, y, button)
    return shipWin:handleCargoMousereleased(x, y, button)
end
function CargoWindow.mousemovedEmbedded(shipWin, x, y, dx, dy)
    return shipWin:handleCargoMousemoved(x, y, dx, dy)
end
function CargoWindow.keypressedEmbedded(shipWin, key)
    return shipWin:handleCargoKeypressed(key)
end
function CargoWindow.textinputEmbedded(shipWin, t)
    return shipWin:handleCargoTextinput(t)
end

-- Get compatible equipment slots for an item
function CargoWindow:getCompatibleSlots(itemId)
    return self:getCompatibleSlotsInternal(itemId)
end

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

-- Equip a module (delegates to LoadoutWindow when parented, or implements directly)
function CargoWindow:equipModule(itemId)
    if self.parentShipWindow and self.parentShipWindow.loadoutWindow then
        return self.parentShipWindow.loadoutWindow:equipModule(itemId)
    else
        -- Standalone mode: implement equip logic directly
        local pilotEntities = ECS.getEntitiesWith({"Player", "InputControlled"})
        if #pilotEntities == 0 then return false end
        local pilotId = pilotEntities[1]
        local input = ECS.getComponent(pilotId, "InputControlled")
        if not input or not input.targetEntity then return false end
        local droneId = input.targetEntity
        
        local ItemDefs = require('src.items.item_loader')
        local itemDef = ItemDefs[itemId]
        if not itemDef then return false end
        
        -- Determine slot type based on item type
        local slotType = nil
        if itemDef.type == "turret" then
            slotType = "Turret Module"
        elseif itemDef.type == "shield" or string.match(itemId, "shield") then
            slotType = "Defensive Module"
        elseif itemDef.type == "generator" then
            slotType = "Generator Module"
        else
            return false -- Can't equip this item
        end
        
        -- Get cargo to remove item from
        local cargo = ECS.getComponent(droneId, "Cargo")
        if not cargo then return false end
        
        -- Check if item exists in cargo
        if not cargo.items[itemId] or cargo.items[itemId] < 1 then
            return false
        end
        
        -- Handle unequipping existing item if slot is occupied
        if slotType == "Turret Module" then
            local turretSlots = ECS.getComponent(droneId, "TurretSlots")
            if turretSlots and turretSlots.slots and turretSlots.slots[1] then
                local oldItemId = turretSlots.slots[1]
                cargo:addItem(oldItemId, 1) -- Add old item back to cargo
            end
            turretSlots.slots[1] = itemId
            -- Also update Turret component
            local turret = ECS.getComponent(droneId, "Turret")
            if turret then
                turret.moduleName = itemId
            end
        elseif slotType == "Defensive Module" then
            local defensiveSlots = ECS.getComponent(droneId, "DefensiveSlots")
            if not defensiveSlots then return false end
            
            -- Unequip old defensive module if present
            if defensiveSlots.slots and defensiveSlots.slots[1] then
                local oldItemId = defensiveSlots.slots[1]
                local oldItemDef = ItemDefs[oldItemId]
                if oldItemDef and oldItemDef.module and oldItemDef.module.unequip then
                    oldItemDef.module.unequip(droneId)
                end
                cargo:addItem(oldItemId, 1)
            end
            
            -- Equip new defensive module
            defensiveSlots.slots[1] = itemId
            if itemDef.module and itemDef.module.equip then
                itemDef.module.equip(droneId)
            end
        elseif slotType == "Generator Module" then
            local generatorSlots = ECS.getComponent(droneId, "GeneratorSlots")
            if not generatorSlots then return false end
            
            -- Unequip old generator module if present
            if generatorSlots.slots and generatorSlots.slots[1] then
                local oldItemId = generatorSlots.slots[1]
                local oldItemDef = ItemDefs[oldItemId]
                if oldItemDef and oldItemDef.module and oldItemDef.module.unequip then
                    oldItemDef.module.unequip(droneId)
                end
                cargo:addItem(oldItemId, 1)
            end
            
            -- Equip new generator module
            generatorSlots.slots[1] = itemId
            if itemDef.module and itemDef.module.equip then
                itemDef.module.equip(droneId)
            end
        end
        
        -- Remove item from cargo
        cargo:removeItem(itemId, 1)
        
        return true
    end
end

-- Open context menu for cargo items
function CargoWindow:openContextMenu(itemId, itemDef, x, y)
    -- If parented, forward to parent
    if self.parentShipWindow and self.parentShipWindow.openContextMenu then
        return self.parentShipWindow:openContextMenu(itemId, itemDef, x, y)
    end
    
    -- Standalone mode: implement context menu
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
            self:equipModule(itemId)
        end
    end)
end

function CargoWindow:handleContextMenuClick(optionIndex)
    if self.parentShipWindow and self.parentShipWindow.handleContextMenuClick then
        return self.parentShipWindow:handleContextMenuClick(optionIndex)
    end
end

function CargoWindow:drawContextMenu(x, y, alpha)
    if self.parentShipWindow and self.parentShipWindow.drawContextMenu then
        return self.parentShipWindow:drawContextMenu(x, y, alpha)
    end
end

function CargoWindow:isSearchFocused()
    return self.cargoSearchFocused == true
end

-- Draw cargo content (main draw function)
function CargoWindow:drawCargoContent(windowX, windowY, width, height, alpha)
    local contentX = windowX + 10
    local contentY = windowY + Theme.window.topBarHeight + 8
    local contentWidth = width - 20
    local bottomBarH = Theme.window.bottomBarHeight or 0
    
    local pilotEntities = ECS.getEntitiesWith({"Player", "InputControlled"})
    if #pilotEntities == 0 then return end
    local pilotId = pilotEntities[1]
    local input = ECS.getComponent(pilotId, "InputControlled")
    if not input or not input.targetEntity then return end
    local droneId = input.targetEntity
    local cargo = ECS.getComponent(droneId, "Cargo")
    if not cargo then return end

    -- Initialize control state
    self.cargoSortMode = self.cargoSortMode or "name" -- "name" | "qty"
    self.cargoFilterMode = self.cargoFilterMode or "All" -- "All" | "Modules" | "Resources"
    self.cargoSearchQuery = self.cargoSearchQuery or ""
    self.cargoSearchFocused = self.cargoSearchFocused or false

    -- Draw sort/filter controls at top
    local controlsHeight = self:drawTopControls(contentX, contentY, contentWidth, alpha)
    local gridY = contentY + controlsHeight + 8
    local gridHeight = height - Theme.window.topBarHeight - bottomBarH - controlsHeight - 24

    self.hoveredItemSlot = nil
    -- Draw cargo grid filtered/sorted
    local itemsList = self:getFilteredAndSortedItems(cargo.items)
    self:drawCargoGridInternal(itemsList, contentX, gridY, contentWidth, gridHeight, alpha)

    -- Draw bottom bar with search, credits, and cargo capacity
    self:drawBottomBar(windowX, windowY, width, height, alpha, pilotId, droneId)

    -- Draw dragged item if being dragged
    if DragState.hasDrag() then
        local draggedItem = DragState.getDragItem()
        if draggedItem and draggedItem.itemDef then
            local mx, my
            if Scaling._lastMouseUI and Scaling._lastMouseUI[1] then
                mx, my = Scaling._lastMouseUI[1], Scaling._lastMouseUI[2]
            else
                mx, my = Scaling.toUI(love.mouse.getPosition())
            end
            local itemDef = draggedItem.itemDef
            local iconSize = 32
            love.graphics.push()
            love.graphics.translate(mx, my)
            love.graphics.setColor(1, 1, 1, 0.9)
            
            -- Check if this is a turret/module item (module is stored in itemDef.module)
            local module = itemDef.module
            local design = itemDef.design or (module and module.design)
            local drawFunc = itemDef.draw or (module and module.draw)
            
            if drawFunc and type(drawFunc) == "function" then
                if module and module.draw then
                    module.draw(module, 0, 0)
                else
                    drawFunc(itemDef, 0, 0)
                end
            elseif design and design.color then
                local color = design.color
                love.graphics.setColor(color[1], color[2], color[3], (color[4] or 1) * 0.9)
                local size = (design.size or 16) * 1.5
                love.graphics.circle("fill", 0, 0, size)
            else
                love.graphics.rectangle("fill", -iconSize/2, -iconSize/2, iconSize, iconSize)
            end
            love.graphics.pop()
        end
    end
end

-- Standalone window behaviour
function CargoWindow:draw(viewportWidth, viewportHeight, uiMx, uiMy)
    WindowBase.draw(self, viewportWidth, viewportHeight, uiMx, uiMy)
    if not self.position then return end
    local alpha = self.animAlpha or 0
    if alpha <= 0 then return end
    local x, y = self.position.x, self.position.y
    -- Draw close button provided by WindowBase
    self:drawCloseButton(x, y, alpha, uiMx, uiMy)
    self:drawCargoContent(x, y, self.width, self.height, alpha)
    
    -- Draw context menu if open
    if ContextMenu.isOpen() then
        ContextMenu.draw(alpha)
    end
end

-- Helper methods (moved from cargo_panel)
function CargoWindow:getFilteredAndSortedItems(cargoItems)
    local ItemDefs = require('src.items.item_loader')
    local list = {}
    for itemId, count in pairs(cargoItems) do
        local itemDef = ItemDefs[itemId]
        if itemDef then
            local filter = self.cargoFilterMode or "All"
            local isModule = (itemDef.module ~= nil) or (itemDef.type == "turret" or itemDef.type == "defensive" or itemDef.type == "generator")
            local isResource = (not isModule) and ((itemDef.type == nil) or (itemDef.type == "resource") or (itemDef.stackable == true))

            local include = true
            if filter == "Modules" then
                include = isModule
            elseif filter == "Resources" then
                include = isResource
            else
                include = true
            end

            -- Search filter
            local query = (self.cargoSearchQuery or ""):lower()
            if include and query ~= "" then
                local name = (itemDef.name or ""):lower()
                local idLower = tostring(itemId):lower()
                include = (name:find(query, 1, true) ~= nil) or (idLower:find(query, 1, true) ~= nil)
            end

            if include then
                table.insert(list, { itemId = itemId, count = count, itemDef = itemDef })
            end
        end
    end

    local sortMode = self.cargoSortMode or "name"
    if sortMode == "qty" then
        table.sort(list, function(a, b)
            if a.count == b.count then
                return (a.itemDef.name or a.itemId) < (b.itemDef.name or b.itemId)
            end
            return a.count > b.count
        end)
    else
        table.sort(list, function(a, b)
            local an = a.itemDef.name or a.itemId
            local bn = b.itemDef.name or b.itemId
            if an == bn then return a.count > b.count end
            return an < bn
        end)
    end

    return list
end

function CargoWindow:drawTopControls(x, y, width, alpha)
    local padding = 6
    local btnH = 26
    local btnW = 96
    local spacing = 8

    love.graphics.setFont(Theme.getFont(Theme.fonts.small))

    self.cargoControlButtons = {}

    local function drawButton(id, label, bx, by, active)
        local bg = Theme.colors.surface
        local border = Theme.colors.borderAlt
        local text = Theme.colors.text
        if active then
            love.graphics.setColor(0.2, 0.5, 0.3, 0.35 * alpha)
            love.graphics.rectangle("fill", bx - 1, by - 1, btnW + 2, btnH + 2, 6, 6)
        end
        love.graphics.setColor(bg[1], bg[2], bg[3], 0.9 * alpha)
        love.graphics.rectangle("fill", bx, by, btnW, btnH, 6, 6)
        love.graphics.setColor(border[1], border[2], border[3], 0.4 * alpha)
        love.graphics.rectangle("line", bx, by, btnW, btnH, 6, 6)
        love.graphics.setColor(text[1], text[2], text[3], alpha)
        love.graphics.printf(label, bx, by + 5, btnW, "center")
        self.cargoControlButtons[id] = { x = bx, y = by, w = btnW, h = btnH }
    end

    local cx = x
    local cy = y

    -- Sort buttons
    drawButton("sort_name", "Sort: Name", cx, cy, self.cargoSortMode == "name")
    cx = cx + btnW + spacing
    drawButton("sort_qty", "Sort: Qty", cx, cy, self.cargoSortMode == "qty")

    -- Filter buttons
    cx = cx + btnW + spacing * 2
    drawButton("filter_all", "All", cx, cy, self.cargoFilterMode == "All")
    cx = cx + btnW + spacing
    drawButton("filter_modules", "Modules", cx, cy, self.cargoFilterMode == "Modules")
    cx = cx + btnW + spacing
    drawButton("filter_resources", "Resources", cx, cy, self.cargoFilterMode == "Resources")

    return btnH + padding
end

function CargoWindow:drawBottomBar(windowX, windowY, width, height, alpha, pilotId, droneId)
    local bottomBarH = Theme.window.bottomBarHeight or 0
    if bottomBarH <= 0 then return end
    
    local x = windowX
    local y = windowY + height - bottomBarH
    local w = width
    local h = bottomBarH
    local padding = Theme.spacing.sm

    local wallet = ECS.getComponent(pilotId, "Wallet")
    local cargo = ECS.getComponent(droneId, "Cargo")
    local currentVolume = cargo and cargo.currentVolume or 0
    local maxCapacity = cargo and cargo.capacity or 0

    love.graphics.setFont(Theme.getFont(Theme.fonts.normal))
    local fontHeight = love.graphics.getFont():getHeight()
    local textY = y + (h - fontHeight) / 2

    -- Draw left side: Credits
    local creditsText = wallet and string.format("Credits: %d", wallet.credits) or "Credits: 0"
    love.graphics.setColor(Theme.colors.text[1], Theme.colors.text[2], Theme.colors.text[3], alpha)
    love.graphics.print(creditsText, x + padding, textY)

    -- Draw center: Cargo capacity
    local cargoText = string.format("Cargo: %.2f/%.2f m3", currentVolume, maxCapacity)
    love.graphics.setColor(Theme.colors.text[1], Theme.colors.text[2], Theme.colors.text[3], alpha)
    love.graphics.printf(cargoText, x + padding, textY, w - padding * 2, "center")

    -- Draw right side: Search box
    local searchW = 220
    local searchH = 26
    local searchX = x + w - searchW - padding
    local searchY = y + (h - searchH) / 2
    self.cargoSearchRect = { x = searchX, y = searchY, w = searchW, h = searchH }

    local bg = Theme.colors.surface
    local border = Theme.colors.border
    local text = Theme.colors.text
    if self.cargoSearchFocused then
        love.graphics.setColor(0.2, 0.4, 0.6, 0.28 * alpha)
        love.graphics.rectangle("fill", searchX - 1, searchY - 1, searchW + 2, searchH + 2, 6, 6)
    end
    love.graphics.setColor(bg[1], bg[2], bg[3], 0.95 * alpha)
    love.graphics.rectangle("fill", searchX, searchY, searchW, searchH, 6, 6)
    love.graphics.setColor(border[1], border[2], border[3], 0.5 * alpha)
    love.graphics.rectangle("line", searchX, searchY, searchW, searchH, 6, 6)

    local placeholder = "Search..."
    local query = self.cargoSearchQuery or ""
    local showPlaceholder = query == "" and not self.cargoSearchFocused
    love.graphics.setScissor(searchX + 8, searchY, searchW - 16, searchH)
    if showPlaceholder then
        local tc = Theme.colors.textSecondary
        love.graphics.setColor(tc[1], tc[2], tc[3], (tc[4] or 1) * alpha)
        love.graphics.printf(placeholder, searchX + 8, searchY + 5, searchW - 16, "left")
    else
        love.graphics.setColor(text[1], text[2], text[3], alpha)
        love.graphics.printf(query, searchX + 8, searchY + 5, searchW - 16, "left")
        -- Caret
        if self.cargoSearchFocused then
            local font = love.graphics.getFont()
            local caretX = searchX + 8 + font:getWidth(query)
            love.graphics.setColor(text[1], text[2], text[3], 0.6 * alpha)
            love.graphics.line(caretX, searchY + 6, caretX, searchY + searchH - 6)
        end
    end
    love.graphics.setScissor()
end

function CargoWindow:canEquipInSlotInternal(itemId, slotType)
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

function CargoWindow:getCompatibleSlotsInternal(itemId)
    local compatibleSlots = {}
    if self:canEquipInSlotInternal(itemId, "Turret Module") then
        table.insert(compatibleSlots, "Turret Module")
    end
    if self:canEquipInSlotInternal(itemId, "Defensive Module") then
        table.insert(compatibleSlots, "Defensive Module")
    end
    if self:canEquipInSlotInternal(itemId, "Generator Module") then
        table.insert(compatibleSlots, "Generator Module")
    end
    return compatibleSlots
end

function CargoWindow:drawCargoGridInternal(cargoItems, x, y, width, height, alpha)
    -- Draw the grid of cargo items
    -- cargoItems is a list of {itemId, count, itemDef}
    if not cargoItems then return end
    
    local ItemDefs = require('src.items.item_loader')
    local slotSize = 64
    local slotPadding = 8
    local slotsPerRow = math.floor(width / (slotSize + slotPadding))
    if slotsPerRow < 1 then slotsPerRow = 1 end
    
    local mx, my
    if Scaling._lastMouseUI and Scaling._lastMouseUI[1] then
        mx, my = Scaling._lastMouseUI[1], Scaling._lastMouseUI[2]
    else
        mx, my = Scaling.toUI(love.mouse.getPosition())
    end
    
    for i, item in ipairs(cargoItems) do
        local row = math.floor((i - 1) / slotsPerRow)
        local col = (i - 1) % slotsPerRow
        local slotX = x + col * (slotSize + slotPadding)
        local slotY = y + row * (slotSize + slotPadding)
        
        local isHovered = pointInRect(mx, my, slotX, slotY, slotSize, slotSize)
        if isHovered then
            self.hoveredItemSlot = {
                itemId = item.itemId,
                itemDef = item.itemDef,
                count = item.count,
                mouseX = mx,
                mouseY = my
            }
        end
        
        -- Draw slot background
        local bg = Theme.colors.surface
        local border = isHovered and Theme.colors.hover or Theme.colors.border
        love.graphics.setColor(bg[1], bg[2], bg[3], 0.8 * alpha)
        love.graphics.rectangle("fill", slotX, slotY, slotSize, slotSize, 4, 4)
        love.graphics.setColor(border[1], border[2], border[3], 0.6 * alpha)
        love.graphics.rectangle("line", slotX, slotY, slotSize, slotSize, 4, 4)
        
        -- Draw item icon using item's draw method or fallback
        if item.itemDef then
            local centerX = slotX + slotSize / 2
            local centerY = slotY + slotSize / 2
            love.graphics.push()
            love.graphics.translate(centerX, centerY)
            love.graphics.setColor(1, 1, 1, alpha)
            
            -- Check if this is a turret/module item (module is stored in itemDef.module)
            local module = item.itemDef.module
            local design = item.itemDef.design or (module and module.design)
            local drawFunc = item.itemDef.draw or (module and module.draw)
            
            if drawFunc and type(drawFunc) == "function" then
                -- Use the module's draw function if available, otherwise item's draw
                if module and module.draw then
                    module.draw(module, 0, 0)
                else
                    drawFunc(item.itemDef, 0, 0)
                end
            elseif design and design.color then
                -- Fallback: draw a colored circle/square based on design
                local color = design.color
                love.graphics.setColor(color[1], color[2], color[3], (color[4] or 1) * alpha)
                local size = (design.size or 16) * 1.5
                love.graphics.circle("fill", 0, 0, size)
            else
                -- Ultimate fallback: simple colored square
                love.graphics.setColor(0.7, 0.7, 0.7, alpha)
                love.graphics.rectangle("fill", -12, -12, 24, 24, 2, 2)
            end
            love.graphics.pop()
        end
        
        -- Draw count
        if item.count > 1 then
            love.graphics.setFont(Theme.getFont(Theme.fonts.small))
            love.graphics.setColor(Theme.colors.text[1], Theme.colors.text[2], Theme.colors.text[3], alpha)
            love.graphics.printf(tostring(item.count), slotX, slotY + slotSize - 16, slotSize, "right")
        end
    end
end

function CargoWindow:handleCargoMousepressed(x, y, button)
    -- Handle clicks on control buttons
    if self.cargoControlButtons then
        for id, rect in pairs(self.cargoControlButtons) do
            if pointInRect(x, y, rect.x, rect.y, rect.w, rect.h) then
                if id == "sort_name" then
                    self.cargoSortMode = "name"
                    return true
                elseif id == "sort_qty" then
                    self.cargoSortMode = "qty"
                    return true
                elseif id == "filter_all" then
                    self.cargoFilterMode = "All"
                    return true
                elseif id == "filter_modules" then
                    self.cargoFilterMode = "Modules"
                    return true
                elseif id == "filter_resources" then
                    self.cargoFilterMode = "Resources"
                    return true
                end
            end
        end
    end
    
    -- Handle search box click
    if self.cargoSearchRect and pointInRect(x, y, self.cargoSearchRect.x, self.cargoSearchRect.y, self.cargoSearchRect.w, self.cargoSearchRect.h) then
        self.cargoSearchFocused = true
        return true
    else
        self.cargoSearchFocused = false
    end
    
    -- Handle right-click on cargo items (button == 2 is right mouse button)
    if button == 2 and self.hoveredItemSlot then
        local hovered = self.hoveredItemSlot
        if hovered.itemId and hovered.itemDef then
            self:openContextMenu(hovered.itemId, hovered.itemDef, x, y)
            return true
        end
    end

    -- Start drag on left-click over an item
    if button == 1 and self.hoveredItemSlot and not ContextMenu.isOpen() and not self._blockDragUntilRelease then
        local hovered = self.hoveredItemSlot
        if hovered.itemId and hovered.itemDef then
            -- Start drag but do not remove the item until drop completes
            DragState.startDrag({ origin = "cargo", itemId = hovered.itemId, itemDef = hovered.itemDef, sourceWindow = self })
            return true
        end
    end
    
    return false
end

function CargoWindow:handleCargoMousereleased(x, y, button)
    -- Handle dropping items dragged from other windows (e.g., loadout)
    if DragState.hasDrag() then
        local dragged = DragState.getDragItem()
        if dragged and dragged.origin == "loadout" then
            -- If the drag originated from a LoadoutWindow, call its unequip to return item to cargo
            local src = dragged.sourceWindow
            if src and src.unequipModule then
                -- Use the window's unequip API to move the item back into cargo
                pcall(function()
                    src:unequipModule(dragged.slotName, dragged.itemId)
                end)
            end
            DragState.endDrag()
            return true
        end
    end

    return false
end

function CargoWindow:handleCargoMousemoved(x, y, dx, dy)
    -- Hover state is updated in drawCargoGridInternal based on mouse position
    return false
end

function CargoWindow:handleCargoKeypressed(key)
    if not self.cargoSearchFocused then return false end
    
    if key == "backspace" then
        local q = self.cargoSearchQuery or ""
        local len = #q
        if len > 0 then
            self.cargoSearchQuery = q:sub(1, len - 1)
        end
        return true
    elseif key == "escape" then
        self.cargoSearchFocused = false
        return true
    elseif key == "return" or key == "kpenter" then
        self.cargoSearchFocused = false
        return true
    end
    return false
end

function CargoWindow:handleCargoTextinput(t)
    if not self.cargoSearchFocused then return false end
    t = t or ""
    if t == "" then return false end
    self.cargoSearchQuery = (self.cargoSearchQuery or "") .. t
    if #self.cargoSearchQuery > 64 then
        self.cargoSearchQuery = self.cargoSearchQuery:sub(1, 64)
    end
    return true
end

function CargoWindow:mousepressed(x, y, button)
    -- Close context menu if clicking outside of it (any button)
    if ContextMenu.isOpen() then
        local menu = ContextMenu.getMenu()
        local cmW = menu.width or 200
        local cmH = menu.height or ((menu.paddingY or 12) * 2 + (#menu.options * (menu.optionHeight or 24)))
        if not (x >= menu.x and x <= menu.x + cmW and
            y >= menu.y and y <= menu.y + cmH) then
            ContextMenu.close()
            return
        end
    end
    
    -- Let base handle close button and dragging first
    WindowBase.mousepressed(self, x, y, button)
    -- If close button was pressed, WindowBase:setOpen(false) will have been called
    if not self:getOpen() then return true end
    -- If user started dragging the window, consume the event
    if self.isDragging then return true end

    return self:handleCargoMousepressed(x, y, button)
end
function CargoWindow:mousereleased(x, y, button)
    if button == 1 and ContextMenu.isOpen() then
        if ContextMenu.handleClickAt(x, y) then
            -- Prevent drag from starting immediately after context menu action
            -- Items may have shifted and mouse is still at the same position
            -- Clear the flag on the next mouse release that's not a context menu action
            self._blockDragUntilRelease = true
            return
        end
    end
    
    -- Clear drag block flag when mouse is released (after context menu action)
    if button == 1 and self._blockDragUntilRelease then
        self._blockDragUntilRelease = false
    end
    
    WindowBase.mousereleased(self, x, y, button)
    self:handleCargoMousereleased(x, y, button)
end
function CargoWindow:mousemoved(x, y, dx, dy)
    -- Handle context menu hover detection
    if ContextMenu.isOpen() then
        ContextMenu.mousemoved(x, y)
    end
    
    -- Let base handle dragging first
    WindowBase.mousemoved(self, x, y, dx, dy)
    self:handleCargoMousemoved(x, y, dx, dy)
end
function CargoWindow:keypressed(key)
    -- Close context menu on escape
    if key == "escape" and ContextMenu.isOpen() then
        ContextMenu.close()
        return true
    end
    
    return self:handleCargoKeypressed(key)
end
function CargoWindow:textinput(t)
    return self:handleCargoTextinput(t)
end

return CargoWindow


