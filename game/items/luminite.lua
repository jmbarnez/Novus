return {
  id = "luminite",
  name = "Luminite",
  color = { 0.92, 0.88, 0.35, 0.95 },
  unitVolume = 1,
  maxStackVolume = 100,
  icon = {
    kind = "poly",
    points = {
      -0.05, -0.62,
      0.20, -0.50,
      0.42, -0.15,
      0.30, 0.25,
      0.05, 0.62,
      -0.28, 0.45,
      -0.40, 0.10,
      -0.30, -0.25,
    },
    shadow = { dx = 0.06, dy = 0.06, a = 0.38 },
    fillA = 0.92,
    outline = { a = 0.88, width = 1 },
    highlight = {
      kind = "polyline",
      points = {
        -0.05, -0.35,
        0.10, -0.25,
        0.18, 0.10,
      },
      a = 0.22,
      width = 1,
    },
    detail = {
      kind = "line",
      points = {
        0.02, -0.05,
        0.18, 0.35,
      },
      a = 0.30,
      width = 1,
    },
  },
}
