local Profiler = {}
Profiler.__index = Profiler

function Profiler.new()
  local self = setmetatable({}, Profiler)
  self.enabled = false
  self.last = {}
  self.lastConcord = {}
  self.frame = {}
  self.concord = { enabled = false, bucket = "frame", buckets = {} }
  return self
end

function Profiler:setEnabled(enabled)
  self.enabled = enabled and true or false
  self.concord.enabled = self.enabled
end

function Profiler:beginFrame()
  self.frame = {}
  self.concord.bucket = "frame"
  self.concord.buckets = {}
  self.concord.enabled = self.enabled
end

function Profiler:add(name, ms)
  self.frame[name] = (self.frame[name] or 0) + ms
end

function Profiler:time(name, fn)
  local t0 = love.timer.getTime()
  fn()
  self:add(name, (love.timer.getTime() - t0) * 1000)
end

function Profiler:endFrame()
  self.last = self.frame
  self.lastConcord = (self.concord.buckets and self.concord.buckets[self.concord.bucket]) or {}
end

local function sortPairsByValueDesc(t)
  local arr = {}
  for k, v in pairs(t or {}) do
    arr[#arr + 1] = { k = k, v = v }
  end
  table.sort(arr, function(a, b) return a.v > b.v end)
  return arr
end

function Profiler:drawOverlay(x, y)
  if not self.enabled then
    return
  end

  x = x or 12
  y = y or 12

  love.graphics.push("all")
  love.graphics.setColor(0, 0, 0, 0.65)
  local w, h = 420, 190
  love.graphics.rectangle("fill", x - 8, y - 8, w, h, 6, 6)

  love.graphics.setColor(1, 1, 1, 1)

  local line = 0
  local function printLine(s)
    love.graphics.print(s, x, y + line * 14)
    line = line + 1
  end

  printLine(string.format("FPS: %d", love.timer.getFPS()))

  local frameSorted = sortPairsByValueDesc(self.last)
  for i = 1, math.min(6, #frameSorted) do
    local it = frameSorted[i]
    printLine(string.format("%s: %.2f ms", it.k, it.v))
  end

  local eventsToShow = { "update", "fixedUpdate", "drawWorld", "drawHud" }
  for _, evName in ipairs(eventsToShow) do
    local ev = self.lastConcord and self.lastConcord[evName]
    if ev then
      local list = sortPairsByValueDesc(ev)
      if #list > 0 then
        printLine(evName .. ":")
        for i = 1, math.min(3, #list) do
          local it = list[i]
          printLine(string.format("  %s: %.2f ms", it.k, it.v))
        end
      end
    end
  end

  love.graphics.pop()
end

return Profiler
