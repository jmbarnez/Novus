--- Active Quest HUD Widget
--- Shows accepted quests below the minimap

local Theme = require("game.theme")

local ActiveQuestWidget = {}

function ActiveQuestWidget.hitTest(ctx, x, y)
    return false -- Non-interactive
end

function ActiveQuestWidget.draw(ctx)
    if not ctx then return end

    local theme = (ctx and ctx.theme) or Theme
    local hudTheme = theme.hud
    local colors = hudTheme.colors
    local ps = hudTheme.panelStyle or {}

    local layout = ctx.layout or {}
    local margin = layout.margin or hudTheme.layout.margin

    -- Get active quests from station_ui
    local world = ctx.world
    local stationUi = world and world:getResource("station_ui")
    if not stationUi or not stationUi.quests then return end

    -- Find accepted quests
    local activeQuests = {}
    for _, quest in ipairs(stationUi.quests) do
        if quest.accepted and not quest.completed then
            table.insert(activeQuests, quest)
        end
    end

    if #activeQuests == 0 then return end

    -- Position below minimap - minimal compact design
    local mapW = hudTheme.minimap.w
    local panelW = mapW + 100 -- Significantly wider
    local questH = 32         -- More compact height
    local padding = 6
    local panelH = math.min(#activeQuests, 3) * questH + padding * 2
    local panelX = (ctx.screenW or 0) - margin - panelW
    local panelY = layout.topRightY or (margin + hudTheme.minimap.h + hudTheme.layout.stackGap)

    local cornerRadius = ps.radius or 4

    -- Background (subtle)
    -- love.graphics.setColor(colors.panelBg[1], colors.panelBg[2], colors.panelBg[3], colors.panelBg[4] * 0.75)
    -- love.graphics.rectangle("fill", panelX, panelY, panelW, panelH, cornerRadius, cornerRadius)

    -- Border (subtle)
    -- love.graphics.setColor(colors.panelBorder[1], colors.panelBorder[2], colors.panelBorder[3],
    --     colors.panelBorder[4] * 0.6)
    -- love.graphics.setLineWidth(1)
    -- love.graphics.rectangle("line", panelX, panelY, panelW, panelH, cornerRadius, cornerRadius)

    -- Draw quests - minimal layout
    local font = love.graphics.getFont()
    local th = font:getHeight()

    for i, quest in ipairs(activeQuests) do
        if i > 3 then break end -- Max 3

        local qy = panelY + padding + (i - 1) * questH
        local innerPad = 8
        local contentW = panelW - innerPad * 2

        -- Progress text (right-aligned, before description to calculate available width)
        local progText = string.format("%d/%d", quest.current or 0, quest.amount or 0)
        if quest.type == "collect_resource" then
            progText = progText .. " m³"
        end
        local progTw = font:getWidth(progText)
        local progX = panelX + panelW - innerPad - progTw

        -- Quest description (truncated to fit before progress text)
        local maxDescW = contentW - progTw - 12 -- Leave gap before progress
        local desc = quest.description or "Quest"
        if font:getWidth(desc) > maxDescW then
            while font:getWidth(desc .. "...") > maxDescW and #desc > 3 do
                desc = desc:sub(1, -2)
            end
            desc = desc .. "..."
        end
        love.graphics.setColor(1, 1, 1, 0.85)
        love.graphics.print(desc, panelX + innerPad, qy + 2)

        -- Progress text
        love.graphics.setColor(0.6, 0.75, 0.85, 0.75)
        love.graphics.print(progText, progX, qy + 2)

        -- Progress bar (compact, below text)
        local barX = panelX + innerPad
        local barY = qy + th + 4
        local barW = contentW
        local barH = 4
        local progress = (quest.current or 0) / (quest.amount or 1)
        progress = math.max(0, math.min(1, progress))

        love.graphics.setColor(colors.barBg[1], colors.barBg[2], colors.barBg[3], colors.barBg[4] * 0.6)
        love.graphics.rectangle("fill", barX, barY, barW, barH, 2)

        love.graphics.setColor(0.30, 0.70, 0.45, 0.85)
        love.graphics.rectangle("fill", barX, barY, barW * progress, barH, 2)
    end

    -- Update layout Y position
    if ctx.layout then
        ctx.layout.topRightY = panelY + panelH + hudTheme.layout.stackGap
    end

    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.setLineWidth(1)
end

return ActiveQuestWidget
