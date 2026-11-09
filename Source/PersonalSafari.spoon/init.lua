--- === PersonalSafari ===
--- Shift-click web links into one chosen Safari window, across macOS Spaces.
local obj = {}
obj.__index = obj
obj.name = "PersonalSafari"
obj.version = "1.0.2"
obj.author = "manos"
obj.homepage = "https://github.com/manos/Spoons"
obj.license = "MIT - see LICENSE"

-- Shift alone is reserved; Cmd-Shift-click and other combinations stay native.
obj.modifier = "shift"
obj.gestureTimeout = 1.5 -- seconds allowed for an app to dispatch its URL
obj.showMenu = false

local safari = "com.apple.Safari"
local targetKey = "PersonalSafari.target"
local browserKey = "PersonalSafari.previousBrowser"
local axBudget = 0.12 -- leave ample room below macOS's input callback timeout
local axQueryTimeout = 0.025

local function isWebURL(url)
  return type(url) == "string" and not url:find("[%z\1-\32\127]")
    and url:match("^[Hh][Tt][Tt][Pp][Ss]?://[^/?#]+") ~= nil
end

local function appleScriptString(value)
  return '"' .. value:gsub("\\", "\\\\"):gsub('"', '\\"') .. '"'
end

function obj:_notify(message)
  hs.alert.show("Personal Safari: " .. message)
  return false
end

function obj:_modifierOnly(flags)
  if not flags[self.modifier] then return false end
  for _, key in ipairs({ "cmd", "alt", "ctrl", "shift", "fn" }) do
    if key ~= self.modifier and flags[key] then return false end
  end
  return true
end

function obj:_processIdentity(pid)
  if not self._bootSession then
    local boot, ok = hs.execute("/usr/sbin/sysctl -n kern.bootsessionuuid")
    if not ok then return nil end
    self._bootSession = boot:gsub("%s+$", "")
  end
  local started, ok = hs.execute(string.format("LC_ALL=C /bin/ps -p %d -o lstart=", pid))
  if not ok or not started:match("%S") then return nil end
  return self._bootSession .. ":" .. started:gsub("%s+$", "")
end

function obj:_attribute(element, key, deadline)
  local remaining = deadline - hs.timer.absoluteTime() / 1e9
  if remaining <= 0 then return nil end
  if not element:setTimeout(math.min(remaining, axQueryTimeout)) then return nil end
  return element:attributeValue(key)
end

-- Stop at the page boundary: AXWebArea's AXURL is the page, not a link.
function obj:_linkAt(element, deadline)
  deadline = deadline or (hs.timer.absoluteTime() / 1e9 + axBudget)
  for _ = 1, 16 do
    if not element then return nil end
    local role = self:_attribute(element, "AXRole", deadline)
    if not role then return nil end
    if role == "AXLink" then
      local url = self:_attribute(element, "AXURL", deadline)
      -- Safari exposes NSURL as a Lua table on some Hammerspoon builds.
      if type(url) == "table" then url = url.url end
      return isWebURL(url) and url or nil
    end
    if role == "AXWebArea" or role == "AXWindow" or role == "AXApplication" then
      return nil
    end
    element = self:_attribute(element, "AXParent", deadline)
  end
end

--- PersonalSafari:selectWindow() -> boolean
--- With your personal Safari window focused, remember its ID and Safari process.
function obj:selectWindow()
  local app = hs.application.frontmostApplication()
  if not app or app:bundleID() ~= safari then
    return self:_notify("Focus your personal Safari window, then press ⌃⌥⌘P.")
  end
  local ok, windowID = hs.osascript.applescript([[
    tell application id "com.apple.Safari"
      if (count windows) is 0 then return false
      return id of front window
    end tell
  ]])
  if not ok or type(windowID) ~= "number" then
    return self:_notify("Could not select a window. Allow Hammerspoon to control Safari in Privacy & Security → Automation.")
  end
  local identity = self:_processIdentity(app:pid())
  if not identity then return self:_notify("Could not verify Safari. Try selecting the window again.") end
  self._target = { windowID = windowID, pid = app:pid(), processIdentity = identity }
  hs.settings.set(targetKey, self._target)
  hs.alert.show("Personal Safari window selected — Shift-click links to send them here.")
  return true
end

--- PersonalSafari:openPersonal(url) -> boolean
--- Open a background tab in the selected window. Never fall back to another window.
function obj:openPersonal(url)
  if not isWebURL(url) then return self:_notify("This is not a web link.") end
  local app = hs.application.get(safari)
  local target = self._target
  if not app or not target or target.pid ~= app:pid()
    or type(target.windowID) ~= "number" or target.windowID % 1 ~= 0
    or not target.processIdentity or target.processIdentity ~= self:_processIdentity(app:pid()) then
    self._target = nil
    hs.settings.clear(targetKey)
    return self:_notify("Select your personal Safari window with ⌃⌥⌘P, then click the link again.")
  end
  local script = string.format([[
    tell application id "com.apple.Safari"
      if not (exists window id %d) then return false
      tell window id %d
        make new tab at end of tabs with properties {URL:%s}
      end tell
      return true
    end tell
  ]], target.windowID, target.windowID, appleScriptString(url))
  local ok, result = hs.osascript.applescript(script)
  if not ok then
    return self:_notify("Could not open the tab. Check Hammerspoon's Safari permission in Privacy & Security → Automation.")
  end
  if result ~= true then
    self._target = nil
    hs.settings.clear(targetKey)
    return self:_notify("That window was closed. Select your personal window with ⌃⌥⌘P.")
  end
  return true
end

function obj:_mouseEvent(event)
  local types = hs.eventtap.event.types
  local kind = event:getType()
  if kind == types.keyDown then
    self._lastClick = nil
    return false
  end
  if kind == types.leftMouseDragged then
    self._lastClick = nil
    if self._captured then self._captured.dragged = true; return true end
    return false
  end
  if kind == types.leftMouseUp then
    local captured = self._captured
    self._captured = nil
    if not captured then return false end
    local point = event:location()
    local distance = (point.x - captured.point.x)^2 + (point.y - captured.point.y)^2
    if not captured.dragged and distance <= 36 then
      -- Never run synchronous Safari automation inside an input event callback.
      hs.timer.doAfter(0, function()
        if self._running then self:openPersonal(captured.url) end
      end)
    end
    return true
  end
  if kind ~= types.leftMouseDown then return false end
  self._captured = nil
  self._lastClick = nil
  if not self:_modifierOnly(event:getFlags()) then return false end

  local point = event:location()
  local app = hs.application.frontmostApplication()
  local pid = app and app:pid() or -1
  local deadline = hs.timer.absoluteTime() / 1e9 + axBudget
  -- A per-app timeout bounds hit-testing without changing Hammerspoon's global
  -- Accessibility timeout, which other Spoons may have configured.
  local ok, element = pcall(function()
    if not app then return nil end
    local ax = hs.axuielement.applicationElement(app)
    if not ax or not ax:setTimeout(axQueryTimeout) then return nil end
    return ax:elementAtPosition(point)
  end)
  if not ok then element = nil end
  local url
  if element then
    local found, value = pcall(function()
      pid = element:pid() or pid
      return self:_linkAt(element, deadline)
    end)
    if found then url = value end
  end
  if url then
    self._captured = { url = url, point = point }
    return true
  end
  -- Apps that do not expose links to Accessibility can still use URL routing.
  self._lastClick = { time = hs.timer.absoluteTime() / 1e9, pid = pid }
  return false
end

function obj:_handleURL(scheme, host, params, url, senderPID)
  local click = self._lastClick
  local elapsed = click and (hs.timer.absoluteTime() / 1e9 - click.time)
  if click and (elapsed < 0 or elapsed > self.gestureTimeout) then self._lastClick = nil end
  local sameApp = click and (not senderPID or senderPID < 0
    or click.pid < 0 or click.pid == senderPID)
  if isWebURL(url) and click and sameApp and elapsed >= 0 and elapsed <= self.gestureTimeout then
    self._lastClick = nil
    return self:openPersonal(url)
  end
  if self._previousCallback then
    return self._previousCallback(scheme, host, params, url, senderPID)
  end
  -- Explicit app routing avoids recursively calling our own default handler.
  if not hs.urlevent.openURLWithBundle(url, safari) then
    return self:_notify("Safari could not open the link.")
  end
  return true
end

--- PersonalSafari:makeDefaultBrowser() -> self
--- Ask macOS to route external links through Hammerspoon (one system confirmation).
function obj:makeDefaultBrowser()
  self:start()
  local previous = hs.urlevent.getDefaultHandler("https")
  if previous and previous ~= hs.processInfo.bundleID then
    hs.settings.set(browserKey, previous)
  end
  hs.urlevent.setDefaultHandler("http")
  return self
end

--- PersonalSafari:restoreDefaultBrowser() -> self
--- Restore the previous default browser, if Hammerspoon is still the default.
function obj:restoreDefaultBrowser()
  if hs.urlevent.getDefaultHandler("https") == hs.processInfo.bundleID then
    hs.urlevent.setDefaultHandler("http", hs.settings.get(browserKey) or safari)
  end
  return self
end

--- PersonalSafari:bindHotkeys(map) -> self
--- Supported actions: selectWindow.
function obj:bindHotkeys(map)
  hs.spoons.bindHotkeysToSpec({ selectWindow = function() self:selectWindow() end }, map)
  return self
end

--- PersonalSafari:start() -> self
--- Start link interception and install the external URL callback. Idempotent.
function obj:start()
  if self._running then return self end
  self._target = hs.settings.get(targetKey)
  self._previousCallback = hs.urlevent.httpCallback
  self._callback = function(...) return self:_handleURL(...) end
  hs.urlevent.httpCallback = self._callback
  self._running = true
  local types = hs.eventtap.event.types
  self._tap = hs.eventtap.new({ types.leftMouseDown, types.leftMouseUp,
    types.leftMouseDragged, types.keyDown }, function(event) return self:_mouseEvent(event) end):start()
  if self.showMenu then
    self._menu = hs.menubar.new()
    if self._menu then
      self._menu:setTitle("↗")
      self._menu:setTooltip("Personal Safari — Shift-click links")
      self._menu:setMenu(function()
        local active = hs.urlevent.getDefaultHandler("https") == hs.processInfo.bundleID
        return {
          { title = "Personal Safari", disabled = true },
          { title = "Select current Safari window (⌃⌥⌘P)", fn = function() self:selectWindow() end },
          { title = "-" },
          { title = "Route links from other apps…", checked = active,
            fn = function() self:makeDefaultBrowser() end },
          { title = "Restore previous default browser", disabled = not active,
            fn = function() self:restoreDefaultBrowser() end },
        }
      end)
    end
  end
  return self
end

--- PersonalSafari:stop() -> self
--- Stop interception. If still the default browser, keep ordinary links working.
function obj:stop()
  if not self._running then return self end
  self._running = false
  if self._tap then self._tap:stop(); self._tap = nil end
  if self._menu then self._menu:delete(); self._menu = nil end
  self._captured, self._lastClick = nil, nil
  if hs.urlevent.httpCallback == self._callback then
    local fallback = function(_, _, _, url) return hs.urlevent.openURLWithBundle(url, safari) end
    hs.urlevent.httpCallback = self._previousCallback
      or (hs.urlevent.getDefaultHandler("https") == hs.processInfo.bundleID and fallback or nil)
  end
  return self
end

return obj
