local source = assert(arg[1], "Pass the Spoon init.lua path")
local failures = 0

local function fixture(options)
  options = options or {}
  local world = {now = 0, timers = {}, alerts = {}, keys = {}, typed = 0, stray = 0, selected = false}
  world.go = options.alreadyOpen or false
  world.readyAt = world.go and 0 or math.huge
  local function element(attributes)
    return {
      setTimeout = function() return true end,
      attributeValue = function(_, key)
        local value = attributes[key]
        if type(value) == "function" then return value() end
        return value
      end,
    }
  end
  local button = element({AXIdentifier = "OKButton", AXEnabled = function() return world.selected end})
  local field = element({AXIdentifier = "PathTextField", AXRole = "AXTextField", AXEnabled = true,
    AXValue = function() return world.text or "" end})
  local panel = element({AXIdentifier = options.noPicker and "ordinary-window" or "open-panel",
    AXDefaultButton = options.noPicker and nil or button, AXChildren = {button}})
  local go = element({AXIdentifier = "GoToWindow", AXChildren = {field}})
  local function currentWindow()
    if world.go then return world.now >= world.readyAt and go or nil end
    return panel
  end
  local app = {pid = function() return 10 end, isRunning = function() return true end}
  local other = {pid = function() return 20 end}
  local ax = element({AXFocusedWindow = currentWindow,
    AXFocusedUIElement = function() return world.go and world.now >= world.readyAt and field or nil end})
  local function keyStroke(mods, key)
    world.keys[#world.keys + 1] = {key = key, at = world.now}
    if key == "g" then world.go = true; world.readyAt = world.now + (options.delay or 0.75)
    elseif key == "a" then world.text = ""
    elseif key == "return" then
      if world.go and world.now >= world.readyAt and world.text == world.savedPath then
        world.selectionAt = world.now + 0.2
      else world.stray = world.stray + 1 end
    end
  end
  _G.hs = {
    application = {frontmostApplication = function()
      return options.switchAt and world.now >= options.switchAt and other or app
    end},
    axuielement = {applicationElement = function() return ax end},
    pasteboard = {readImage = function()
      if options.noImage then return nil end
      return {saveToFile = function(_, filename)
        world.savedPath = filename
        return not options.saveFails
      end}
    end},
    alert = {show = function(message) world.alerts[#world.alerts + 1] = message end},
    timer = {
      absoluteTime = function() return world.now * 1e9 end,
      usleep = function(delay) world.now = world.now + delay / 1e6 end,
      doEvery = function(interval, callback)
        local timer = {enabled = true, callback = callback, stop = function(self) self.enabled = false end}
        world.timers[#world.timers + 1] = timer
        return timer
      end,
    },
    eventtap = {
      checkKeyboardModifiers = function() return world.now < (options.releaseAt or 0) and {ctrl = true, cmd = true} or {} end,
      keyStroke = keyStroke,
      keyStrokes = function(text)
        world.typed = world.typed + 1
        if world.go and world.now >= world.readyAt then world.text = text else world.stray = world.stray + 1 end
      end,
      event = {newKeyEvent = function(_, key, down)
        return {setFlags = function(self) return self end, post = function() if down then keyStroke({}, key) end end}
      end},
    },
  }
  function world:advance(seconds)
    local untilTime = self.now + seconds
    while self.now < untilTime do
      self.now = self.now + 0.05
      if self.selectionAt and self.now >= self.selectionAt then self.selected = true; self.go = false; self.selectionAt = nil end
      for _, timer in ipairs(self.timers) do if timer.enabled then timer.callback() end end
    end
  end
  return assert(loadfile(source))(), world
end

local function test(name, options, verify)
  local ok, err = pcall(function()
    local spoonObject, world = fixture(options)
    spoonObject:pasteImageToPicker()
    world:advance(5)
    verify(world, spoonObject)
  end)
  print((ok and "PASS " or "FAIL ") .. name .. (ok and "" or ": " .. tostring(err)))
  if not ok then failures = failures + 1 end
end

test("waits for a slow picker and selects the image", {delay = 0.75}, function(w)
  assert(w.selected, "image was not selected")
  assert(w.stray == 0, "typed before the field was ready")
  local returns = 0; for _, event in ipairs(w.keys) do if event.key == "return" then returns = returns + 1 end end
  assert(returns == 1, "must confirm the path without submitting the upload")
end)
test("waits for shortcut modifiers to be released", {releaseAt = 0.5}, function(w)
  assert(w.selected and w.keys[1].at >= 0.5)
end)
test("reuses an already open path field", {alreadyOpen = true}, function(w)
  assert(w.selected)
  for _, event in ipairs(w.keys) do assert(event.key ~= "g", "reopened an existing path sheet") end
end)
test("stops if the user changes apps", {switchAt = 0.2}, function(w)
  assert(w.typed == 0 and not w.selected)
  assert(#w.alerts == 1)
end)
test("does not type into an ordinary app window", {noPicker = true}, function(w)
  assert(#w.keys == 0 and w.typed == 0 and #w.alerts == 1)
end)
test("empty clipboard does not operate the picker", {noImage = true}, function(w)
  assert(#w.keys == 0 and #w.alerts == 1)
end)
test("failed image save does not operate the picker", {saveFails = true}, function(w)
  assert(#w.keys == 0 and #w.alerts == 1)
end)
os.exit(failures == 0 and 0 or 1)
