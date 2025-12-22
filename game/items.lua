local Items = {}

Items.defs = {}

function Items.register(def)
  if not def or not def.id then
    return
  end
  Items.defs[def.id] = def
end

Items.register(require("game.items.stone"))
Items.register(require("game.items.iron"))
Items.register(require("game.items.mithril"))
Items.register(require("game.items.iron_ingot"))
Items.register(require("game.items.mithril_ingot"))

function Items.get(id)
  return Items.defs[id]
end

function Items.all()
  return Items.defs
end

return Items
