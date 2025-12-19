return {
  id = "stone",
  name = "Stone",
  color = { 0.70, 0.70, 0.70, 0.95 },
  unitVolume = 1,
  maxStackVolume = 100,
  icon = {
    kind = "poly",
    points = {
      -0.55, -0.10,
      -0.25, -0.55,
      0.20, -0.50,
      0.55, -0.15,
      0.45, 0.35,
      0.10, 0.60,
      -0.45, 0.35,
    },
    shadow = { dx = 0.07, dy = 0.07, a = 0.35 },
    fillA = 0.92,
    outline = { a = 0.85, width = 1 },
    highlight = {
      kind = "polyline",
      points = {
        -0.30, -0.10,
        0.10, -0.30,
        0.35, 0.10,
      },
      a = 0.18,
      width = 1,
    },
    detail = {
      kind = "line",
      points = {
        -0.10, -0.05,
        0.20, 0.25,
      },
      a = 0.30,
      width = 1,
    },
  },
}
