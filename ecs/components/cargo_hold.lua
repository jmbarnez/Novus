local Concord = require("lib.concord")

Concord.component("cargo_hold", function(c, cols, rows)
  c.cols = cols or 5
  c.rows = rows or 3

  local n = c.cols * c.rows
  c.slots = {}
  for i = 1, n do
    c.slots[i] = { id = nil, volume = 0 }
  end
end)

return true
