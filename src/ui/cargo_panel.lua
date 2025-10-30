---@diagnostic disable: undefined-global
local Theme = require('src.ui.plasma_theme')
local ECS = require('src.ecs')
local Scaling = require('src.scaling')
local DragState = require('src.ui.drag_state')

local CargoPanel = {}

function CargoPanel.draw(shipWin, windowX, windowY, width, height, alpha)
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
    shipWin.cargoSortMode = shipWin.cargoSortMode or "name" -- "name" | "qty"
    shipWin.cargoFilterMode = shipWin.cargoFilterMode or "All" -- "All" | "Modules" | "Resources"
    shipWin.cargoSearchQuery = shipWin.cargoSearchQuery or ""
    shipWin.cargoSearchFocused = shipWin.cargoSearchFocused or false

    -- Draw sort/filter controls at top (no search box)
    local controlsHeight = CargoPanel.drawTopControls(shipWin, contentX, contentY, contentWidth, alpha)
    local gridY = contentY + controlsHeight + 8
    local gridHeight = height - Theme.window.topBarHeight - bottomBarH - controlsHeight - 24

    shipWin.hoveredItemSlot = nil
    -- Draw cargo grid filtered/sorted
    local itemsList = CargoPanel.getFilteredAndSortedItems(shipWin, cargo.items)
    shipWin:drawCargoGrid(itemsList, contentX, gridY, contentWidth, gridHeight, alpha)

    -- Draw bottom bar with search, credits, and cargo capacity
    CargoPanel.drawBottomBar(shipWin, windowX, windowY, width, height, alpha, pilotId, droneId)

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
            love.graphics.setColor(1, 1, 1, 0.8 * alpha)
            local itemDef = draggedItem.itemDef
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
                love.graphics.circle('fill', 0, 0, 10)
            end
            love.graphics.pop()
        end
    end

    if shipWin.contextMenu then
        shipWin:drawContextMenu(shipWin.contextMenu.x, shipWin.contextMenu.y, alpha)
    end
end

function CargoPanel.drawCargoGrid(shipWin, cargoItems, x, y, width, height, alpha)
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

    -- cargoItems may be a list produced by getFilteredAndSortedItems, or a map
    local iterateList
    if #cargoItems > 0 then
        iterateList = cargoItems
    else
        iterateList = {}
        for itemId, count in pairs(cargoItems) do
            table.insert(iterateList, { itemId = itemId, count = count })
        end
        table.sort(iterateList, function(a, b) return tostring(a.itemId) < tostring(b.itemId) end)
    end

    for _, entry in ipairs(iterateList) do
        local itemId = entry.itemId
        local count = entry.count
        local itemDef = ItemDefs[itemId]
        if itemDef then
            local row = math.floor(i / cols)
            local col = i % cols
            local slotX = x + col * (slotSize + padding)
            local slotY = y + row * (slotSize + padding)

            local isHoveringSlot = mx >= slotX and mx <= slotX + slotSize and my >= slotY and my <= slotY + slotSize

            if isHoveringSlot then
                shipWin.hoveredItemSlot = {itemId = itemId, itemDef = itemDef, count = count, mouseX = mx, mouseY = my, slotIndex = i}
            end

            local compatibleSlots = CargoPanel.getCompatibleSlots(shipWin, itemId)
            if #compatibleSlots > 0 then
                love.graphics.setColor(0.1, 0.25, 0.1, alpha * 0.4)
                love.graphics.rectangle("fill", slotX - 1, slotY - 1, slotSize + 2, slotSize + 2, 5, 5)
                love.graphics.setColor(Theme.colors.surface[1], Theme.colors.surface[2], Theme.colors.surface[3], alpha * 0.8)
            else
                love.graphics.setColor(Theme.colors.surface[1], Theme.colors.surface[2], Theme.colors.surface[3], alpha * 0.8)
            end
            love.graphics.rectangle("fill", slotX, slotY, slotSize, slotSize, 4, 4)

            if isHoveringSlot then
                love.graphics.setColor(Theme.colors.surfaceLight[1], Theme.colors.surfaceLight[2], Theme.colors.surfaceLight[3], 0.32 * alpha)
                love.graphics.rectangle("fill", slotX, slotY, slotSize, slotSize, 4, 4)
            end

            if #compatibleSlots > 0 then
                love.graphics.setColor(0.15, 0.35, 0.15, alpha * 0.6)
            else
                love.graphics.setColor(Theme.colors.borderAlt[1], Theme.colors.borderAlt[2], Theme.colors.borderAlt[3], alpha * 0.3)
            end
            love.graphics.rectangle("line", slotX, slotY, slotSize, slotSize, 4, 4)

            love.graphics.push()
            love.graphics.translate(slotX + slotSize / 2, slotY + slotSize / 2)
            -- Scale icons to fill slot better (use ~75% of slot size)
            local iconScale = (slotSize * 0.75) / (itemDef.design and itemDef.design.size or 16)
            -- Clamp to at most 1.0 so large icons are scaled down to fit the slot
            iconScale = math.min(iconScale, 1.0)
            love.graphics.scale(iconScale, iconScale)
            if type(itemDef.module) == "table" and itemDef.module.draw then
                love.graphics.setColor(1, 1, 1, alpha)
                itemDef.module.draw(itemDef.module, 0, 0)
            elseif itemDef.draw then
                itemDef:draw(0, 0)
            else
                local color = itemDef.design and itemDef.design.color or {0.7, 0.7, 0.8, 1}
                love.graphics.setColor(color[1], color[2], color[3], (color[4] or 1) * alpha)
                local iconRadius = (itemDef.design and itemDef.design.size or 16) / 2
                love.graphics.circle("fill", 0, 0, iconRadius)
            end
            love.graphics.pop()

            -- Draw level requirement in top left corner if item has one
            if itemDef.module and itemDef.module.levelRequirement then
                local levelReq = itemDef.module.levelRequirement
                local LevelUtils = require('src.level_utils')
                local playerLevelData = LevelUtils.getPlayerLevelData()
                local playerLevel = playerLevelData and playerLevelData.level or 1
                
                local levelDiff = levelReq - playerLevel
                local color
                if playerLevel >= levelReq then
                    -- Green if requirement met
                    color = {0.2, 1.0, 0.2}
                elseif levelDiff <= 3 then
                    -- Yellow if within 3 levels (close)
                    color = {1.0, 1.0, 0.2}
                else
                    -- Red if more than 3 levels away (far)
                    color = {1.0, 0.2, 0.2}
                end
                
                love.graphics.setColor(color[1], color[2], color[3], alpha)
                love.graphics.setFont(Theme.getFont(Theme.fonts.small))
                love.graphics.print(tostring(levelReq), slotX + 4, slotY + 4)
            end

            if count > 1 then
                love.graphics.setColor(Theme.colors.text[1], Theme.colors.text[2], Theme.colors.text[3], alpha)
                love.graphics.setFont(Theme.getFont(Theme.fonts.small))
                love.graphics.printf(tostring(count), slotX, slotY + slotSize - 16, slotSize, "center")
            end

            love.graphics.setColor(Theme.colors.text[1], Theme.colors.text[2], Theme.colors.text[3], alpha)
            love.graphics.setFont(Theme.getFont("xs"))
            local label = (itemDef and itemDef.name) or tostring(itemId)
            love.graphics.printf(label, slotX, slotY + slotSize + 4, slotSize, "center")

            i = i + 1
        end
    end
end

function CargoPanel.getFilteredAndSortedItems(shipWin, cargoItems)
    local ItemDefs = require('src.items.item_loader')
    local list = {}
    for itemId, count in pairs(cargoItems) do
        local itemDef = ItemDefs[itemId]
        if itemDef then
            local filter = shipWin.cargoFilterMode or "All"
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
            local query = (shipWin.cargoSearchQuery or ""):lower()
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

    local sortMode = shipWin.cargoSortMode or "name"
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

function CargoPanel.drawTopControls(shipWin, x, y, width, alpha)
    local padding = 6
    local btnH = 26
    local btnW = 96
    local spacing = 8

    love.graphics.setFont(Theme.getFont(Theme.fonts.small))

    shipWin.cargoControlButtons = {}

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
        shipWin.cargoControlButtons[id] = { x = bx, y = by, w = btnW, h = btnH }
    end

    local cx = x
    local cy = y

    -- Sort buttons
    drawButton("sort_name", "Sort: Name", cx, cy, shipWin.cargoSortMode == "name")
    cx = cx + btnW + spacing
    drawButton("sort_qty", "Sort: Qty", cx, cy, shipWin.cargoSortMode == "qty")

    -- Filter buttons
    cx = cx + btnW + spacing * 2
    drawButton("filter_all", "All", cx, cy, shipWin.cargoFilterMode == "All")
    cx = cx + btnW + spacing
    drawButton("filter_modules", "Modules", cx, cy, shipWin.cargoFilterMode == "Modules")
    cx = cx + btnW + spacing
    drawButton("filter_resources", "Resources", cx, cy, shipWin.cargoFilterMode == "Resources")

    return btnH + padding
end

-- Draw bottom bar with search, credits, and cargo capacity
function CargoPanel.drawBottomBar(shipWin, windowX, windowY, width, height, alpha, pilotId, droneId)
    local Theme = require('src.ui.plasma_theme')
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
    shipWin.cargoSearchRect = { x = searchX, y = searchY, w = searchW, h = searchH }

    local bg = Theme.colors.surface
    local border = Theme.colors.border
    local text = Theme.colors.text
    if shipWin.cargoSearchFocused then
        love.graphics.setColor(0.2, 0.4, 0.6, 0.28 * alpha)
        love.graphics.rectangle("fill", searchX - 1, searchY - 1, searchW + 2, searchH + 2, 6, 6)
    end
    love.graphics.setColor(bg[1], bg[2], bg[3], 0.95 * alpha)
    love.graphics.rectangle("fill", searchX, searchY, searchW, searchH, 6, 6)
    love.graphics.setColor(border[1], border[2], border[3], 0.5 * alpha)
    love.graphics.rectangle("line", searchX, searchY, searchW, searchH, 6, 6)

    local placeholder = "Search..."
    local query = shipWin.cargoSearchQuery or ""
    local showPlaceholder = query == "" and not shipWin.cargoSearchFocused
    love.graphics.setScissor(searchX + 8, searchY, searchW - 16, searchH)
    if showPlaceholder then
        local tc = Theme.colors.textSecondary
        love.graphics.setColor(tc[1], tc[2], tc[3], (tc[4] or 1) * alpha)
        love.graphics.printf(placeholder, searchX + 8, searchY + 5, searchW - 16, "left")
    else
        love.graphics.setColor(text[1], text[2], text[3], alpha)
        love.graphics.printf(query, searchX + 8, searchY + 5, searchW - 16, "left")
        -- Caret
        if shipWin.cargoSearchFocused then
            local font = love.graphics.getFont()
            local caretX = searchX + 8 + font:getWidth(query)
            love.graphics.setColor(text[1], text[2], text[3], 0.6 * alpha)
            love.graphics.line(caretX, searchY + 6, caretX, searchY + searchH - 6)
        end
    end
    love.graphics.setScissor()
end

local function pointInRect(px, py, rx, ry, rw, rh)
    return px >= rx and px <= rx + rw and py >= ry and py <= ry + rh
end

function CargoPanel.canEquipInSlot(shipWin, itemId, slotType)
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

function CargoPanel.getCompatibleSlots(shipWin, itemId)
    local compatibleSlots = {}
    if CargoPanel.canEquipInSlot(shipWin, itemId, "Turret Module") then
        table.insert(compatibleSlots, "Turret Module")
    end
    if CargoPanel.canEquipInSlot(shipWin, itemId, "Defensive Module") then
        table.insert(compatibleSlots, "Defensive Module")
    end
    if CargoPanel.canEquipInSlot(shipWin, itemId, "Generator Module") then
        table.insert(compatibleSlots, "Generator Module")
    end
    return compatibleSlots
end

function CargoPanel.openContextMenu(shipWin, itemId, itemDef, x, y)
    if shipWin and shipWin.openContextMenu then
        shipWin:openContextMenu(itemId, itemDef, x, y)
    end
end

function CargoPanel.handleContextMenuClick(shipWin, optionIndex)
    if shipWin and shipWin.handleContextMenuClick then
        shipWin:handleContextMenuClick(optionIndex)
    end
end

function CargoPanel.drawContextMenu(shipWin, x, y, alpha)
    if shipWin and shipWin.drawContextMenu then
        shipWin:drawContextMenu(x, y, alpha)
    end
end

function CargoPanel.mousepressed(shipWin, x, y, button)
    -- Controls handling
    if shipWin.cargoControlButtons and button == 1 then
        for id, btn in pairs(shipWin.cargoControlButtons) do
            if pointInRect(x, y, btn.x, btn.y, btn.w, btn.h) then
                if id == "sort_name" then
                    shipWin.cargoSortMode = "name"
                elseif id == "sort_qty" then
                    shipWin.cargoSortMode = "qty"
                elseif id == "filter_all" then
                    shipWin.cargoFilterMode = "All"
                elseif id == "filter_modules" then
                    shipWin.cargoFilterMode = "Modules"
                elseif id == "filter_resources" then
                    shipWin.cargoFilterMode = "Resources"
                end
                shipWin.cargoSearchFocused = false
                return
            end
        end
    end

    -- Search focus handling (UI space coords already)
    if button == 1 and shipWin.cargoSearchRect then
        local r = shipWin.cargoSearchRect
        if pointInRect(x, y, r.x, r.y, r.w, r.h) then
            shipWin.cargoSearchFocused = true
            return
        else
            shipWin.cargoSearchFocused = false
        end
    end

    -- Start dragging from cargo (left-click on item)
    if button == 1 and shipWin.hoveredItemSlot then
        DragState.startDrag({
            itemId = shipWin.hoveredItemSlot.itemId,
            itemDef = shipWin.hoveredItemSlot.itemDef,
            slotIndex = shipWin.hoveredItemSlot.slotIndex,
            count = shipWin.hoveredItemSlot.count,
            fromCargo = true,
            fromEquipment = false
        })
        return
    end

    -- Delegate to ship window logic (maintain existing behavior)
    if button == 2 and shipWin.hoveredItemSlot and not shipWin.contextMenu then
        -- Use UI-space coordinates for context menu positioning
        local uiX, uiY
        if Scaling._lastMouseUI and Scaling._lastMouseUI[1] then
            uiX, uiY = Scaling._lastMouseUI[1], Scaling._lastMouseUI[2]
        else
            uiX, uiY = x, y
        end
        shipWin:openContextMenu(shipWin.hoveredItemSlot.itemId, shipWin.hoveredItemSlot.itemDef, uiX, uiY)
    end
end

function CargoPanel.mousereleased(shipWin, x, y, button)
    if button == 1 and DragState.hasDrag() then
        local draggedItem = DragState.getDragItem()
        if not draggedItem then
            DragState.endDrag()
            return
        end

        -- Check if dropped on cargo grid slot (same window or cross-window)
        local pilotEntities = ECS.getEntitiesWith({"Player", "InputControlled"})
        if #pilotEntities == 0 then
            DragState.endDrag()
            return
        end

        local pilotId = pilotEntities[1]
        local input = ECS.getComponent(pilotId, "InputControlled")
        if not input or not input.targetEntity then
            DragState.endDrag()
            return
        end
        local droneId = input.targetEntity
        local cargo = ECS.getComponent(droneId, "Cargo")
        if not cargo then
            DragState.endDrag()
            return
        end

        -- Check if drop is within cargo window bounds
        local windowX, windowY = shipWin.position.x, shipWin.position.y
        local windowW, windowH = shipWin.width, shipWin.height
        local isInCargoWindow = x >= windowX and x <= windowX + windowW and y >= windowY and y <= windowY + windowH

        -- Handle drops from equipment onto cargo window
        if isInCargoWindow and draggedItem.fromEquipment then
            -- If dropped on cargo window, unequip (which already adds to cargo)
            if draggedItem.slotName then
                local LoadoutPanel = require('src.ui.loadout_panel')
                LoadoutPanel.unequipModule(shipWin, draggedItem.slotName, draggedItem.itemId)
            end
        elseif draggedItem.fromCargo then
            -- If dropped outside cargo window, item is discarded
            if not isInCargoWindow then
                local itemId = draggedItem.itemId
                if cargo.items[itemId] and cargo.items[itemId] > 0 then
                    cargo.items[itemId] = cargo.items[itemId] - 1
                    if cargo.items[itemId] <= 0 then
                        cargo.items[itemId] = nil
                    end
                end
            end
        end

        DragState.endDrag()
    end
end

function CargoPanel.mousemoved(shipWin, x, y, dx, dy)
    -- No-op; ship window handles context menu hover centrally
end

function CargoPanel.keypressed(shipWin, key)
    if not shipWin.cargoSearchFocused then return false end
    -- Consume input when search bar is focused
    if key == "backspace" then
        local q = shipWin.cargoSearchQuery or ""
        local len = #q
        if len > 0 then
            shipWin.cargoSearchQuery = q:sub(1, len - 1)
        end
        return true
    elseif key == "escape" then
        shipWin.cargoSearchFocused = false
        return true
    elseif key == "return" or key == "kpenter" then
        shipWin.cargoSearchFocused = false
        return true
    end
    -- For all other keys, return true to consume input (textinput will handle actual characters)
    return true
end

function CargoPanel.textinput(shipWin, t)
    if not shipWin.cargoSearchFocused then return false end
    t = t or ""
    if t == "" then return false end
    shipWin.cargoSearchQuery = (shipWin.cargoSearchQuery or "") .. t
    -- Optional max length cap to avoid runaway
    if #shipWin.cargoSearchQuery > 64 then
        shipWin.cargoSearchQuery = shipWin.cargoSearchQuery:sub(1, 64)
    end
    return true
end

-- Helper to check if cargo search is focused (can be called from anywhere)
function CargoPanel.isSearchFocused()
    local CargoWindow = require('src.ui.cargo_window')
    if not CargoWindow then return false end
    -- Access the window instance
    if CargoWindow:getOpen() then
        return CargoWindow:isSearchFocused()
    end
    return false
end

return CargoPanel
