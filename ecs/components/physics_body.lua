local Concord = require("lib.concord")

Concord.component("physics_body", function(c, body, shape, fixture)
  c.body = body
  c.shape = shape
  c.fixture = fixture
end)

return true
