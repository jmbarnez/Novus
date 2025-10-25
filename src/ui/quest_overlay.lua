---@diagnostic disable: undefined-global
-- Quest Overlay - Super minimal quest display under minimap
-- Optimized with caching and batched rendering

local ECS = require('src.ecs')
local Theme = require('src.ui.theme')
local BatchRenderer = require('src.ui.batch_renderer')

local QuestOverlay = {}

QuestOverlay.isOpen = true -- Always visible when there are accepted quests

-- Cache for quest data to avoid querying every frame
local cachedQuests = {}
local cacheVersion = 0
local lastUpdateFrame = 0
local CACHE_UPDATE_INTERVAL = 30 -- Update cache every 30 frames (~0.5 seconds at 60fps)

-- Invalidate cache when quests change (call this from quest system when accepting/completing quests)
function QuestOverlay.invalidateCache()
    cacheVersion = cacheVersion + 1
end

-- Get all accepted quests (cached version)
function QuestOverlay.getAcceptedQuests()
    local currentFrame = love.timer.getTime() * 60 -- Approximate frame count
    
    -- Only update cache periodically
    if currentFrame - lastUpdateFrame < CACHE_UPDATE_INTERVAL and #cachedQuests > 0 then
        return cachedQuests
    end
    
    lastUpdateFrame = currentFrame
    cachedQuests = {}
    
    -- Find all stations with quest boards - no need for QuestSystem
    local stations = ECS.getEntitiesWith({"Station", "QuestBoard"})
    
    for _, stationId in ipairs(stations) do
        local questBoard = ECS.getComponent(stationId, "QuestBoard")
        if questBoard then
            for _, quest in ipairs(questBoard.quests) do
                if quest.accepted and not quest.completed then
                    table.insert(cachedQuests, quest)
                end
            end
        end
    end
    
    return cachedQuests
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
    
    -- Background (batched)
    local bgColor = Theme.colors.bgDark
    BatchRenderer.queueRect(overlayX, overlayY, overlayWidth, totalHeight, 
        bgColor[1], bgColor[2], bgColor[3], alpha, 2)
    
    -- Border (batched)
    local borderColor = Theme.colors.borderDark
    BatchRenderer.queueRectLine(overlayX, overlayY, overlayWidth, totalHeight, 
        borderColor[1], borderColor[2], borderColor[3], alpha, 1, 2)
    
    -- Draw each quest
    for i, quest in ipairs(quests) do
        local questY = overlayY + (i - 1) * (questHeight + dividerHeight)
        
        -- Draw quest
        QuestOverlay.drawQuest(quest, overlayX + 4, questY, overlayWidth - 8, questHeight, alpha, font, smallFont)
        
        -- Draw divider (except after last quest)
        if i < #quests then
            BatchRenderer.queueRect(overlayX + 4, questY + questHeight, overlayWidth - 8, dividerHeight,
                borderColor[1], borderColor[2], borderColor[3], alpha * 0.5, 0)
        end
    end
end

-- Draw a single quest (minimal: title + progress bar) - batched rendering
function QuestOverlay.drawQuest(quest, x, y, w, h, alpha, font, smallFont)
    -- Quest title (batched text)
    local textColor = Theme.colors.textAccent
    BatchRenderer.queueText(quest.title, x, y + 4, font, 
        textColor[1], textColor[2], textColor[3], alpha)
    
    -- Progress bar
    local barX = x
    local barY = y + 18
    local barW = w
    local barH = 6
    
    -- Progress background
    local bgColor = Theme.colors.bgMedium
    BatchRenderer.queueRect(barX, barY, barW, barH, 
        bgColor[1], bgColor[2], bgColor[3], alpha, 1)
    
    -- Progress fill
    local progress = 0
    if quest.requirements and quest.requirements.count then
        progress = quest.requirements.current / quest.requirements.count
    end
    
    local fillColor = Theme.colors.textAccent
    if progress >= 1.0 then
        fillColor = Theme.colors.buttonYes
    end
    
    local fillWidth = barW * progress
    if fillWidth > 0 then
        BatchRenderer.queueRect(barX, barY, fillWidth, barH, 
            fillColor[1], fillColor[2], fillColor[3], alpha, 1)
    end
    
    -- Progress border
    local borderColor = Theme.colors.borderDark
    BatchRenderer.queueRectLine(barX, barY, barW, barH, 
        borderColor[1], borderColor[2], borderColor[3], alpha, 1, 1)
    
    -- Progress text (centered)
    if quest.requirements and quest.requirements.count then
        local progressText = string.format("%d/%d", quest.requirements.current, quest.requirements.count)
        local mutedColor = Theme.colors.textMuted
        local textX = barX + (barW - smallFont:getWidth(progressText)) / 2
        local textY = barY + (barH - smallFont:getHeight()) / 2
        BatchRenderer.queueText(progressText, textX, textY, smallFont, 
            mutedColor[1], mutedColor[2], mutedColor[3], alpha)
    end
end

return QuestOverlay

