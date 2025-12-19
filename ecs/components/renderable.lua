local Concord = require("lib.concord")

Concord.component("renderable", function(c, kind, color)
  c.kind = kind
  c.color = color
end)

return true
