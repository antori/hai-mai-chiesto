function love.conf(t)
  t.identity = "hai-mai-chiesto"
  t.window.title = "L'hai mai chiesto?"
  -- Sul web (love.js) una tela più grande resta nitida sugli schermi dei telefoni.
  local web = love._os == "Web"
  t.window.width = web and 1080 or 720
  t.window.height = web and 1920 or 1280
  t.window.resizable = true
  t.window.vsync = 1
  t.modules.physics = false
  t.modules.joystick = false
  t.accelerometerjoystick = false
end
