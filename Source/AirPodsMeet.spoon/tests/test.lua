local source = assert(arg[1])
local clock, calls = 0, 0
hs = {timer = {absoluteTime = function() return clock * 1e9 end}}
local f = io.open(source)
local spoon = f and dofile(source) or {}; if f then f:close() end
assert(type(spoon._message) == 'function', 'AirPods message handler not implemented')
spoon.toggle = function() calls = calls + 1 end
local function message(text, time) clock = time; spoon:_message(text) end
message('Mute Control: playing RejectChimeWithBanner', 1)
assert(calls == 0, 'unpaired rejection must not unmute')
message('Mute Control: AAMuteStateChanged message: 1', 2)
message('Mute Control: playing RejectChimeWithBanner', 2.1)
message('Mute Control: app bundle identifier set for mute action: com.apple.WebKit.GPU', 2.2)
assert(calls == 1, 'paired Safari rejection should trigger once')
message('Mute Control: playing RejectChimeWithBanner', 2.3)
message('Mute Control: app bundle identifier set for mute action: com.apple.WebKit.GPU', 2.4)
assert(calls == 1, 'duplicate log messages must not toggle again')
message('Mute Control: AAMuteStateChanged message: 1', 4)
message('Mute Control: playing RejectChimeWithBanner', 4.1)
message('Mute Control: app bundle identifier set for mute action: com.example.Other', 4.2)
assert(calls == 1, 'another calling app must not toggle Meet')
message('Mute Control: app bundle identifier set for mute action: com.apple.WebKit.GPU', 7)
assert(calls == 1, 'expired requests must not toggle')
assert(spoon._isMeetURL({url='https://meet.google.com/abc-defg-hij'}))
assert(not spoon._isMeetURL('https://meet.google.com.example.test/abc-defg-hij'))
assert(not spoon._isMeetURL('https://meet.google.com/'))
assert(spoon._buttonState('Turn off microphone (⌘ + d)') == 'unmuted')
assert(spoon._buttonState('Turn on microphone (⌘ + d)') == 'muted')
assert(spoon._buttonState('Turn off camera') == nil)
print('PASS: paired gesture detection, deduplication, source/expiry guards, exact Meet URL and microphone states')
assert(not spoon._isMeetURL('https://meet.google.com/abc-defg-hijextra'))
local function element(values)
  return {setTimeout=function() end, attributeValue=function(_,key) return values[key] end}
end
local mic = element({AXRole='AXButton',AXDescription='Turn on microphone (⌘ + d)',AXEnabled=true})
local leave = element({AXRole='AXButton',AXTitle='Leave call',AXEnabled=true})
local pageValues={AXRole='AXWebArea',AXURL={url='https://meet.google.com/abc-defg-hij'},AXChildren={mic,leave}}
local page=element(pageValues)
local window=element({AXChildren={page}})
local button,state=spoon:_controls(window)
assert(button==mic and state=='muted')
pageValues.AXChildren={mic}
assert(spoon:_controls(window)==nil, 'prejoin page must not toggle')
pageValues.AXChildren={mic,mic,leave}
assert(spoon:_controls(window)==nil, 'ambiguous microphone buttons must not toggle')
pageValues.AXURL='https://example.test/'
pageValues.AXChildren={mic,leave}
assert(spoon:_controls(window)==nil, 'other websites must not toggle')
print('PASS: active-call controls required; prejoin, ambiguous controls and unrelated pages ignored')
assert(spoon._isMeetURL('https://meet.google.com/meet/abc-defg-hij'), 'current Meet route must be accepted')
assert(spoon._isMeetURL({url='https://meet.google.com/meet/abc-defg-hij?authuser=1'}))
assert(not spoon._isMeetURL('https://meet.google.com/meet/abc-defg-hijextra'))
assert(not spoon._isMeetURL('https://meet.google.com.example.test/meet/abc-defg-hij'))
print('PASS: current and legacy Meet routes, query strings and lookalike rejection')

local plays, stops, spoken = {}, 0, 0
local timers = {}
hs.timer.doAfter = function(delay, callback)
  local timer = {delay=delay, callback=callback, stop=function(self) self.stopped=true end}
  timers[#timers+1]=timer
  return timer
end
hs.sound = {getByFile = function(file)
  return {stop=function() stops=stops+1 end, volume=function() end,
          play=function() plays[#plays+1]=file; return true end}
end}
hs.speech = {new=function() return {speak=function() spoken=spoken+1 end, stop=function() end} end}
assert(type(spoon._announce)=='function', 'bundled voice player missing')
spoon:_announce('muted')
assert(#plays==0 and #timers==1 and timers[1].delay==0.6, 'announcement must wait for rejection tones')
timers[1].callback()
spoon:_announce('unmuted')
timers[2].callback()
assert(#plays==2 and plays[1]:match('/sounds/muted%.wav$') and plays[2]:match('/sounds/unmuted%.wav$'))
assert(stops==1, 'new status must stop the previous announcement')
spoon:_announce('unverified')
assert(#plays==2, 'unverified microphone state must not be announced')
spoon.speakStatus=false
spoon:_announce('muted')
assert(#plays==2, 'disabled feedback must remain silent')
spoon.speakStatus=true
hs.sound.getByFile=function() return nil end
spoon:_announce('muted')
timers[#timers].callback()
assert(spoken==1, 'missing sound file must fall back to speech')
spoon:_announce('muted')
local stale = timers[#timers]
spoon:_announce('unmuted')
assert(stale.stopped, 'a new announcement must cancel the old timer')
stale.callback()
assert(spoken==1, 'a canceled timer must not announce stale microphone state')
spoon:_cancelAnnouncement()
timers[#timers].callback()
assert(spoken==1, 'stopping must prevent queued announcements')
print('PASS: bundled status clips, replacement, silence and missing-file fallback')
