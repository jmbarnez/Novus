return {
  id = "verdium",
  name = "Verdium",
  color = { 0.22, 0.90, 0.55, 0.95 },
  unitVolume = 1,
  maxStackVolume = 100,
  icon = {
    kind = "poly",
    points = {
      -0.05, -0.62,
      0.28, -0.42,
      0.38, -0.05,
      0.10, 0.62,
      -0.22, 0.55,
      -0.40, 0.20,
      -0.32, -0.20,
    },
    shadow = { dx = 0.06, dy = 0.06, a = 0.38 },
    fillA = 0.92,
    outline = { a = 0.88, width = 1 },
    highlight = {
      kind = "polyline",
      points = {
        -0.10, -0.30,
        0.10, -0.15,
        0.20, 0.25,
      },
      a = 0.22,
      width = 1,
    },
    detail = {
      kind = "line",
      points = {
        -0.05, 0.05,
        0.05, 0.40,
      },
      a = 0.30,
      width = 1,
    },
  },
}
