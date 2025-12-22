local Theme = require("game.theme")

local HudContext = {}

local function getTargetShip(world, ships)
  local player = world and world:getResource("player")
  if player and player.pilot and player.pilot.ship then
    return player.pilot.ship
  end

  if ships and ships.size and ships.size > 0 then
    return ships[1]
  end

  return nil
end

function HudContext.build(world, ships)
  local fps = love.timer.getFPS()
  local screenW, screenH = love.graphics.getDimensions()
  local margin = Theme.hud.layout.margin

  local targetShip = getTargetShip(world, ships)

  local ctx = {
    world = world,
    theme = Theme,
    screenW = screenW,
    screenH = screenH,
    fps = fps,
    sector = world and world:getResource("sector"),
    layout = { margin = margin, topLeftY = margin, topCenterY = margin, topRightY = margin, bottomLeftY = screenH - margin, bottomRightY = screenH - margin },
    hasShip = false,
    playerLevel = 1,
    playerXp = 0,
    playerXpToNext = 100,
    weaponCooldown = nil,
    weaponTimer = nil,
    weaponConeHalfAngle = nil,
    shipAngle = nil,
    mouseWorldX = nil,
    mouseWorldY = nil,
  }

  local player = world and world:getResource("player")
  if player and player:has("player_progress") then
    ctx.playerLevel = player.player_progress.level or ctx.playerLevel
    ctx.playerXp = player.player_progress.xp or ctx.playerXp
    ctx.playerXpToNext = player.player_progress.xpToNext or ctx.playerXpToNext
  end

  if targetShip and targetShip.physics_body and targetShip.physics_body.body then
    local body = targetShip.physics_body.body
    ctx.hasShip = true
    ctx.x, ctx.y = body:getPosition()
    ctx.vx, ctx.vy = body:getLinearVelocity()
    ctx.shipAngle = body:getAngle()

    local mw = world and world:getResource("mouse_world")
    if mw then
      ctx.mouseWorldX = mw.x
      ctx.mouseWorldY = mw.y
    end

    if targetShip:has("auto_cannon") then
      ctx.weaponCooldown = targetShip.auto_cannon.cooldown or ctx.weaponCooldown
      ctx.weaponTimer = targetShip.auto_cannon.timer or ctx.weaponTimer
      ctx.weaponConeHalfAngle = targetShip.auto_cannon.coneHalfAngle
    end

    if targetShip:has("hull") then
      ctx.hullCur = targetShip.hull.current
      ctx.hullMax = targetShip.hull.max
    end

    if targetShip:has("shield") then
      ctx.shieldCur = targetShip.shield.current
      ctx.shieldMax = targetShip.shield.max
    end

    -- Check for nearby interactables (space stations)
    if world then
      local px, py = ctx.x, ctx.y
      for _, entity in ipairs(world:getEntities()) do
        if entity:has("space_station") and entity:has("physics_body") and entity.physics_body.body then
          local stationBody = entity.physics_body.body
          local sx, sy = stationBody:getPosition()
          local radius = entity.space_station.radius or 400
          local dockingRange = radius * 1.6
          local dx, dy = px - sx, py - sy
          local dist = math.sqrt(dx * dx + dy * dy)
          if dist < dockingRange then
            local stationType = entity.space_station.stationType or "hub"
            if stationType == "refinery" then
              ctx.refineryPrompt = { text = "[E] Refine", entity = entity }
            else
              ctx.interactionPrompt = { text = "[E] Dock", entity = entity }
            end
            break
          end
        end
      end
    end
  end

  return ctx
end

return HudContext
