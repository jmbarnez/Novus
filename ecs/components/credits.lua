local Concord = require("lib.concord")

Concord.component("credits", function(c, amount)
    c.balance = amount or 1000
end)

return true
