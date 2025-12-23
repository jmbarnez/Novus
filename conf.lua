function love.conf(t)
  t.identity = "novus_space"
  t.version = "11.4"

  t.window.title = "Novus Space"
  t.window.width = 1280
  t.window.height = 720
  t.window.vsync = 1
  t.window.msaa = 0
  t.window.resizable = true
  t.window.minwidth = 800
  t.window.minheight = 600

  t.modules.audio = true
  t.modules.data = true
  t.modules.event = true
  t.modules.font = true
  t.modules.graphics = true
  t.modules.image = true
  t.modules.joystick = true
  t.modules.keyboard = true
  t.modules.math = true
  t.modules.mouse = true
  t.modules.physics = true
  t.modules.sound = true
  t.modules.system = true
  t.modules.thread = false
  t.modules.timer = true
  t.modules.touch = false
  t.modules.video = false
end
