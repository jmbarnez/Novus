---@diagnostic disable: undefined-global
-- Quest Overlay - Super minimal quest display under minimap

local ECS = require('src.ecs')
local Theme = require('src.ui.theme')

local QuestOverlay = {}

QuestOverlay.isOpen = true -- Always visible when there are accepted quests

-- Get all accepted quests
function QuestOverlay.getAcceptedQuests()
    local acceptedQuests = {}
    
    -- Find all stations with quest boards - no need for QuestSystem
    local stations = ECS.getEntitiesWith({"Station", "QuestBoard"})
    
    for _, stationId in ipairs(stations) do
        local questBoard = ECS.getComponent(stationId, "QuestBoard")
        if questBoard then
            for _, quest in ipairs(questBoard.quests) do
                if quest.accepted and not quest.completed then
                    table.insert(acceptedQuests, quest)
                end
            end
        end
    end
    
    return acceptedQuests
end

-- Draw the quest overlay
function QuestOverlay.draw()
    if not QuestOverlay.isOpen then return end
    
    local quests = QuestOverlay.getAcceptedQuests()
    if #quests == 0 then return end
    
    local alpha = 0.85
    local font = Theme.getFont(11)
    local smallFont = Theme.getFont(9)
    
    -- Position: below minimap (right side)
    -- Minimap is at: x = screenW - 100, y = 100, radius = 80
    -- So minimap bottom is at y = 180
    local viewportWidth, viewportHeight = love.graphics.getDimensions()
    local minimapRadius = 80
    local minimapMargin = 20
    local minimapX = viewportWidth - minimapRadius - minimapMargin
    local minimapY = minimapRadius + minimapMargin
    local minimapBottom = minimapY + minimapRadius
    
    local overlayWidth = minimapRadius * 2 + 20
    local overlayX = minimapX - minimapRadius - 10
    local overlayY = minimapBottom + 15
    
    -- Calculate height based on number of quests
    local questHeight = 32
    local dividerHeight = 2
    local totalHeight = (#quests * questHeight) + ((#quests - 1) * dividerHeight)
    
    -- Background
    love.graphics.setColor(Theme.colors.bgDark[1], Theme.colors.bgDark[2], Theme.colors.bgDark[3], alpha)
    love.graphics.rectangle("fill", overlayX, overlayY, overlayWidth, totalHeight, 2, 2)
    
    -- Border
    love.graphics.setColor(Theme.colors.borderDark[1], Theme.colors.borderDark[2], Theme.colors.borderDark[3], alpha)
    love.graphics.setLineWidth(1)
    love.graphics.rectangle("line", overlayX, overlayY, overlayWidth, totalHeight, 2, 2)
    
    -- Draw each quest
    for i, quest in ipairs(quests) do
        local questY = overlayY + (i - 1) * (questHeight + dividerHeight)
        
        -- Draw quest
        QuestOverlay.drawQuest(quest, overlayX + 4, questY, overlayWidth - 8, questHeight, alpha, font, smallFont)
        
        -- Draw divider (except after last quest)
        if i < #quests then
            love.graphics.setColor(Theme.colors.borderDark[1], Theme.colors.borderDark[2], Theme.colors.borderDark[3], alpha * 0.5)
            love.graphics.rectangle("fill", overlayX + 4, questY + questHeight, overlayWidth - 8, dividerHeight)
        end
    end
end

-- Draw a single quest (minimal: title + progress bar)
function QuestOverlay.drawQuest(quest, x, y, w, h, alpha, font, smallFont)
    -- Quest title
    love.graphics.setColor(Theme.colors.textAccent[1], Theme.colors.textAccent[2], Theme.colors.textAccent[3], alpha)
    love.graphics.setFont(font)
    love.graphics.print(quest.title, x, y + 4)
    
    -- Progress bar
    local barX = x
    local barY = y + 18
    local barW = w
    local barH = 6
    
    -- Progress background
    love.graphics.setColor(Theme.colors.bgMedium[1], Theme.colors.bgMedium[2], Theme.colors.bgMedium[3], alpha)
    love.graphics.rectangle("fill", barX, barY, barW, barH, 1, 1)
    
    -- Progress fill
    local progress = 0
    if quest.requirements and quest.requirements.count then
        progress = quest.requirements.current / quest.requirements.count
    end
    
    local fillColor = Theme.colors.textAccent
    if progress >= 1.0 then
        fillColor = Theme.colors.buttonYes
    end
    
    love.graphics.setColor(fillColor[1], fillColor[2], fillColor[3], alpha)
    love.graphics.rectangle("fill", barX, barY, barW * progress, barH, 1, 1)
    
    -- Progress border
    love.graphics.setColor(Theme.colors.borderDark[1], Theme.colors.borderDark[2], Theme.colors.borderDark[3], alpha)
    love.graphics.setLineWidth(1)
    love.graphics.rectangle("line", barX, barY, barW, barH, 1, 1)
    
    -- Progress text (centered)
    if quest.requirements and quest.requirements.count then
        local progressText = string.format("%d/%d", quest.requirements.current, quest.requirements.count)
        love.graphics.setColor(Theme.colors.textMuted[1], Theme.colors.textMuted[2], Theme.colors.textMuted[3], alpha)
        love.graphics.setFont(smallFont)
        local textX = barX + (barW - smallFont:getWidth(progressText)) / 2
        local textY = barY + (barH - smallFont:getHeight()) / 2
        love.graphics.print(progressText, textX, textY)
    end
end

return QuestOverlay

