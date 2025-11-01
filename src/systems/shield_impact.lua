---@diagnostic disable: undefined-global
-- Shield Impact System - Manages shield impact visual effects
-- Renders shield bubbles around ships that become visible when hit
-- Pulse effect emanates from impact point across the shield surface

local ECS = require('src.ecs')
local Components = require('src.components')

local ShieldImpactSystem = {
    name = "ShieldImpactSystem",
    priority = 9,
    
    update = function(dt)
        -- Update all active shield impacts
        local impactEntities = ECS.getEntitiesWith({"ShieldImpact"})
        
        for _, entityId in ipairs(impactEntities) do
            local impact = ECS.getComponent(entityId, "ShieldImpact")
            
            if impact and impact.life then
                -- Update lifetime
                impact.life = impact.life - dt
                
                -- Remove expired impacts
                if impact.life <= 0 then
                    ECS.destroyEntity(entityId)
                end
            end
        end
    end,
    
    -- Render shield impact effects
    draw = function()
        local impactEntities = ECS.getEntitiesWith({"ShieldImpact"})
        
        for _, entityId in ipairs(impactEntities) do
            local impact = ECS.getComponent(entityId, "ShieldImpact")
            
            if impact and impact.life and impact.maxLife and impact.x and impact.y and impact.shipId then
                -- Get the ship this impact belongs to
                local shipPos = ECS.getComponent(impact.shipId, "Position")
                local shipColl = ECS.getComponent(impact.shipId, "Collidable")
                
                if shipPos and shipColl and shipColl.radius then
                    -- Calculate effect progress (0 = just started, 1 = finished)
                    local progress = 1 - (impact.life / impact.maxLife)
                    
                    -- Shield bubble radius: place the visual just outside the object's collision radius
                    -- Use a small additive offset (proportional to size with a minimum) so the bubble
                    -- sits tightly against large stations while still remaining visible on small ships.
                    local shieldRadius = shipColl.radius + math.max(4, shipColl.radius * 0.03)
                    
                    -- Calculate distance from impact point to each point on the shield
                    -- We'll draw the shield as a circle with varying opacity based on distance from impact
                    
                    -- Base shield opacity (fades out as effect progresses)
                    local baseAlpha = (1 - progress) * 0.4
                    
                    -- Draw the shield bubble
                    love.graphics.setColor(0.3, 0.6, 1.0, baseAlpha)
                    love.graphics.setLineWidth(2)
                    love.graphics.circle("line", shipPos.x, shipPos.y, shieldRadius)
                    
                    -- Calculate angle from ship center to impact point
                    local impactDx = impact.x - shipPos.x
                    local impactDy = impact.y - shipPos.y
                    ---@diagnostic disable-next-line: deprecated
                    local impactAngle = math.atan2(impactDy, impactDx)
                    
                    -- Draw pulse wave emanating from impact point
                    -- The pulse spreads across the shield surface over time
                    local pulseAngleSpread = math.pi * 2 * progress -- Spreads around the whole shield
                    local pulseIntensity = math.sin(progress * math.pi) * 0.5 -- Peaks in the middle
                    
                    -- Draw multiple arc segments to show the pulse spreading
                    local numSegments = 16  -- Reduced from 64 to 16 for performance
                    for i = 0, numSegments do
                        local angle = (i / numSegments) * math.pi * 2
                        
                        -- Calculate angular distance from impact point
                        local angleDiff = angle - impactAngle
                        -- Normalize to -pi to pi
                        while angleDiff > math.pi do angleDiff = angleDiff - 2 * math.pi end
                        while angleDiff < -math.pi do angleDiff = angleDiff + 2 * math.pi end
                        
                        local absAngleDiff = math.abs(angleDiff)
                        
                        -- Check if this segment is within the pulse wave
                        if absAngleDiff < pulseAngleSpread then
                            -- Calculate brightness based on how close to the pulse front
                            local distanceFromFront = math.abs(absAngleDiff - pulseAngleSpread * 0.7)
                            local segmentAlpha = math.max(0, pulseIntensity * (1 - distanceFromFront / (pulseAngleSpread * 0.3)))
                            
                            if segmentAlpha > 0.05 then
                                local x1 = shipPos.x + math.cos(angle) * shieldRadius
                                local y1 = shipPos.y + math.sin(angle) * shieldRadius
                                local nextAngle = ((i + 1) / numSegments) * math.pi * 2
                                local x2 = shipPos.x + math.cos(nextAngle) * shieldRadius
                                local y2 = shipPos.y + math.sin(nextAngle) * shieldRadius
                                
                                love.graphics.setColor(0.5, 0.8, 1.0, (baseAlpha + segmentAlpha * 0.6))
                                love.graphics.setLineWidth(3)
                                love.graphics.line(x1, y1, x2, y2)
                            end
                        end
                    end
                    
                    -- Draw bright spot at impact point
                    if progress < 0.3 then
                        local spotAlpha = (1 - progress / 0.3) * 0.8
                        love.graphics.setColor(1.0, 1.0, 1.0, spotAlpha)
                        
                        -- Calculate position on shield surface closest to impact
                        local impactDist = math.sqrt(impactDx * impactDx + impactDy * impactDy)
                        if impactDist > 0 then
                            local normalizedX = impactDx / impactDist
                            local normalizedY = impactDy / impactDist
                            local spotX = shipPos.x + normalizedX * shieldRadius
                            local spotY = shipPos.y + normalizedY * shieldRadius
                            
                            love.graphics.circle("fill", spotX, spotY, 3)
                        end
                    end
                end
            end
        end
        
        -- Reset graphics state
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.setLineWidth(1)
    end
}

-- Helper function to create a shield impact effect at a position
function ShieldImpactSystem.createImpact(x, y, shipId)
    local impactId = ECS.createEntity()
    ECS.addComponent(impactId, "ShieldImpact", Components.ShieldImpact(x, y, shipId))
    return impactId
end

return ShieldImpactSystem
