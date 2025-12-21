local Gamestate = require("lib.hump.gamestate")
local Space = require("states.space")
local Seed = require("util.seed")
local Settings = require("game.settings") -- Load settings

function love.load()
  love.physics.setMeter(64)
  local seed1 = os.time()
  local seed2 = math.floor(love.timer.getTime() * 1000000)
  local worldSeed = Seed.normalize(seed1 * 1000000 + seed2)
  love.math.setRandomSeed(worldSeed, Seed.derive(worldSeed, "global"))
  love.math.random()
  love.math.random()
  love.math.random()

  love.graphics.setDefaultFilter("nearest", "nearest")

  Gamestate.registerEvents()
  Gamestate.switch(Space, worldSeed)
end

-- Custom main loop for FPS limiting
function love.run()
  if love.load then love.load(love.arg.parseGameArguments(arg), arg) end

  -- We don't want the first frame's dt to include time taken by love.load.
  if love.timer then love.timer.step() end

  local dt = 0

  -- Main loop time.
  return function()
    -- Process events.
    if love.event then
      love.event.pump()
      for name, a, b, c, d, e, f in love.event.poll() do
        if name == "quit" then
          if not love.quit or not love.quit() then
            return a or 0
          end
        end
        love.handlers[name](a, b, c, d, e, f)
      end
    end

    -- Update dt, as we'll be passing it to update
    if love.timer then dt = love.timer.step() end

    -- Call update and draw
    if love.update then love.update(dt) end

    if love.graphics and love.graphics.isActive() then
      love.graphics.origin()
      love.graphics.clear(love.graphics.getBackgroundColor())

      if love.draw then love.draw() end

      love.graphics.present()
    end

    -- FPS Limiter
    local maxFps = Settings.get("maxFps") or 60
    if maxFps > 0 then
      local targetDt = 1.0 / maxFps
      if love.timer then
        local delta = love.timer.getTime() - (love.timer.getTime() - dt)          -- Rough delta
        local frameTime = love.timer.step()                                       -- Reset step to get actual frame time at start of next loop? No.
        -- Proper wait:
        local start = love.timer.getTime()
        local remaining = targetDt - dt                  -- dt is the last frame duration
        if remaining > 0.001 then
          love.timer.sleep(remaining - 0.001)            -- sleep a bit less to be safe
        end
      end

      -- Busy wait for precision
      -- simplified: just use a high precision sleep if available or accept slight jitter
      -- Basic implementation:
      -- dt is time of LAST frame.
      -- We want THIS frame to take at least targetDt.
      -- But we already did update/draw.
    end

    -- Better FPS Limiter:
    if love.timer and maxFps > 0 then
      local target = 1.0 / maxFps
      local frameTime = love.timer.getTime() - (lastFrameTime or 0)
      if frameTime < target then
        love.timer.sleep(target - frameTime)
      end
      lastFrameTime = love.timer.getTime()
    end
  end
end
