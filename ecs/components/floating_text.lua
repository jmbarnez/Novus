local Concord = require("lib.concord")

Concord.component("floating_text", function(c, text, x, y, opts)
  opts = opts or {}

  c.text = text or ""
  c.x = x or 0
  c.y = y or 0

  c.vx = opts.vx or 0
  c.vy = opts.vy or (opts.riseSpeed ~= nil and -math.abs(opts.riseSpeed) or -50)
  c.ax = opts.ax or 0
  c.ay = opts.ay or 0

  c.duration = opts.duration or 0.55
  c.t = c.duration

  c.fadeOutFrac = opts.fadeOutFrac or 0.35
  c.scale = opts.scale or 1

  c.color = opts.color or { 1, 1, 1, 1 }
  c.shadow = opts.shadow
  c.shadowOffsetX = opts.shadowOffsetX or 1
  c.shadowOffsetY = opts.shadowOffsetY or 1
end)

return true
