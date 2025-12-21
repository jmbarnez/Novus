return {
  id = "crimsonite",
  name = "Crimsonite",
  color = { 0.95, 0.28, 0.35, 0.95 },
  unitVolume = 1,
  maxStackVolume = 100,
  icon = {
    kind = "poly",
    points = {
      -0.15, -0.60,
      0.18, -0.55,
      0.45, -0.20,
      0.32, 0.25,
      0.00, 0.60,
      -0.35, 0.35,
      -0.45, -0.10,
    },
    shadow = { dx = 0.06, dy = 0.06, a = 0.38 },
    fillA = 0.92,
    outline = { a = 0.88, width = 1 },
    highlight = {
      kind = "polyline",
      points = {
        -0.08, -0.35,
        0.18, -0.30,
        0.10, 0.05,
      },
      a = 0.22,
      width = 1,
    },
    detail = {
      kind = "line",
      points = {
        0.18, 0.10,
        0.05, 0.45,
      },
      a = 0.30,
      width = 1,
    },
  },
}
