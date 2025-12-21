return {
  id = "azurite",
  name = "Azurite",
  color = { 0.22, 0.58, 0.95, 0.95 },
  unitVolume = 1,
  maxStackVolume = 100,
  icon = {
    kind = "poly",
    points = {
      -0.10, -0.60,
      0.20, -0.35,
      0.10, 0.10,
      0.35, 0.45,
      0.00, 0.60,
      -0.35, 0.40,
      -0.25, -0.05,
      -0.40, -0.35,
    },
    shadow = { dx = 0.06, dy = 0.06, a = 0.38 },
    fillA = 0.92,
    outline = { a = 0.88, width = 1 },
    highlight = {
      kind = "polyline",
      points = {
        -0.12, -0.35,
        0.06, -0.20,
        0.00, 0.25,
      },
      a = 0.22,
      width = 1,
    },
    detail = {
      kind = "line",
      points = {
        0.12, -0.10,
        0.22, 0.28,
      },
      a = 0.30,
      width = 1,
    },
  },
}
