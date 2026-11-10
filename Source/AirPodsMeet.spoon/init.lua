--- === AirPodsMeet ===
--- Bridge rejected AirPods mute presses to the selected Safari Meet call.
local obj = {
  name = 'AirPodsMeet', version = '0.3.0', speakStatus = true,
  soundVolume = 0.8, announcementDelay = 0.6,
}
local resourcePath = (debug.getinfo(1, 'S').source:sub(2):match('^(.*)/') or '.') .. '/'
local PREFIX = 'Mute Control: '
local SOURCE = PREFIX .. 'app bundle identifier set for mute action: '
local REQUEST_WINDOW = 2

local function now() return hs.timer.absoluteTime() / 1e9 end
local function attr(element, key)
  if not element then return nil end
  element:setTimeout(0.025)
  return element:attributeValue(key)
end

function obj._isMeetURL(url)
  if type(url) == 'table' then url = url.url end
  if type(url) ~= 'string' then return false end
  url = url:gsub('^https://meet%.google%.com/meet/', 'https://meet.google.com/', 1)
  local suffix = url:match('^https://meet%.google%.com/%l%l%l%-%l%l%l%l%-%l%l%l(.*)$')
  return suffix ~= nil and (suffix == '' or suffix == '/' or suffix:match('^[?#]') ~= nil)
end

function obj._buttonState(label)
  if type(label) ~= 'string' then return nil end
  if label:match('^Turn off microphone') then return 'unmuted' end
  if label:match('^Turn on microphone') then return 'muted' end
end

function obj:_cancelAnnouncement()
  if self._announceTimer then self._announceTimer:stop(); self._announceTimer = nil end
  self._announcementToken = nil
end

function obj:_announce(state)
  self:_cancelAnnouncement()
  if not self.speakStatus or (state ~= 'muted' and state ~= 'unmuted') then return end
  local token = {}
  self._announcementToken = token
  self._announceTimer = hs.timer.doAfter(self.announcementDelay, function()
    if self._announcementToken ~= token then return end
    self._announceTimer, self._announcementToken = nil, nil
    self:_playAnnouncement(state)
  end)
end

function obj:_playAnnouncement(state)
  if not self.speakStatus or (state ~= 'muted' and state ~= 'unmuted') then return end
  if self._sound then self._sound:stop(); self._sound = nil end
  if self._voice then self._voice:stop() end
  self._sound = hs.sound.getByFile(resourcePath .. 'sounds/' .. state .. '.wav')
  if self._sound then
    self._sound:volume(self.soundVolume)
    if self._sound:play() then return end
  end
  self._voice = self._voice or hs.speech.new()
  self._voice:speak(state == 'muted' and 'Muted' or 'Unmuted')
end

-- Native notifications also occur on audio routing changes. Require the explicit
-- request, rejection and WebKit attribution instead of treating any change as a press.
function obj:_message(message)
  local time = now()
  if message:match('^Mute Control: AAMuteStateChanged message: %d+$') then
    self._request = {time = time}
    return
  end
  local request = self._request
  if not request or time - request.time > REQUEST_WINDOW then self._request = nil; return end
  if message == PREFIX .. 'playing RejectChimeWithBanner'
      or message == PREFIX .. 'playing RejectChimeWithoutBanner' then
    request.rejected = true
  elseif message:sub(1, #SOURCE) == SOURCE then
    request.webkit = message == SOURCE .. 'com.apple.WebKit.GPU'
  end
  if request.rejected and request.webkit then
    self._request = nil
    if self._lastGesture and time - self._lastGesture < 0.6 then return end
    self._lastGesture = time
    self:toggle()
  end
end

-- Traverse only Accessibility structure; do not collect page text or addresses.
local function walk(root, visitor, deadline, maximum)
  local queue, index = {root}, 1
  while queue[index] do
    if index > maximum or now() >= deadline then return false end
    local element = queue[index]; index = index + 1
    if attr(element, 'AXHidden') ~= true then
      local descend = visitor(element)
      if descend ~= false then
        for _, child in ipairs(attr(element, 'AXChildren') or {}) do queue[#queue + 1] = child end
      end
    end
  end
  return true
end

function obj:_controls(window)
  local deadline, areas = now() + 0.8, {}
  local complete = walk(window, function(element)
    if attr(element, 'AXRole') == 'AXWebArea' then
      if self._isMeetURL(attr(element, 'AXURL')) then areas[#areas + 1] = element end
      return false
    end
  end, deadline, 250)
  if not complete or #areas ~= 1 then return nil, 'no_unique_meet_page' end
  local microphone, state, count, inCall = nil, nil, 0, false
  complete = walk(areas[1], function(element)
    local role = attr(element, 'AXRole')
    if role == 'AXButton' then
      local found, leave = nil, false
      for _, key in ipairs({'AXTitle', 'AXDescription', 'AXHelp'}) do
        local label = attr(element, key)
        found = found or self._buttonState(label)
        if type(label) == 'string' and label:match('^Leave call') then leave = true end
      end
      if found and attr(element, 'AXEnabled') then
        microphone, state, count = element, found, count + 1
      end
      if leave and attr(element, 'AXEnabled') then inCall = true end
      return false
    end
    return role ~= 'AXStaticText' and role ~= 'AXTextField'
  end, deadline, 1500)
  if not complete then return nil, 'scan_timeout' end
  if not inCall or count ~= 1 then return nil, 'no_unique_call_controls' end
  return microphone, state
end

function obj:toggle()
  if self._busy then return end
  self:_cancelAnnouncement()
  if self._sound then self._sound:stop(); self._sound = nil end
  if self._voice then self._voice:stop() end
  self._busy = true
  local ok, failure = pcall(function()
    local app = hs.application.get('com.apple.Safari')
    local window = app and app:focusedWindow()
    if not window then self.lastResult = 'no_safari_window'; self._busy = false; return end
    local id = window:id()
    local button, state = self:_controls(hs.axuielement.windowElement(window))
    if not button then self.lastResult = state; self._busy = false; return end
    local current = app:focusedWindow()
    if not current or current:id() ~= id then self.lastResult = 'window_changed'; self._busy = false; return end
    if not button:performAction('AXPress') then self.lastResult = 'press_failed'; self._busy = false; return end
    self.lastResult = 'verifying'
    local deadline = now() + 2
    self._verify = hs.timer.doEvery(0.2, function()
      local verified, result = pcall(function()
        local focused = app:focusedWindow()
        if not focused or focused:id() ~= id then return 'window_changed' end
        local _, after = self:_controls(hs.axuielement.windowElement(focused))
        if (after == 'muted' or after == 'unmuted') and after ~= state then return after end
        if now() >= deadline then return 'unverified' end
      end)
      if not verified then result = 'unverified' end
      if result then
        self._verify:stop(); self._verify = nil; self._busy = false
        self.lastResult = result
        if self.speakStatus and (result == 'muted' or result == 'unmuted') then
          self:_announce(result)
        elseif result == 'unverified' then
          hs.alert.show('AirPods Meet: could not confirm microphone state')
        end
      end
    end)
  end)
  if not ok then self._busy = false; self.lastResult = 'accessibility_error' end
end

function obj:start()
  if self._running then return self end
  self._running = true
  self.lastResult = 'listening'
  self._buffer = ''
  local predicate = 'process == "audioaccessoryd" AND (eventMessage BEGINSWITH "Mute Control: AAMuteStateChanged message:" OR eventMessage == "Mute Control: playing RejectChimeWithBanner" OR eventMessage == "Mute Control: playing RejectChimeWithoutBanner" OR eventMessage BEGINSWITH "Mute Control: app bundle identifier set for mute action:")'
  self._task = hs.task.new('/usr/bin/log', function(code)
    if self._running then
      self._running = false; self.lastResult = 'listener_stopped'
      hs.alert.show('AirPods Meet listener stopped; reload Hammerspoon to retry')
    end
  end, function(_, output)
    if not self._running then return false end
    self._buffer = self._buffer .. (output or '')
    while true do
      local newline = self._buffer:find('\n', 1, true)
      if not newline then break end
      local line = self._buffer:sub(1, newline - 1)
      self._buffer = self._buffer:sub(newline + 1)
      local ok, event = pcall(hs.json.decode, line)
      if ok and type(event) == 'table' and type(event.eventMessage) == 'string' then
        self:_message(event.eventMessage)
      end
    end
    if #self._buffer > 16384 then self._buffer = '' end
    return true
  end, {'stream', '--style', 'ndjson', '--level', 'info', '--predicate', predicate})
  if not self._task or not self._task:start() then
    self._running = false; self.lastResult = 'listener_failed'
    hs.alert.show('AirPods Meet could not start its event listener')
  end
  if not self._shutdown then
    local previous = hs.shutdownCallback
    self._shutdown = function() self:stop(); if previous then previous() end end
    self._previousShutdown = previous
    hs.shutdownCallback = self._shutdown
  end
  return self
end

function obj:stop()
  self._running = false
  self:_cancelAnnouncement()
  if self._task and self._task:isRunning() then self._task:terminate() end
  if self._verify then self._verify:stop(); self._verify = nil end
  if self._voice then self._voice:stop() end
  if self._sound then self._sound:stop(); self._sound = nil end
  if hs.shutdownCallback == self._shutdown then hs.shutdownCallback = self._previousShutdown end
  self._shutdown = nil
  self._busy, self._request, self._buffer = false, nil, ''
  return self
end

return obj
