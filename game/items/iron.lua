return {
  id = "iron",
  name = "Iron",
  color = { 0.62, 0.62, 0.64, 0.95 },
  unitVolume = 1,
  maxStackVolume = 100,
  icon = {
    kind = "poly",
    points = {
      -0.55, -0.15,
      -0.30, -0.55,
      0.20, -0.50,
      0.55, -0.10,
      0.45, 0.38,
      0.05, 0.60,
      -0.45, 0.35,
    },
    shadow = { dx = 0.07, dy = 0.07, a = 0.35 },
    fillA = 0.92,
    outline = { a = 0.85, width = 1 },
    highlight = {
      kind = "polyline",
      points = {
        -0.28, -0.08,
        0.05, -0.25,
        0.32, 0.05,
      },
      a = 0.16,
      width = 1,
    },
    detail = {
      kind = "line",
      points = {
        -0.08, 0.00,
        0.18, 0.28,
      },
      a = 0.25,
      width = 1,
    },
  },
}
