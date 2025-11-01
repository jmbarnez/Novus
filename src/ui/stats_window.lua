---@diagnostic disable: undefined-global
-- Ship Stats Window - Dedicated view for detailed ship statistics

local WindowBase = require('src.ui.window_base')
local Theme = require('src.ui.plasma_theme')
local ECS = require('src.ecs')
local Constants = require('src.constants')
local TurretRegistry = require('src.turret_registry')
local TurretModuleLoader = require('src.turret_module_loader')
local Scaling = require('src.scaling')

local StatsWindow = WindowBase:new{
    width = 420,
    height = 540,
    isOpen = false
}

StatsWindow.scrollOffset = 0
StatsWindow.maxScroll = 0

function StatsWindow:getOpen()
    return self.isOpen
end

function StatsWindow:setOpen(state)
    WindowBase.setOpen(self, state)
    if state then
        self.scrollOffset = 0
    end
end

function StatsWindow:toggle()
    self:setOpen(not self.isOpen)
end

function StatsWindow:mousepressed(mx, my, button)
    if not self.isOpen then return end
    local sx, sy = Scaling.toScreenCanvas(mx, my)
    WindowBase.mousepressed(self, sx, sy, button)
end

function StatsWindow:mousereleased(mx, my, button)
    if not self.isOpen then return end
    local sx, sy = Scaling.toScreenCanvas(mx, my)
    WindowBase.mousereleased(self, sx, sy, button)
end

function StatsWindow:mousemoved(mx, my, dx, dy)
    if not self.isOpen then return end
    local sx, sy = Scaling.toScreenCanvas(mx, my)
    local sdx, sdy = Scaling.toScreenCanvas(mx + dx, my + dy)
    WindowBase.mousemoved(self, sx, sy, sdx - sx, sdy - sy)
end

local function getBaseStats(droneId)
    -- Get base stats from ship design (without modules)
    local ShipLoader = require('src.ship_loader')
    local wreckage = ECS.getComponent(droneId, "Wreckage")
    if not wreckage then
        return nil
    end
    -- Wreckage component historically stores the design id in different fields
    local designId = wreckage.designId or wreckage.sourceShip or wreckage.source or wreckage.sourceShipId
    if not designId then
        return nil
    end
    
    local design = ShipLoader.getDesign(designId)
    if not design then
        return nil
    end
    
    local baseStats = {}
    baseStats.hullMax = (design.hull and design.hull.max) or 0
    baseStats.shieldMax = (design.shield and design.shield.max) or 0
    baseStats.shieldRegen = (design.shield and design.shield.regenRate) or 0
    baseStats.mass = design.mass or 1
    baseStats.thrustForce = design.thrustForce or 0
    baseStats.energyMax = 100  -- Default base energy
    baseStats.energyRegen = 2  -- Default base regen
    
    return baseStats, design
end


-- Unit mapping for display
local function getUnitForLabel(label)
    local m = {
        ["Hull"] = "HP",
        ["Shield"] = "HP",
        ["Shield Regen"] = "HP/s",
        ["Effective HP"] = "HP",
        ["Mass"] = "u",
        ["Thrust Force"] = "N",
        ["Energy Max"] = "EP",
        ["Energy Regen"] = "EP/s",
        ["Max Speed (design)"] = "u/s",
        ["Friction"] = "",
        ["Angular Damping"] = "",
        ["Collision Radius"] = "u",
        ["Cargo Capacity"] = "m3",
        ["Turret Slots"] = "",
        ["Defensive Slots"] = "",
        ["Generator Slots"] = "",
        ["Sustained DPS"] = "DPS",
        ["Accuracy"] = "%",
        ["Energy Usage"] = "EP/s",
        ["Max Velocity"] = "u/s",
        ["Acceleration"] = "u/s^2",
        ["Current Speed"] = "u/s",
        ["Current Hull"] = "HP",
        ["Current Shield"] = "HP",
        ["Current Energy"] = "EP",
        ["Shield Regen Delay"] = "s",
        ["Turn Rate"] = "rad/s",
        ["Cargo Used"] = "m3",
        ["Max Hull"] = "HP",
        ["Max Shield"] = "HP",
    }
    return m[label] or ""
end

local function gatherShipData()
    local EntityHelpers = require('src.entity_helpers')
    local pilotId = EntityHelpers.getPlayerPilot()
    local droneId = EntityHelpers.getPlayerShip()
    
    if not pilotId or not droneId then
        return nil, {
            { title = "Status", lines = {not pilotId and "No active pilot detected." or "No ship linked to pilot."} }
        }
    end

    -- Get current stats
    local hull = ECS.getComponent(droneId, "Hull")
    local shield = ECS.getComponent(droneId, "Shield")
    local energy = ECS.getComponent(droneId, "Energy")
    local physics = ECS.getComponent(droneId, "Physics")
    local turret = ECS.getComponent(droneId, "Turret")
    local turretSlots = ECS.getComponent(droneId, "TurretSlots")
    local velocity = ECS.getComponent(droneId, "Velocity")
    local angularVelocity = ECS.getComponent(droneId, "AngularVelocity")
    local cargo = ECS.getComponent(droneId, "Cargo")

    -- Get base stats and design for comparison / preview
    local baseStats, design = getBaseStats(droneId)
    baseStats = baseStats or {}

    local mass = physics and physics.mass or 1
    local baseMass = baseStats.mass or 1
    
    -- Use the pilot's configured input speed as the ship's intended max velocity when available
    local input = ECS.getComponent(pilotId, "InputControlled")
    local baseMaxVelocity = input and input.speed or Constants.player_max_speed or 0
    local maxVelocity = baseMaxVelocity
    -- Prefer physics-based acceleration (a = F/m) when thrustForce is available
    local acceleration = 0
    local baseAcceleration = 0
    if physics and physics.thrustForce then
        acceleration = physics.thrustForce / math.max(mass, 0.01)
    else
        -- Fallback: estimate acceleration as half the max velocity per second (legacy behavior)
        acceleration = maxVelocity / 2.0
    end
    if baseStats.thrustForce and baseStats.thrustForce > 0 then
        baseAcceleration = baseStats.thrustForce / math.max(baseMass, 0.01)
    end

    local totalHull = hull and hull.max or 0
    local currentHull = hull and hull.current or 0
    local totalShield = shield and shield.max or 0
    local currentShield = shield and shield.current or 0
    local shieldRegen = shield and (shield.regen or shield.regenRate) or 0
    local shieldRegenDelay = shield and shield.regenDelay or 0
    local currentEnergy = energy and energy.current or 0
    local totalEnergy = energy and energy.max or 0
    local totalEffectiveHP = totalHull + totalShield
    
    -- Calculate current speed from velocity
    local currentSpeed = 0
    if velocity then
        currentSpeed = math.sqrt(velocity.vx * velocity.vx + velocity.vy * velocity.vy)
    end
    
    -- Get turn rate from angular velocity
    local turnRate = angularVelocity and angularVelocity.omega or 0
    
    local baseHull = baseStats.hullMax or 0
    local baseShield = baseStats.shieldMax or 0
    local baseShieldRegen = baseStats.shieldRegen or 0
    local baseEffectiveHP = baseHull + baseShield

    -- Build structured list of stats with runtime and base values + deltas, organized into sections
    local baseLines = {}
    -- Helper to push entry
    local function pushStat(label, baseVal, curVal, delta)
        local d = delta
        if d == nil then d = (curVal and baseVal and (curVal - baseVal) or 0) end
        local color = nil
        if d > 0.01 then color = "positive" elseif d < -0.01 then color = "negative" end
        baseLines[#baseLines + 1] = { label = label, base = baseVal, current = curVal, delta = d, deltaColor = color }
    end
    -- Helper to push section header
    local function pushSection(title)
        baseLines[#baseLines + 1] = { isSection = true, title = title }
    end

    -- Design section
    pushSection("Design")
    baseLines[#baseLines + 1] = { label = "Design", current = (design and design.name) or "Unknown", isString = true }

    -- Defense section
    pushSection("Defense")
    -- Current Hull (with progress bar support)
    baseLines[#baseLines + 1] = { 
        label = "Current Hull", 
        current = currentHull, 
        max = totalHull,
        base = baseHull,
        delta = totalHull - baseHull,
        deltaColor = (totalHull - baseHull > 0.01) and "positive" or ((totalHull - baseHull < -0.01) and "negative" or nil),
        showProgress = true
    }
    -- Max Hull (for reference)
    pushStat("Max Hull", baseHull, totalHull, nil)
    -- Current Shield (with progress bar support)
    baseLines[#baseLines + 1] = { 
        label = "Current Shield", 
        current = currentShield, 
        max = totalShield,
        base = baseShield,
        delta = totalShield - baseShield,
        deltaColor = (totalShield - baseShield > 0.01) and "positive" or ((totalShield - baseShield < -0.01) and "negative" or nil),
        showProgress = true
    }
    -- Max Shield (for reference)
    pushStat("Max Shield", baseShield, totalShield, nil)
    pushStat("Shield Regen", baseShieldRegen, shieldRegen, nil)
    if shieldRegenDelay > 0 then
        baseLines[#baseLines + 1] = { label = "Shield Regen Delay", current = shieldRegenDelay, base = nil, delta = nil }
    end
    local totalEffectiveHP = totalHull + totalShield
    local baseEffectiveHP = baseHull + baseShield
    pushStat("Effective HP", baseEffectiveHP, totalEffectiveHP, nil)

    -- Turret aggregates: compute sustained DPS, accuracy, energy usage
    local ItemDefs = require('src.items.item_loader')
    local EnergySystem = require('src.systems.energy')
    local turretModules = {}
    if turretSlots and turretSlots.slots then
        for _, itemId in ipairs(turretSlots.slots) do
            if itemId and itemId ~= "" then
                local mod = TurretRegistry.getModule(itemId) or TurretModuleLoader.getTurretModuleByName(itemId)
                if not mod then
                    local itemDef = ItemDefs[itemId]
                    if itemDef and itemDef.module then
                        mod = itemDef.module
                    end
                end
                if mod then table.insert(turretModules, mod) end
            end
        end
    end
    -- Fallback: if no turretSlots, check Turret.component.moduleName
    if #turretModules == 0 and turret and turret.moduleName and turret.moduleName ~= "" then
        local mid = turret.moduleName
        local mod = TurretRegistry.getModule(mid) or TurretModuleLoader.getTurretModuleByName(mid)
        if not mod then
            local itemDef = ItemDefs[mid]
            if itemDef and itemDef.module then mod = itemDef.module end
        end
        if mod then table.insert(turretModules, mod) end
    end

    -- Helper to calculate weapon stats from a module
    local function calculateWeaponStats(mod)
        local dps = mod.DPS or 0
        local sustained = dps
        if not mod.CONTINUOUS then
            local cooldown = mod.COOLDOWN or 1
            sustained = dps / math.max(cooldown, 1)
        end
        
        local accuracy = 100
        local spread = mod.AIM_SPREAD or 0
        if spread then
            accuracy = math.max(0, 100 - math.deg(spread))
        end
        
        local energyPerSec = mod.ENERGY_PER_SECOND or 0
        if not energyPerSec and EnergySystem and EnergySystem.CONSUMPTION then
            energyPerSec = EnergySystem.CONSUMPTION[mod.name] or EnergySystem.CONSUMPTION[mod.id] or 0
        end
        if energyPerSec and not mod.CONTINUOUS then
            local cooldown = mod.COOLDOWN or 1
            energyPerSec = energyPerSec / math.max(cooldown, 1)
        end
        
        local range = mod.RANGE or mod.FALLOFF_START or 0
        local name = mod.displayName or mod.NAME or mod.name or mod.id or "weapon"
        
        return {
            name = name,
            dps = dps,
            sustained = sustained,
            accuracy = accuracy,
            energyPerSec = energyPerSec,
            range = range
        }
    end

    -- Aggregate weapon stats
    local totalSustainedDPS = 0
    local accSum = 0
    local accCount = 0
    local totalEnergyPerSecond = 0
    local weaponNames = {}
    for _, mod in ipairs(turretModules) do
        local stats = calculateWeaponStats(mod)
        totalSustainedDPS = totalSustainedDPS + stats.sustained
        accSum = accSum + stats.accuracy
        accCount = accCount + 1
        totalEnergyPerSecond = totalEnergyPerSecond + stats.energyPerSec
        weaponNames[#weaponNames + 1] = stats.name
    end

    -- Combat section
    pushSection("Combat")
    baseLines[#baseLines + 1] = { label = "Weapons", current = table.concat(weaponNames, ", ") or "None", isString = true }
    baseLines[#baseLines + 1] = { label = "Sustained DPS", base = nil, current = totalSustainedDPS, delta = totalSustainedDPS, deltaColor = (totalSustainedDPS>0) and "positive" or nil }
    if accCount > 0 then
        local avgAcc = accSum / accCount
        baseLines[#baseLines + 1] = { label = "Accuracy", base = nil, current = avgAcc, delta = nil }
    else
        baseLines[#baseLines + 1] = { label = "Accuracy", base = nil, current = 100, delta = nil }
    end
    baseLines[#baseLines + 1] = { label = "Energy Usage", base = nil, current = totalEnergyPerSecond, delta = nil }
    
    -- Per-weapon breakdown (if multiple weapons)
    if #turretModules > 1 then
        for _, mod in ipairs(turretModules) do
            local stats = calculateWeaponStats(mod)
            baseLines[#baseLines + 1] = { label = stats.name, current = stats.name, isString = true, isWeaponHeader = true }
            baseLines[#baseLines + 1] = { label = "  DPS", base = nil, current = stats.sustained, delta = nil }
            baseLines[#baseLines + 1] = { label = "  Accuracy", base = nil, current = stats.accuracy, delta = nil }
            baseLines[#baseLines + 1] = { label = "  Energy Usage", base = nil, current = stats.energyPerSec, delta = nil }
            if stats.range > 0 then
                baseLines[#baseLines + 1] = { label = "  Range", base = nil, current = stats.range, delta = nil }
            end
        end
    end

    -- Movement section
    pushSection("Movement")
    pushStat("Mass", baseStats.mass or 0, mass, nil)
    pushStat("Max Velocity", baseMaxVelocity, maxVelocity, nil)
    baseLines[#baseLines + 1] = { label = "Current Speed", current = currentSpeed, base = nil, delta = nil }
    if baseAcceleration > 0 then
        pushStat("Acceleration", baseAcceleration, acceleration, nil)
    else
        baseLines[#baseLines + 1] = { label = "Acceleration", base = nil, current = acceleration, delta = nil }
    end
    pushStat("Thrust Force", baseStats.thrustForce or 0, physics and physics.thrustForce or 0, nil)
    if turnRate ~= 0 then
        baseLines[#baseLines + 1] = { label = "Turn Rate", current = turnRate, base = nil, delta = nil }
    end

    -- Energy section
    pushSection("Energy")
    -- Current Energy (with progress bar support)
    baseLines[#baseLines + 1] = { 
        label = "Current Energy", 
        current = currentEnergy, 
        max = totalEnergy,
        base = baseStats.energyMax or 0,
        delta = totalEnergy - (baseStats.energyMax or 0),
        deltaColor = (totalEnergy - (baseStats.energyMax or 0) > 0.01) and "positive" or ((totalEnergy - (baseStats.energyMax or 0) < -0.01) and "negative" or nil),
        showProgress = true
    }
    -- Max Energy (for reference)
    pushStat("Energy Max", baseStats.energyMax or 0, totalEnergy, nil)
    pushStat("Energy Regen", baseStats.energyRegen or 0, energy and energy.regenRate or 0, nil)

    -- Structure section
    pushSection("Structure")
    if design then
        baseLines[#baseLines + 1] = { label = "Collision Radius", base = design.collisionRadius, current = (ECS.getComponent(droneId, "Collidable") and ECS.getComponent(droneId, "Collidable").radius) or design.collisionRadius }
        baseLines[#baseLines + 1] = { label = "Turret Slots", base = design.turretSlots or 0, current = (turretSlots and (turretSlots.maxSlots or #turretSlots.slots)) or (design.turretSlots or 0) }
        baseLines[#baseLines + 1] = { label = "Defensive Slots", base = design.defensiveSlots or 0, current = (ECS.getComponent(droneId, "DefensiveSlots") and (ECS.getComponent(droneId, "DefensiveSlots").maxSlots or #ECS.getComponent(droneId, "DefensiveSlots").slots)) or (design.defensiveSlots or 0) }
        baseLines[#baseLines + 1] = { label = "Generator Slots", base = design.generatorSlots or 0, current = (ECS.getComponent(droneId, "GeneratorSlots") and (ECS.getComponent(droneId, "GeneratorSlots").maxSlots or #ECS.getComponent(droneId, "GeneratorSlots").slots)) or (design.generatorSlots or 0) }
        baseLines[#baseLines + 1] = { label = "Cargo Capacity", base = design.cargoCapacity or 0, current = design.cargoCapacity or 0 }
        baseLines[#baseLines + 1] = { label = "Max Speed (design)", base = (design.maxSpeed or design.patrolSpeed), current = (physics and physics.maxSpeed) or (design.maxSpeed or design.patrolSpeed) }
        baseLines[#baseLines + 1] = { label = "Friction", base = design.friction or 0, current = physics and physics.friction or design.friction or 0 }
        baseLines[#baseLines + 1] = { label = "Angular Damping", base = design.angularDamping or 0, current = physics and physics.angularDamping or design.angularDamping or 0 }
    end
    
    -- Cargo section (only if cargo component exists)
    if cargo then
        pushSection("Cargo")
        baseLines[#baseLines + 1] = { 
            label = "Cargo Used", 
            current = cargo.currentVolume or 0, 
            max = cargo.capacity or 0,
            base = nil,
            delta = nil,
            showProgress = true
        }
    end

    return droneId, design, baseLines
end

local function drawShipPreview(design, x, y, w, h, alpha)
    -- Draw a complete preview of the ship including all texture elements
    love.graphics.push('all')
    love.graphics.setColor(Theme.colors.surface[1], Theme.colors.surface[2], Theme.colors.surface[3], alpha)
    love.graphics.rectangle('fill', x, y, w, h)
    love.graphics.setColor(Theme.colors.border[1], Theme.colors.border[2], Theme.colors.border[3], alpha)
    love.graphics.rectangle('line', x, y, w, h)

    if not design then
        love.graphics.setFont(Theme.getFont(Theme.fonts.small))
        love.graphics.setColor(Theme.colors.textSecondary[1], Theme.colors.textSecondary[2], Theme.colors.textSecondary[3], alpha)
        love.graphics.printf("No design", x, y + h/2 - 8, w, 'center')
        love.graphics.pop()
        return
    end

    -- Calculate bounding box including polygon and all texture elements
    local minX, maxX, minY, maxY = nil, nil, nil, nil
    
    if design.polygon and #design.polygon > 0 then
        for _, p in ipairs(design.polygon) do
            if minX == nil then
                minX, maxX, minY, maxY = p.x, p.x, p.y, p.y
            else
                minX = math.min(minX, p.x)
                maxX = math.max(maxX, p.x)
                minY = math.min(minY, p.y)
                maxY = math.max(maxY, p.y)
            end
        end
    end
    
    -- Expand bounding box to include all texture elements
    if design.texture then
        for field, shapes in pairs(design.texture) do
            if type(shapes) == "table" then
                for _, shape in ipairs(shapes) do
                    if type(shape) == "table" then
                        -- Circles: {x, y, r, color}
                        if shape.x and shape.y and shape.r then
                            if minX == nil then
                                minX = shape.x - shape.r
                                maxX = shape.x + shape.r
                                minY = shape.y - shape.r
                                maxY = shape.y + shape.r
                            else
                                minX = math.min(minX, shape.x - shape.r)
                                maxX = math.max(maxX, shape.x + shape.r)
                                minY = math.min(minY, shape.y - shape.r)
                                maxY = math.max(maxY, shape.y + shape.r)
                            end
                        end
                        -- Lines: {x1, y1, x2, y2, color, lineWidth}
                        if shape.x1 and shape.y1 and shape.x2 and shape.y2 then
                            if minX == nil then
                                minX = math.min(shape.x1, shape.x2)
                                maxX = math.max(shape.x1, shape.x2)
                                minY = math.min(shape.y1, shape.y2)
                                maxY = math.max(shape.y1, shape.y2)
                            else
                                minX = math.min(minX, shape.x1, shape.x2)
                                maxX = math.max(maxX, shape.x1, shape.x2)
                                minY = math.min(minY, shape.y1, shape.y2)
                                maxY = math.max(maxY, shape.y1, shape.y2)
                            end
                        end
                    end
                end
            end
        end
    end
    
    if minX == nil then
        -- Fallback: draw simple triangle
        love.graphics.setColor(0.8,0.8,0.8,alpha)
        love.graphics.polygon('fill', {x + w/2, y + 8, x + w - 8, y + h - 8, x + 8, y + h - 8})
        love.graphics.setColor(Theme.colors.border[1], Theme.colors.border[2], Theme.colors.border[3], alpha)
        love.graphics.polygon('line', {x + w/2, y + 8, x + w - 8, y + h - 8, x + 8, y + h - 8})
        love.graphics.pop()
        return
    end

    local pw = maxX - minX
    local ph = maxY - minY
    if pw <= 0 then pw = 1 end
    if ph <= 0 then ph = 1 end
    local pad = 10
    local scale = math.min((w - pad*2) / pw, (h - pad*2) / ph)
    local cx = x + w/2
    local cy = y + h/2

    love.graphics.translate(cx, cy)
    love.graphics.scale(scale, scale)
    love.graphics.translate(-(minX + maxX)/2, -(minY + maxY)/2)

    -- Draw base polygon
    if design.polygon and #design.polygon > 0 then
        local baseColor = (design.colors and design.colors.base) or (design.color and design.color) or {0.7,0.7,0.7,1}
        love.graphics.setColor(baseColor[1], baseColor[2], baseColor[3], (baseColor[4] or 1) * alpha)
        local verts = {}
        for _, p in ipairs(design.polygon) do
            table.insert(verts, p.x)
            table.insert(verts, p.y)
        end
        love.graphics.polygon('fill', verts)
    end

    -- Draw all texture elements (matching render/entities.lua logic)
    if design.texture then
        for field, shapes in pairs(design.texture) do
            if type(shapes) == "table" and #shapes > 0 then
                for _, shape in ipairs(shapes) do
                    if type(shape) == "table" then
                        -- Draw circles: {x, y, r, color}
                        if shape.x and shape.y and shape.r and shape.color and type(shape.color) == "table" and #shape.color >= 3 then
                            love.graphics.setColor(shape.color[1], shape.color[2], shape.color[3], (shape.color[4] or 1) * alpha)
                            love.graphics.circle("fill", shape.x, shape.y, shape.r)
                        end
                        -- Draw lines: {x1, y1, x2, y2, color, lineWidth}
                        if shape.x1 and shape.y1 and shape.x2 and shape.y2 and shape.color and type(shape.color) == "table" and #shape.color >= 3 then
                            love.graphics.setColor(shape.color[1], shape.color[2], shape.color[3], (shape.color[4] or 1) * alpha)
                            love.graphics.setLineWidth((shape.lineWidth or 3) / scale)
                            love.graphics.line(shape.x1, shape.y1, shape.x2, shape.y2)
                        end
                    end
                end
            end
        end
    end

    -- Draw polygon outline
    if design.polygon and #design.polygon > 0 then
        love.graphics.setColor(Theme.colors.border[1], Theme.colors.border[2], Theme.colors.border[3], alpha)
        love.graphics.setLineWidth(2 / scale)
        local verts = {}
        for _, p in ipairs(design.polygon) do
            table.insert(verts, p.x)
            table.insert(verts, p.y)
        end
        love.graphics.polygon('line', verts)
    end

    love.graphics.pop()
end

-- Helper function to draw progress bar
local function drawProgressBar(x, y, w, h, current, max, alpha)
    if max <= 0 then return end
    
    local ratio = math.max(0, math.min(1, current / max))
    local barW = w * ratio
    
    -- Background
    love.graphics.setColor(0.2, 0.2, 0.2, alpha)
    love.graphics.rectangle('fill', x, y, w, h)
    
    -- Progress color based on percentage
    local r, g, b = 0.2, 1.0, 0.2  -- Green default
    if ratio < 0.25 then
        r, g, b = 1.0, 0.2, 0.2  -- Red when low
    elseif ratio < 0.5 then
        r, g, b = 1.0, 0.8, 0.2  -- Yellow when medium
    end
    
    love.graphics.setColor(r, g, b, alpha)
    love.graphics.rectangle('fill', x, y, barW, h)
    
    -- Border
    love.graphics.setColor(Theme.colors.border[1], Theme.colors.border[2], Theme.colors.border[3], alpha * 0.5)
    love.graphics.setLineWidth(1)
    love.graphics.rectangle('line', x, y, w, h)
end

function StatsWindow:draw(viewportWidth, viewportHeight, uiMx, uiMy)
    WindowBase.draw(self, viewportWidth, viewportHeight, uiMx, uiMy)
    if not self.position then return end

    local alpha = self.animAlpha or 0
    if alpha <= 0 then return end
    local x = self.position.x
    local y = self.position.y
    local w = self.width
    local h = self.height
    local topBarH = Theme.window.topBarHeight
    local bottomBarH = Theme.window.bottomBarHeight

    self:drawCloseButton(x, y, alpha, uiMx, uiMy)

    local contentPadding = 16
    local contentAreaX = x + contentPadding
    local contentAreaW = w - contentPadding * 2
    local contentAreaY = y + topBarH + 4
    local contentAreaH = math.max(0, h - topBarH - bottomBarH - 8)
    local contentOriginY = contentAreaY + 8

    local titleFont = Theme.getFontBold(Theme.fonts.title)
    local tinyFont = Theme.getFont(Theme.fonts.tiny)
    local titleHeight = titleFont:getHeight()
    local titleSpacing = 16
    local sectionSpacing = 12
    local footerSpacing = 10
    local footerHeight = tinyFont:getHeight()

    local _, design, baseLines = gatherShipData()

    local previewH = 120
    local previewSpacing = 8
    local lineSpacing = 18

    -- Calculate total height including section headers
    local sectionCount = 0
    for _, entry in ipairs(baseLines) do
        if entry.isSection then sectionCount = sectionCount + 1 end
    end
    local totalHeight = previewH + previewSpacing + titleHeight + titleSpacing
    totalHeight = totalHeight + (#baseLines) * lineSpacing + sectionCount * sectionSpacing
    totalHeight = totalHeight + footerSpacing + footerHeight

    local contentBottom = contentOriginY + totalHeight
    local visibleBottom = contentAreaY + contentAreaH
    self.maxScroll = math.max(0, contentBottom - visibleBottom)
    self.scrollOffset = math.max(0, math.min(self.scrollOffset or 0, self.maxScroll))
    local scrollY = self.scrollOffset

    love.graphics.push('all')
    love.graphics.setScissor(contentAreaX, contentAreaY, contentAreaW, contentAreaH)

    -- Draw ship preview at top
    local cursorY = contentOriginY - scrollY
    drawShipPreview(design, contentAreaX, cursorY, contentAreaW, previewH, alpha)
    cursorY = cursorY + previewH + previewSpacing

    love.graphics.setFont(titleFont)
    love.graphics.setColor(Theme.colors.text[1], Theme.colors.text[2], Theme.colors.text[3], alpha)
    love.graphics.printf("Ship Statistics", contentAreaX, cursorY, contentAreaW, 'left')
    cursorY = cursorY + titleHeight + titleSpacing

    -- Draw organized baseLines list with sections (label, runtime value, delta right-aligned)
    love.graphics.setFont(Theme.getFont(Theme.fonts.normal))
    for _, entry in ipairs(baseLines) do
        if entry.isSection then
            -- Draw section header
            cursorY = cursorY + sectionSpacing
            love.graphics.setFont(Theme.getFontBold(Theme.fonts.normal))
            love.graphics.setColor(Theme.colors.accent[1], Theme.colors.accent[2], Theme.colors.accent[3], alpha)
            love.graphics.printf(entry.title, contentAreaX + 8, cursorY, contentAreaW - 16, 'left')
            cursorY = cursorY + lineSpacing
            love.graphics.setFont(Theme.getFont(Theme.fonts.normal))
        elseif entry.isString then
            local textColor = Theme.colors.text
            if entry.isWeaponHeader then
                textColor = Theme.colors.accent or Theme.colors.text
            end
            love.graphics.setColor(textColor[1], textColor[2], textColor[3], alpha)
            love.graphics.printf(tostring(entry.current), contentAreaX + 8, cursorY, contentAreaW - 16, 'left')
            cursorY = cursorY + lineSpacing
        else
            local label = entry.label or ""
            local cur = entry.current
            local max = entry.max
            local base = entry.base
            local delta = entry.delta
            local deltaColor = entry.deltaColor
            local showProgress = entry.showProgress

            local curStr = "-"
            if type(cur) == 'number' then
                -- format numbers with sensible decimals
                if math.abs(cur) >= 100 or cur == math.floor(cur) then
                    curStr = string.format("%.0f", cur)
                else
                    curStr = string.format("%.1f", cur)
                end
            else
                curStr = tostring(cur)
            end

            -- Append units
            local unit = getUnitForLabel(label)
            if unit and unit ~= "" then
                curStr = curStr .. " " .. unit
            end
            
            -- Format with current/max if showProgress is enabled
            if showProgress and max and type(max) == 'number' and max > 0 then
                local maxStr = ""
                if math.abs(max) >= 100 or max == math.floor(max) then
                    maxStr = string.format("%.0f", max)
                else
                    maxStr = string.format("%.1f", max)
                end
                if unit and unit ~= "" then
                    maxStr = maxStr .. " " .. unit
                end
                curStr = curStr .. " / " .. maxStr
            end

            local deltaStr = ""
            if delta and math.abs(delta) > 0.009 then
                if math.abs(delta) >= 100 or delta == math.floor(delta) then
                    deltaStr = string.format("%+.0f", delta)
                else
                    deltaStr = string.format("%+.1f", delta)
                end
                if unit and unit ~= "" then
                    deltaStr = deltaStr .. " " .. unit
                end
            end

            -- Left: label and current value
            love.graphics.setColor(Theme.colors.textSecondary[1], Theme.colors.textSecondary[2], Theme.colors.textSecondary[3], alpha)
            local textX = contentAreaX + 8
            local textY = cursorY
            local textW = contentAreaW - 24
            if showProgress then
                -- Reserve space for progress bar on right side
                textW = textW - 80
            end
            love.graphics.printf(string.format("%s: %s", label, curStr), textX, textY, textW, 'left')
            
            -- Progress bar (if enabled)
            if showProgress and max and type(max) == 'number' and max > 0 then
                local barX = contentAreaX + contentAreaW - 76
                local barY = textY + 2
                local barW = 60
                local barH = 12
                drawProgressBar(barX, barY, barW, barH, cur or 0, max, alpha)
            end

            -- Right: delta (colored)
            if deltaStr ~= "" then
                local col = Theme.colors.textSecondary
                if deltaColor == "positive" then col = Theme.colors.success or {0.1,1,0.2,1} elseif deltaColor == "negative" then col = Theme.colors.danger or {1,0.25,0.25,1} end
                love.graphics.setColor(col[1], col[2], col[3], alpha)
                local deltaX = contentAreaX + 8
                local deltaW = contentAreaW - 16
                if showProgress then
                    deltaX = contentAreaX + 8
                    deltaW = contentAreaW - 88  -- Leave space for progress bar
                end
                love.graphics.printf(deltaStr, deltaX, textY, deltaW, 'right')
            end

            cursorY = cursorY + lineSpacing
        end
    end

    cursorY = cursorY + footerSpacing
    love.graphics.setFont(tinyFont)
    love.graphics.setColor(Theme.colors.textMuted[1], Theme.colors.textMuted[2], Theme.colors.textMuted[3], alpha * 0.8)
    love.graphics.printf("Stats update automatically when modules change.", contentAreaX, cursorY, contentAreaW, 'left')

    love.graphics.pop()
end

function StatsWindow:wheelmoved(x, y)
    if not self.isOpen or y == 0 then return false end

    local uiMx, uiMy
    if Scaling._lastMouseUI and Scaling._lastMouseUI[1] then
        uiMx, uiMy = Scaling._lastMouseUI[1], Scaling._lastMouseUI[2]
    else
        uiMx, uiMy = Scaling.toUI(love.mouse.getPosition())
    end

    local contentTop = (self.position and self.position.y or 0) + Theme.window.topBarHeight
    local contentBottom = (self.position and self.position.y or 0) + self.height - Theme.window.bottomBarHeight
    local contentLeft = (self.position and self.position.x or 0)
    local contentRight = contentLeft + self.width

    if uiMx >= contentLeft and uiMx <= contentRight and uiMy >= contentTop and uiMy <= contentBottom then
        local scrollSpeed = 30
        local newOffset = (self.scrollOffset or 0) - y * scrollSpeed
        self.scrollOffset = math.max(0, math.min(newOffset, self.maxScroll or 0))
        return true
    end

    return false
end

return StatsWindow
