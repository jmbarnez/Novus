local Theme = require('src.ui.theme')
local ECS = require('src.ecs')
local TurretRegistry = require('src.turret_registry')
local Scaling = require('src.scaling')

local LoadoutPanel = {}

function LoadoutPanel.draw(shipWin, windowX, windowY, width, height, alpha)
    local contentX = windowX + 10
    local contentY = windowY + Theme.window.topBarHeight + 40 + 10
    local contentWidth = shipWin.width - 20
    local contentHeight = shipWin.height - Theme.window.topBarHeight - Theme.window.bottomBarHeight - 40 - 20

    -- Reset hovered items
    shipWin.hoveredItemSlot = nil
    shipWin.hoveredEquipmentSlot = nil

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

    -- Use the full content area for stats + equipment (no right-side cargo in this tab)
    local leftPanelWidth = contentWidth

    -- LEFT PANEL: Ship Stats and Equipment
    local slotSize = Theme.spacing.slotSize
    local sectionHeight = 95

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

    local function drawStatSection(sectionY, label, stats)
        local sectionX = contentX + 10
        local boxWidth = leftPanelWidth - 20
        local boxHeight = sectionHeight - 8

        love.graphics.setColor(Theme.colors.bgDark[1], Theme.colors.bgDark[2], Theme.colors.bgDark[3], alpha * 0.4)
        love.graphics.rectangle("fill", sectionX, sectionY, boxWidth, boxHeight, 3, 3)
        love.graphics.setColor(Theme.colors.borderMedium[1], Theme.colors.borderMedium[2], Theme.colors.borderMedium[3], alpha * 0.2)
        love.graphics.rectangle("line", sectionX, sectionY, boxWidth, boxHeight, 3, 3)

        love.graphics.setFont(Theme.getFont(Theme.fonts.small))
        love.graphics.setColor(Theme.colors.textAccent[1], Theme.colors.textAccent[2], Theme.colors.textAccent[3], alpha)
        love.graphics.printf(label, sectionX + 5, sectionY + 8, boxWidth - 10, "left")

        love.graphics.setFont(Theme.getFont(Theme.fonts.tiny))
        love.graphics.setColor(Theme.colors.textSecondary[1], Theme.colors.textSecondary[2], Theme.colors.textSecondary[3], alpha)
        local statY = sectionY + 26
        for i, stat in ipairs(stats) do
            love.graphics.printf(stat, sectionX + 8, statY, boxWidth - 16, "left")
            statY = statY + 16
        end
    end

    drawStatSection(contentY, "COMBAT", {
        string.format("Damage: %.0f", turretDPS),
        string.format("DPS: %.1f", effectiveDPS),
        string.format("Range: %d", turretRange)
    })

    local survivalStats = { string.format("Eff. HP: %d", totalEffectiveHP) }
    if shield and shield.max > 0 then
        table.insert(survivalStats, string.format("Shield: +%d", shield.max))
        table.insert(survivalStats, string.format("Regen: %.1f/s", shield.regenRate or 0))
    end
    table.insert(survivalStats, string.format("Uptime: ~%.0fs", survivalTime))
    drawStatSection(contentY + sectionHeight, "SURVIVAL", survivalStats)
    drawStatSection(contentY + sectionHeight * 2, "MOVEMENT", {
        string.format("Max Vel: %.0f u/s", maxVelocity),
        string.format("Accel: %.0f u/s²", acceleration),
        string.format("Mass: %.1f", mass)
    })

    local equipmentY = contentY + sectionHeight * 3 + 10

    love.graphics.setFont(Theme.getFont(Theme.fonts.tiny))
    love.graphics.setColor(Theme.colors.textSecondary[1], Theme.colors.textSecondary[2], Theme.colors.textSecondary[3], alpha * 0.7)
    love.graphics.printf("TURRET", contentX + 10, equipmentY, leftPanelWidth - 20, "left")
    LoadoutPanel.drawEquipmentSlot(shipWin, "Turret Module", turretSlots and turretSlots.slots[1], contentX + (leftPanelWidth - slotSize) / 2, equipmentY + 12, slotSize, alpha, droneId)

    local defenseY = equipmentY + slotSize + 12
    love.graphics.setColor(Theme.colors.textSecondary[1], Theme.colors.textSecondary[2], Theme.colors.textSecondary[3], alpha * 0.7)
    love.graphics.printf("DEFENSE", contentX + 10, defenseY, leftPanelWidth - 20, "left")
    LoadoutPanel.drawEquipmentSlot(shipWin, "Defensive Module", defensiveSlots and defensiveSlots.slots[1], contentX + (leftPanelWidth - slotSize) / 2, defenseY + 12, slotSize, alpha, droneId)

    local generatorY = defenseY + slotSize + 12
    love.graphics.setColor(Theme.colors.textSecondary[1], Theme.colors.textSecondary[2], Theme.colors.textSecondary[3], alpha * 0.7)
    love.graphics.printf("GENERATOR", contentX + 10, generatorY, leftPanelWidth - 20, "left")
    LoadoutPanel.drawEquipmentSlot(shipWin, "Generator Module", generatorSlots and generatorSlots.slots[1], contentX + (leftPanelWidth - slotSize) / 2, generatorY + 12, slotSize, alpha, droneId)

    -- Draw dragged item at mouse position
    if shipWin.draggedItem and shipWin.draggedItem.itemDef then
        local mx, my
        if Scaling._lastMouseUI and Scaling._lastMouseUI[1] then
            mx, my = Scaling._lastMouseUI[1], Scaling._lastMouseUI[2]
        else
            mx, my = Scaling.toUI(love.mouse.getPosition())
        end
        love.graphics.setColor(1, 1, 1, 0.8 * alpha)
        local itemDef = shipWin.draggedItem.itemDef
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

function LoadoutPanel.drawEquipmentSlot(shipWin, slotName, equippedItemId, x, y, width, alpha, droneId)
    local slotSize = width
    local mx, my
    if Scaling._lastMouseUI and Scaling._lastMouseUI[1] then
        mx, my = Scaling._lastMouseUI[1], Scaling._lastMouseUI[2]
    else
    mx, my = Scaling.toUI(love.mouse.getPosition())
    end

    local isDropZone = false
    if shipWin.draggedItem and shipWin.draggedItem.itemDef then
        local itemDef = shipWin.draggedItem.itemDef
        if (slotName == "Turret Module" and itemDef.type == "turret") or
           (slotName == "Defensive Module" and string.match(shipWin.draggedItem.itemId, "shield")) or
           (slotName == "Generator Module" and itemDef.type == "generator") then
            if mx >= x and mx <= x + width and my >= y and my <= y + slotSize then
                isDropZone = true
            end
        end
    end

    local isHoveringSlot = mx >= x and mx <= x + width and my >= y and my <= y + slotSize
    if isHoveringSlot and equippedItemId then
        shipWin.hoveredEquipmentSlot = {
            slotName = slotName,
            itemId = equippedItemId,
            x = x,
            y = y,
            w = width,
            h = slotSize
        }
    end

    if isDropZone then
        love.graphics.setColor(0.3, 0.8, 0.3, alpha * 0.5)
    else
        love.graphics.setColor(Theme.colors.bgDark[1], Theme.colors.bgDark[2], Theme.colors.bgDark[3], alpha * 0.8)
    end
    love.graphics.rectangle("fill", x, y, slotSize, slotSize, 4, 4)

    local borderColor = isDropZone and {0.3, 1, 0.3, alpha} or {Theme.colors.borderMedium[1], Theme.colors.borderMedium[2], Theme.colors.borderMedium[3], alpha}
    love.graphics.setColor(borderColor)
    love.graphics.rectangle("line", x, y, slotSize, slotSize, 4, 4)

    shipWin.equipmentSlots = shipWin.equipmentSlots or {}
    shipWin.equipmentSlots[slotName] = {x = x, y = y, w = slotSize, h = slotSize, slotType = slotName, itemId = equippedItemId}

    if equippedItemId then
        local ItemDefs = require('src.items.item_loader')
        local itemDef = ItemDefs[equippedItemId]
        if itemDef then
            if isHoveringSlot then
                local color = (itemDef.module and itemDef.module.design and itemDef.module.design.color) or (itemDef.design and itemDef.design.color) or {0.7, 0.7, 0.8, 1}
                love.graphics.setColor(color[1] * 1.3, color[2] * 1.3, color[3] * 1.3, 0.3 * alpha)
                love.graphics.rectangle("fill", x, y, slotSize, slotSize, 4, 4)
            end
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
    end
end

function LoadoutPanel.unequipModule(shipWin, slotType, itemId)
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
            turretSlots.slots[1] = nil
            if playerTurret then
                playerTurret.moduleName = nil
            end
            cargo:addItem(itemId, 1)
        end
    elseif slotType == "Defensive Module" then
        local defensiveSlots = ECS.getComponent(droneId, "DefensiveSlots")

        if defensiveSlots and defensiveSlots.slots[1] == itemId and cargo then
            defensiveSlots.slots[1] = nil
            local ItemDefs = require('src.items.item_loader')
            local itemDef = ItemDefs[itemId]
            if itemDef and itemDef.module and itemDef.module.unequip then
                itemDef.module.unequip(droneId)
            end
            cargo:addItem(itemId, 1)
        end
    elseif slotType == "Generator Module" then
        local generatorSlots = ECS.getComponent(droneId, "GeneratorSlots")

        if generatorSlots and generatorSlots.slots[1] == itemId and cargo then
            generatorSlots.slots[1] = nil
            local ItemDefs = require('src.items.item_loader')
            local itemDef = ItemDefs[itemId]
            if itemDef and itemDef.module and itemDef.module.unequip then
                itemDef.module.unequip(droneId)
            end
            cargo:addItem(itemId, 1)
        end
    end
end

function LoadoutPanel.equipModule(shipWin, itemId)
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
            local oldModuleId = turretSlots.slots[1]
            if oldModuleId then
                cargo:addItem(oldModuleId, 1)
            end
            turretSlots.slots[1] = itemId
            if itemDef.module and itemDef.module.name then
                playerTurret.moduleName = itemDef.module.name
                if not TurretRegistry.hasModule(playerTurret.moduleName) then
                    playerTurret.moduleName = nil
                end
            else
                playerTurret.moduleName = nil
            end
            cargo:removeItem(itemId, 1)
        end
    elseif string.match(itemId, "shield") then
        local defensiveSlots = ECS.getComponent(droneId, "DefensiveSlots")
        if defensiveSlots then
            local oldModuleId = defensiveSlots.slots[1]
            if oldModuleId then
                cargo:addItem(oldModuleId, 1)
                local oldItemDef = ItemDefs[oldModuleId]
                if oldItemDef and oldItemDef.module and oldItemDef.module.unequip then
                    oldItemDef.module.unequip(droneId)
                end
            end
            defensiveSlots.slots[1] = itemId
            if itemDef.module and itemDef.module.equip then
                itemDef.module.equip(droneId)
            end
            cargo:removeItem(itemId, 1)
        end
    elseif itemDef.type == "generator" then
        local generatorSlots = ECS.getComponent(droneId, "GeneratorSlots")
        if generatorSlots then
            local oldModuleId = generatorSlots.slots[1]
            if oldModuleId then
                cargo:addItem(oldModuleId, 1)
                local oldItemDef = ItemDefs[oldModuleId]
                if oldItemDef and oldItemDef.module and oldItemDef.module.unequip then
                    oldItemDef.module.unequip(droneId)
                end
            end
            generatorSlots.slots[1] = itemId
            if itemDef.module and itemDef.module.equip then
                itemDef.module.equip(droneId)
            end
            cargo:removeItem(itemId, 1)
        end
    end
end

return LoadoutPanel
