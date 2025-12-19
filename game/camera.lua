local Camera = {}
Camera.__index = Camera

local clamp = function(v, lo, hi)
  if v < lo then return lo end
  if v > hi then return hi end
  return v
end

function Camera.new(opts)
  opts = opts or {}

  local self = setmetatable({}, Camera)

  self.zoom = opts.zoom or 1.0
  self.minZoom = opts.minZoom or 0.5
  self.maxZoom = opts.maxZoom or 2.0
  self.zoomStep = opts.zoomStep or 1.1

  self.boundsW = opts.boundsW or 0
  self.boundsH = opts.boundsH or 0

  return self
end

function Camera:setBounds(w, h)
  self.boundsW = w or 0
  self.boundsH = h or 0
end

function Camera:setZoomLimits(minZoom, maxZoom)
  self.minZoom = minZoom or self.minZoom
  self.maxZoom = maxZoom or self.maxZoom
  self.zoom = clamp(self.zoom, self.minZoom, self.maxZoom)
end

function Camera:zoomIn()
  self.zoom = clamp(self.zoom * self.zoomStep, self.minZoom, self.maxZoom)
end

function Camera:zoomOut()
  self.zoom = clamp(self.zoom / self.zoomStep, self.minZoom, self.maxZoom)
end

function Camera:getView(screenW, screenH, targetX, targetY, out)
  local zoom = self.zoom
  local viewW = screenW / zoom
  local viewH = screenH / zoom

  local camX, camY = 0, 0

  if targetX and targetY then
    local maxCamX = math.max(0, self.boundsW - viewW)
    local maxCamY = math.max(0, self.boundsH - viewH)

    camX = clamp(targetX - viewW * 0.5, 0, maxCamX)
    camY = clamp(targetY - viewH * 0.5, 0, maxCamY)
  end

  local view = out or {}
  view.zoom = zoom
  view.viewW = viewW
  view.viewH = viewH
  view.camX = camX
  view.camY = camY
  view.focusX = camX + viewW * 0.5
  view.focusY = camY + viewH * 0.5
  return view
end

return Camera
