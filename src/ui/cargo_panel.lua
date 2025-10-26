local Theme = require('src.ui.theme')
local ECS = require('src.ecs')
local Scaling = require('src.scaling')

local CargoPanel = {}

function CargoPanel.draw(shipWin, windowX, windowY, width, height, alpha)
    local contentX = windowX + 10
    local contentY = windowY + Theme.window.topBarHeight + 40 + 10
    local contentWidth = shipWin.width - 20
    local contentHeight = shipWin.height - Theme.window.topBarHeight - Theme.window.bottomBarHeight - 40 - 20

    local pilotEntities = ECS.getEntitiesWith({"Player", "InputControlled"})
    if #pilotEntities == 0 then return end
    local pilotId = pilotEntities[1]
    local input = ECS.getComponent(pilotId, "InputControlled")
    if not input or not input.targetEntity then return end
    local droneId = input.targetEntity
    local cargo = ECS.getComponent(droneId, "Cargo")
    if not cargo then return end

    shipWin.hoveredItemSlot = nil
    -- Draw cargo grid full area
    shipWin:drawCargoGrid(cargo.items, contentX, contentY, contentWidth, contentHeight, alpha)

    if shipWin.contextMenu then
        shipWin:drawContextMenu(shipWin.contextMenu.x, shipWin.contextMenu.y, alpha)
    end
end

function CargoPanel.openContextMenu(shipWin, itemId, itemDef, x, y)
    shipWin:openContextMenu(itemId, itemDef, x, y)
end

function CargoPanel.handleContextMenuClick(shipWin, optionIndex)
    shipWin:handleContextMenuClick(optionIndex)
end

function CargoPanel.mousepressed(shipWin, x, y, button)
    -- Delegate to ship window logic (maintain existing behavior)
    if button == 2 and shipWin.hoveredItemSlot and not shipWin.contextMenu then
        shipWin:openContextMenu(shipWin.hoveredItemSlot.itemId, shipWin.hoveredItemSlot.itemDef, x, y)
    end
end

function CargoPanel.mousereleased(shipWin, x, y, button)
    -- No-op; ship window handles release logic centrally
end

function CargoPanel.mousemoved(shipWin, x, y, dx, dy)
    -- No-op; ship window handles context menu hover centrally
end

return CargoPanel
