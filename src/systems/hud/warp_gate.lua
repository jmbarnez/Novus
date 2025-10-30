---@diagnostic disable: undefined-global
-- Warp Gate HUD overlay
-- Draws a screen-space repair UI when the player is near a broken warp gate

local ECS = require('src.ecs')
local Theme = require('src.ui.plasma_theme')
local Scaling = require('src.scaling')

local WarpGateHUD = {}

-- Draw HUD overlay (called from HUDSystem.draw)
function WarpGateHUD.draw(viewportWidth, viewportHeight)
    viewportWidth = viewportWidth or (love.graphics and love.graphics.getWidth and love.graphics.getWidth()) or 1920
    viewportHeight = viewportHeight or (love.graphics and love.graphics.getHeight and love.graphics.getHeight()) or 1080

    -- Find nearest warp gate within trigger distance (800)
    local gateEntities = ECS.getEntitiesWith({"WarpGate", "Position", "Collidable"})
    if #gateEntities == 0 then return end

    -- Get player position
    local playerEntities = ECS.getEntitiesWith({"Player", "InputControlled"})
    local playerPos = nil
    if #playerEntities > 0 then
        local pilotId = playerEntities[1]
        local input = ECS.getComponent(pilotId, "InputControlled")
        if input and input.targetEntity then
            playerPos = ECS.getComponent(input.targetEntity, "Position")
        end
    end
    if not playerPos then return end

    local closestGate = nil
    local closestDist = math.huge
    local triggerDistance = 800

    for _, gateId in ipairs(gateEntities) do
        local pos = ECS.getComponent(gateId, "Position")
        local coll = ECS.getComponent(gateId, "Collidable")
        local gate = ECS.getComponent(gateId, "WarpGate")
        if pos and coll and gate and not ECS.getComponent(gateId, "Station") then
            local dx = pos.x - playerPos.x
            local dy = pos.y - playerPos.y
            local dist = math.sqrt(dx * dx + dy * dy)
            if dist < triggerDistance and dist < closestDist then
                closestDist = dist
                closestGate = {id = gateId, pos = pos, coll = coll, gate = gate}
            end
        end
    end

    if not closestGate then return end

    -- Prepare repair data
    local needsRepair = not closestGate.gate.active
    local title = needsRepair and "Warp Gate Offline" or "Warp Gate Active"

    -- Required resources (match world_tooltips.lua)
    local requiredScrap = 100
    local requiredStone = 200
    local requiredIron = 80

    -- Get player cargo counts
    local scrapCount, stoneCount, ironCount = 0, 0, 0
    local playerCargo = nil
    if #playerEntities > 0 then
        local pilotId = playerEntities[1]
        local input = ECS.getComponent(pilotId, "InputControlled")
        if input and input.targetEntity then
            playerCargo = ECS.getComponent(input.targetEntity, "Cargo")
        end
    end

    if playerCargo and needsRepair then
        scrapCount = playerCargo.items["scrap"] or 0
        stoneCount = playerCargo.items["stone"] or 0
        ironCount = playerCargo.items["iron"] or 0
    end

    local hasResources = (scrapCount >= requiredScrap) and (stoneCount >= requiredStone) and (ironCount >= requiredIron)

    -- Draw HUD panel centered bottom
    local font = Theme.getFont(16)
    local smallFont = Theme.getFont(12)
    love.graphics.setFont(font)

    local boxW = 420
    local boxH = 160
    local bx = (viewportWidth - boxW) / 2
    local by = viewportHeight - boxH - 80

    -- Background
    love.graphics.setColor(Theme.colors.surface[1], Theme.colors.surface[2], Theme.colors.surface[3], 0.95)
    love.graphics.rectangle("fill", bx, by, boxW, boxH, 8, 8)
    -- Border
    love.graphics.setColor(Theme.colors.border[1], Theme.colors.border[2], Theme.colors.border[3], 1)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", bx + 1, by + 1, boxW - 2, boxH - 2, 8, 8)

    -- Title
    love.graphics.setFont(font)
    love.graphics.setColor(Theme.colors.accent[1], Theme.colors.accent[2], Theme.colors.accent[3], 1)
    local titleW = font:getWidth(title)
    love.graphics.print(title, bx + (boxW - titleW) / 2, by + 10)

    -- Resources
    love.graphics.setFont(smallFont)
    local y = by + 40
    local pad = 16

    love.graphics.setColor(Theme.colors.text[1], Theme.colors.text[2], Theme.colors.text[3], 1)
    love.graphics.print("Required Resources:", bx + pad, y)
    y = y + 20

    local function drawResource(name, cur, req, x, y)
        local has = cur >= req
        local color = has and {0.1, 0.8, 0.5, 1} or {1, 0.2, 0.5, 1}
        love.graphics.setColor(color)
        love.graphics.print(string.format("%s: %d/%d", name, cur, req), x, y)
    end

    drawResource("Scrap", scrapCount, requiredScrap, bx + pad, y)
    drawResource("Stone", stoneCount, requiredStone, bx + pad + 140, y)
    drawResource("Iron", ironCount, requiredIron, bx + pad + 280, y)

    -- Draw button
    local buttonW = 200
    local buttonH = 34
    local buttonX = bx + (boxW - buttonW) / 2
    local buttonY = by + boxH - buttonH - 14

    local bg = hasResources and Theme.colors.success or Theme.colors.surfaceAlt
    local textCol = hasResources and Theme.colors.text or Theme.colors.textMuted

    love.graphics.setColor(bg[1], bg[2], bg[3], 1)
    love.graphics.rectangle("fill", buttonX, buttonY, buttonW, buttonH, 6, 6)
    love.graphics.setColor(Theme.colors.border[1], Theme.colors.border[2], Theme.colors.border[3], 1)
    love.graphics.setLineWidth(1)
    love.graphics.rectangle("line", buttonX, buttonY, buttonW, buttonH, 6, 6)

    local btnText = hasResources and "Repair Gate (E)" or "Insufficient Resources"
    love.graphics.setFont(font)
    local tw = font:getWidth(btnText)
    love.graphics.setColor(textCol[1], textCol[2], textCol[3], 1)
    love.graphics.print(btnText, buttonX + (buttonW - tw) / 2, buttonY + (buttonH - font:getHeight()) / 2)

    -- Reset color
    love.graphics.setColor(1, 1, 1, 1)
end

return WarpGateHUD
