--- === SafariTabGroups ===
--- Search and switch the front Safari window's tab groups.
local obj = {name = 'SafariTabGroups', version = '1.0.0', author = 'manos', license = 'MIT'}
obj.homepage = 'https://github.com/manos/Spoons'
local SAFARI = 'com.apple.Safari'
local TIMEOUT = 1.5

local function attr(element, name)
  if not element then return nil end
  element:setTimeout(0.05)
  return element:attributeValue(name)
end

-- Only inspect browser chrome, never page content or other windows.
local function find(root, predicate)
  local queue, index = {{root, 0}}, 1
  while index <= #queue and index <= 150 do
    local element, depth = table.unpack(queue[index])
    index = index + 1
    if predicate(element) then return element end
    local role = attr(element, 'AXRole')
    if depth < 6 and role ~= 'AXWebArea' and role ~= 'AXTabGroup'
        and role ~= 'AXRadioButton' and role ~= 'AXMenuBar' then
      for _, child in ipairs(attr(element, 'AXChildren') or {}) do
        queue[#queue + 1] = {child, depth + 1}
      end
    end
  end
end

local function picker(window)
  return find(window, function(element)
    return (attr(element, 'AXIdentifier') or ''):match('^TabGroupPickerButton') ~= nil
  end)
end

function obj._choices(menu)
  local choices = {}
  for _, item in ipairs(attr(menu, 'AXChildren') or {}) do
    local title, id = attr(item, 'AXTitle'), attr(item, 'AXIdentifier')
    -- Creation commands have different identifiers: never treat them as groups.
    if attr(item, 'AXRole') == 'AXMenuItem' and attr(item, 'AXEnabled')
        and type(title) == 'string' and title ~= ''
        and (id == 'LocalTabGroupPickerMenuItem' or id == title .. 'TabGroupPickerMenuItem') then
      local mark = attr(item, 'AXMenuItemMarkChar')
      local current = mark ~= nil and mark ~= ''
      choices[#choices + 1] = {text = title, id = id, current = current,
        subText = current and 'Current tab group' or 'Switch in this Safari window'}
    end
  end
  return choices
end

local function sameWindow(target)
  local app = hs.application.frontmostApplication()
  local window = app and app:focusedWindow()
  return app and app:pid() == target.pid and window and window:id() == target.id
end

function obj:_closeMenu()
  if self._menu then pcall(function() self._menu:performAction('AXCancel') end) end
  self._menu = nil
end

function obj:_stopTimer()
  if self._timer then self._timer:stop() end
  self._timer = nil
end

function obj:_fail(message)
  self:_stopTimer()
  self:_closeMenu()
  self._busy = false
  self.lastResult = 'cancelled'
  if message then hs.alert.show(message) end
end

-- Reopen the real menu for selection rather than retaining stale menu items.
function obj:_withMenu(target, callback)
  self._busy = true
  local deadline = hs.timer.absoluteTime() / 1e9 + TIMEOUT
  local pressed, button = false, nil
  self._timer = hs.timer.doEvery(0.03, function()
    local ok = pcall(function()
      if not sameWindow(target) then self:_fail(); return end
      if hs.timer.absoluteTime() / 1e9 > deadline then
        self:_fail('Safari’s tab group menu did not respond'); return
      end
      if not pressed then
        local flags = hs.eventtap.checkKeyboardModifiers()
        if flags.cmd or flags.alt or flags.ctrl or flags.shift or flags.fn then return end
        button = picker(target.axWindow)
        if not button then self:_fail('No tab group picker in this Safari window'); return end
        pressed = true
        button:performAction('AXPress')
      end
      self._menu = find(button, function(element)
        return attr(element, 'AXIdentifier') == 'TabGroupPickerMenu'
      end)
      if self._menu then
        self:_stopTimer()
        callback(self._menu)
      end
    end)
    if not ok then self:_fail('Could not read Safari’s tab groups') end
  end)
end

function obj:_select(choice, target)
  if not choice then self.lastResult = 'dismissed'; return end
  -- hs.chooser restores the original window before this deferred callback.
  self._timer = hs.timer.doAfter(0.05, function()
    self._timer = nil
    if not sameWindow(target) then self:_fail(); return end
    if choice.current then self.lastResult = 'unchanged'; return end
    self:_withMenu(target, function(menu)
      -- Match both title and identifier against a freshly read, validated list.
      local valid = false
      for _, entry in ipairs(self._choices(menu)) do
        if entry.id == choice.id and entry.text == choice.text then valid = true; break end
      end
      if valid then
        for _, item in ipairs(attr(menu, 'AXChildren') or {}) do
          if attr(item, 'AXIdentifier') == choice.id and attr(item, 'AXTitle') == choice.text then
            local result = item:performAction('AXPress')
            self._menu = nil
            self._busy = false
            self.lastResult = result and 'selected' or 'failed'
            if not result then self:_fail('Safari could not switch tab groups') end
            return
          end
        end
      end
      self:_fail('That tab group changed; open the switcher again')
    end)
  end)
end

function obj:show()
  if self.chooser and self.chooser:isVisible() then self.chooser:hide(); return self end
  if self._busy or self._timer then return self end
  local app = hs.application.frontmostApplication()
  if not app or app:bundleID() ~= SAFARI then return self end
  local window = app:focusedWindow()
  if not window then return self end
  local target = {pid = app:pid(), id = window:id(), axWindow = hs.axuielement.windowElement(window)}
  self.lastResult = 'loading'
  self:_withMenu(target, function(menu)
    local choices = self._choices(menu)
    self:_closeMenu()
    self._busy = false
    if #choices == 0 then self:_fail('No tab groups found in this Safari window'); return end
    self.chooser = hs.chooser.new(function(choice) self:_select(choice, target) end)
      :placeholderText('Switch Safari tab group…')
      :searchSubText(false):rows(math.min(#choices, 10)):width(34)
      :choices(choices):query('')
    self.lastResult = 'choosing'
    self.chooser:show()
  end)
  return self
end

function obj:bindHotkeys(mapping)
  hs.spoons.bindHotkeysToSpec({show = function() self:show() end}, mapping)
  return self
end

function obj:stop()
  if self.chooser then self.chooser:hide(); self.chooser = nil end
  self:_fail()
  return self
end

return obj
