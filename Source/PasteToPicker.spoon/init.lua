--- === PasteToPicker ===
--- Paste a clipboard image into a native file picker.
--
-- Press the hotkey while a native file picker (NSOpenPanel) is
-- focused. If the clipboard holds an image, it's saved to /tmp and the path
-- is auto-typed into the picker via Cmd-Shift-G (Go to folder).
--
-- One keypress => clipboard screenshot becomes the selected file.
--
-- Configure shortcuts with bindHotkeys() in ~/.hammerspoon/init.lua.

local obj = {
  name = "PasteToPicker",
  version = "1.0.2",
  author = "manos",
  license = "MIT - see LICENSE",
  homepage = "https://github.com/manos/Spoons",
}

local SAVE_DIR    = "/tmp"

local POLL_INTERVAL = 0.05
local STEP_TIMEOUT = 3
local PATH_SETTLE_TIME = 0.15

local function now()
  return hs.timer.absoluteTime() / 1e9
end

local function attribute(element, name)
  if not element then return nil end
  element:setTimeout(0.03)
  return element:attributeValue(name)
end

local function pickerWindow(application)
  local window = attribute(application, "AXFocusedWindow")
  local identifier = attribute(window, "AXIdentifier")
  if identifier == "open-panel" or identifier == "GoToWindow" then return window, identifier end
  for _, sheet in ipairs(attribute(window, "AXSheets") or {}) do
    identifier = attribute(sheet, "AXIdentifier")
    if identifier == "open-panel" or identifier == "GoToWindow" then return sheet, identifier end
  end
end

local function modifiersReleased()
  local flags = hs.eventtap.checkKeyboardModifiers()
  return not (flags.cmd or flags.ctrl or flags.alt or flags.shift or flags.fn)
end

local function openButton(window)
  local button = attribute(window, "AXDefaultButton")
  if button then return button end
  local queue, index = {window}, 1
  local deadline = now() + 0.1
  while queue[index] and index <= 80 and now() < deadline do
    local element = queue[index]
    index = index + 1
    if attribute(element, "AXIdentifier") == "OKButton" then return element end
    for _, child in ipairs(attribute(element, "AXChildren") or {}) do queue[#queue + 1] = child end
  end
end

local function timestamp()
  return os.date("%Y%m%d-%H%M%S")
end

function obj:pasteImageToPicker()
  if self._operation then return end
  local app = hs.application.frontmostApplication()
  local application = app and hs.axuielement.applicationElement(app)
  if not application or not pickerWindow(application) then
    hs.alert.show("Open a file picker first")
    return
  end

  local image = hs.pasteboard.readImage()
  if not image then
    hs.alert.show("No image in clipboard")
    return
  end

  local path = string.format("%s/clipboard-%s.png", SAVE_DIR, timestamp())
  local ok = image:saveToFile(path, "png")
  if not ok then
    hs.alert.show("Failed to save clipboard image")
    return
  end

  local operation = {phase = "release", deadline = now() + STEP_TIMEOUT, started = now()}
  self._operation = operation
  self.lastResult = {state = "running"}
  local function finish(state, message)
    if operation.timer then operation.timer:stop() end
    self._operation = nil
    self.lastResult.state = state
    self.lastResult.elapsed = now() - operation.started
    if message then hs.alert.show(message) end
  end
  local function transition(phase)
    operation.phase = phase
    operation.deadline = now() + STEP_TIMEOUT
  end
  local function step()
    local front = hs.application.frontmostApplication()
    if not front or front:pid() ~= app:pid() then
      finish("cancelled", "Keep the file picker focused and try again")
      return
    end
    local window, identifier = pickerWindow(application)
    local field = attribute(application, "AXFocusedUIElement")
    local isPathField = attribute(field, "AXIdentifier") == "PathTextField"
    local matches = isPathField and attribute(field, "AXValue") == path
    self.lastResult.phase = operation.phase
    self.lastResult.window = identifier
    self.lastResult.pathMatches = matches
    if now() >= operation.deadline then
      finish("timeout", "The picker didn't select the image. Please try the shortcut again.")
      return
    end

    if operation.phase == "release" then
      if not modifiersReleased() then return end
      if not window then finish("cancelled", "Open a file picker first"); return end
      if identifier ~= "GoToWindow" then hs.eventtap.keyStroke({"cmd", "shift"}, "g", 0) end
      transition("field")
    elseif operation.phase == "field" then
      if identifier ~= "GoToWindow" or not isPathField or not attribute(field, "AXEnabled") then return end
      if not modifiersReleased() then return end
      hs.eventtap.keyStroke({"cmd"}, "a", 0)
      hs.eventtap.keyStrokes(path)
      transition("path")
    elseif operation.phase == "path" then
      if not matches then return end
      operation.pathReadyAt = now()
      transition("confirm")
    elseif operation.phase == "confirm" then
      if not matches then finish("cancelled", "The path changed; please try the shortcut again"); return end
      if now() - operation.pathReadyAt < PATH_SETTLE_TIME or not modifiersReleased() then return end
      hs.eventtap.keyStroke({}, "return", 0)
      transition("selection")
    elseif operation.phase == "selection" then
      -- Confirm only the path. The user retains the final Open/Upload action.
      if identifier == "open-panel" and attribute(openButton(window), "AXEnabled") then
        finish("selected")
      end
    end
  end
  operation.timer = hs.timer.doEvery(POLL_INTERVAL, function()
    local succeeded = pcall(step)
    if not succeeded then
      finish("error", "Couldn't read the file picker. Please try again.")
    end
  end)
end

--- PasteToPicker:bindHotkeys(mapping) -> self
--- Method
--- Bind the pasteImageToPicker shortcut.
function obj:bindHotkeys(mapping)
  hs.spoons.bindHotkeysToSpec({
    pasteImageToPicker = function() self:pasteImageToPicker() end,
  }, mapping)
  return self
end

return obj
