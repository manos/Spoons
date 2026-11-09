local file = assert(arg[1], 'Pass the Spoon init.lua path')
hs = {}
local f = io.open(file)
local spoon = f and dofile(file) or {}; if f then f:close() end
assert(type(spoon._choices) == 'function', 'Tab group menu parsing is not implemented')
local function item(title, id, mark, enabled)
  local attrs = {AXRole='AXMenuItem', AXTitle=title, AXIdentifier=id,
    AXMenuItemMarkChar=mark, AXEnabled=enabled ~= false}
  return {attributeValue=function(_, key) return attrs[key] end, setTimeout=function() end}
end
local menu = {attributeValue=function() return {
  item('', '_popUpItemAction:'),
  item('9 Tabs', 'LocalTabGroupPickerMenuItem', '✓'),
  item('Work 🤖', 'Work 🤖TabGroupPickerMenuItem'),
  item('New Empty Tab Group', 'NewEmptyTabGroupPickerMenuItem'),
  item('Unavailable', 'UnavailableTabGroupPickerMenuItem', nil, false),
  item('Renamed', 'OldNameTabGroupPickerMenuItem'),
  item('Travel', 'TravelTabGroupPickerMenuItem'),
} end, setTimeout=function() end}
local choices = spoon._choices(menu)
assert(#choices == 3, 'Only enabled, verified group entries should appear')
assert(choices[1].text == '9 Tabs' and choices[1].current, 'Keep current ungrouped tabs')
assert(choices[2].text == 'Work 🤖' and not choices[2].current, 'Keep Unicode group names')
assert(choices[3].text == 'Travel', 'Preserve Safari group order')
assert(choices[2].id == 'Work 🤖TabGroupPickerMenuItem', 'Keep exact identity for selection')
print('PASS: filters commands, disabled and stale entries; keeps local tabs, Unicode, order and identity')

-- A chooser result must never switch a different window or app.
local pending, reads, alerts = {}, 0, 0
local activePid, activeWindow = 10, 20
hs.application = {frontmostApplication=function()
  return {pid=function() return activePid end, bundleID=function() return 'com.apple.Safari' end,
    focusedWindow=function() return {id=function() return activeWindow end} end}
end}
hs.timer = {doAfter=function(_, fn)
  pending[#pending+1] = fn
  return {stop=function() end}
end}
hs.alert = {show=function() alerts=alerts+1 end}
local target = {pid=10, id=20, axWindow={attributeValue=function() reads=reads+1 end}}
local function runPending()
  local callbacks = pending; pending = {}
  for _, callback in ipairs(callbacks) do callback() end
end
spoon:_select({text='Travel', id='TravelTabGroupPickerMenuItem'}, target)
activeWindow = 21
runPending()
assert(spoon.lastResult == 'cancelled' and reads == 0, 'Changing windows must cancel before accessing the menu')
activeWindow, activePid = 20, 11
spoon:_select({text='Travel', id='TravelTabGroupPickerMenuItem'}, target)
runPending()
assert(spoon.lastResult == 'cancelled' and reads == 0, 'A different Safari process must not receive the selection')
activePid = 10
spoon:_select({text='9 Tabs', current=true}, target)
runPending()
assert(spoon.lastResult == 'unchanged' and reads == 0, 'Choosing the current group must not reopen its menu')
spoon:_select(nil, target)
assert(spoon.lastResult == 'dismissed' and #pending == 0, 'Escape must not schedule a switch')
print('PASS: window/process guards, current-group no-op and Escape cancellation')
