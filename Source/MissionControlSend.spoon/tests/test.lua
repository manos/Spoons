local spoon=dofile(assert(arg[1]))
assert(spoon._titleMatches('Long window…ending','Long window title ending'))
assert(not spoon._titleMatches('A…','Another window'),'short ambiguous titles must not match')
assert(spoon._titleMatches('Exact','Exact'))
assert(not spoon._titleMatches('Exact','Different'))
assert(spoon._inside({x=10,y=10},{x=0,y=0,w=20,h=20}))
assert(not spoon._inside({x=20,y=10},{x=0,y=0,w=20,h=20}))
local types={leftMouseDown=1,leftMouseUp=2,leftMouseDragged=3,mouseMoved=4,keyDown=5,flagsChanged=6}
local locked=false
local calls,timers,moved=0,{},nil
hs={eventtap={event={types=types,properties={eventSourceUserData=1}}},
  caffeinate={sessionProperties=function() return {CGSSessionScreenIsLocked=locked} end},
  timer={absoluteTime=function() return 0 end,doAfter=function(_,fn) local t={fn=fn,stop=function(self) self.stopped=true end}; timers[#timers+1]=t; return t end},
  alert={show=function() end}}
local target={point={x=10,y=10},target=2,source=1}
spoon._candidate=function() calls=calls+1; return target end
spoon._begin=function(_,item) moved=item end
spoon._running=true
local function event(kind,flags,x,y,tag)
 return {getType=function() return kind end,getFlags=function() return flags or {} end,
  location=function() return {x=x or 10,y=y or 10} end,getProperty=function() return tag or 0 end}
end
assert(not spoon:_event(event(types.leftMouseDown)))
assert(calls==0,'ordinary clicks must not inspect or alter windows')
assert(not spoon:_event(event(types.leftMouseDown,{shift=true,cmd=true})))
locked=true; assert(not spoon:_event(event(types.leftMouseDown,{shift=true}))); locked=false
assert(calls==0,'locked session must ignore gesture')
spoon._candidate=function() calls=calls+1; return nil end
assert(not spoon:_event(event(types.leftMouseDown,{shift=true})),'outside Mission Control, Shift-click remains native')
spoon._candidate=function() return target end
assert(spoon:_event(event(types.leftMouseDown,{shift=true})))
assert(spoon:_event(event(types.leftMouseUp,{})),'release is consumed even after releasing Shift')
assert(not moved,'work must be deferred out of the event callback')
timers[#timers].fn(); assert(moved==target)
moved=nil
assert(spoon:_event(event(types.leftMouseDown,{shift=true})))
assert(spoon:_event(event(types.leftMouseDragged,{shift=true},40,10)))
assert(spoon:_event(event(types.leftMouseUp,{},40,10)))
assert(not moved,'Shift-drag must cancel instead of moving the wrong thumbnail')
assert(not spoon:_event(event(types.leftMouseDown,{shift=true},10,10,spoon._eventTag)),'synthetic input must not recurse')
print('PASS MissionControlSend native clicks, modifiers, locked session, release, drag cancellation and synthetic guards')

-- Model the WindowManager AX boundary and the native event stream. Verification
-- must inspect actual space membership rather than trust a posted mouse-up.
local client=dofile(arg[1])
local currentSpace,ignoreDrop=11,false
local secondWindow=false
local screen={getUUID=function() return 'fixture-screen' end,fullFrame=function() return {x=0,y=0,w=1200,h=800} end}
local app={pid=function() return 100 end}
local window={id=function() return 200 end,application=function() return app end,screen=function() return screen end,
  isStandard=function() return true end,isFullScreen=function() return false end,title=function() return 'Fixture window' end}
app.allWindows=function() return secondWindow and {window,window} or {window} end
local bar={AXIdentifier='mc.spaces.list',AXFrame={x=0,y=0,w=1200,h=100},AXChildren={}}
for i=1,3 do bar.AXChildren[i]={AXRole='AXButton',AXPosition={x=150*i,y=50},AXParent=bar} end
local thumb={AXRole='AXButton',AXIdentifier='example.app.space.11',AXTitle='Fixture window',AXFrame={x=100,y=200,w=200,h=200}}
local display={AXIdentifier='mc.display',AXFrame=screen:fullFrame(),AXChildren={thumb,{AXIdentifier='mc.spaces',AXChildren={bar}}}}
thumb.AXParent=display
local root={AXChildren={display},setTimeout=function() return true end,elementAtPosition=function() return thumb end}
local pointer={x=150,y=250}
local shift=false
local posts={}
local downNumber=nil
local animateDesktop=false
local reorderOnDrag=false
local desktopOrder={11,99,22}
local activeSpace=11
hs.application={get=function(bundle) if bundle=='com.apple.WindowManager' then return {} elseif bundle=='example.app' then return app end end}
hs.axuielement={applicationElement=function() return root end}
hs.screen={allScreens=function() return {screen} end}
hs.window={get=function(id) if id==200 then return window end end,visibleWindows=function() return {window} end}
hs.spaces={spacesForScreen=function() return desktopOrder end,spaceType=function(id) return id==99 and 'fullscreen' or 'user' end,
  activeSpaceOnScreen=function() return activeSpace end,windowSpaces=function() return {currentSpace} end}
hs.mouse={absolutePosition=function() return pointer end}
hs.eventtap.checkKeyboardModifiers=function() return shift and {shift=true} or {} end
hs.eventtap.event.properties={eventSourceUserData=1,mouseEventNumber=2,mouseEventClickState=3,mouseEventDeltaX=4,mouseEventDeltaY=5}
local function generated(kind,point)
 local props={}
 local e={rawFlags=function(self) return self end,setProperty=function(self,k,v)
  if k==4 or k==5 then assert(v%1==0,'native mouse deltas must be integers') end
  props[k]=v; return self
 end}
 e.post=function()
  assert(props[1]==client._eventTag,'all generated input must carry a recursion marker')
  posts[#posts+1]={kind=kind,point=point,number=props[2]}
  if kind==types.leftMouseDown then
   downNumber=props[2]
   if animateDesktop then bar.AXChildren[3].AXPosition={x=535,y=50} end
  elseif kind==types.leftMouseDragged then
   assert(props[2]==downNumber,'drag must share its mouse event number')
   if reorderOnDrag then desktopOrder={11,22,99} end
  elseif kind==types.leftMouseUp then
   assert(props[2]==downNumber,'release must share its mouse event number')
   if point.x==bar.AXChildren[3].AXPosition.x and point.y==50 and not ignoreDrop then currentSpace=22 end
   downNumber=nil
  end
 end
 return e
end
hs.eventtap.event.newMouseEvent=generated
hs.eventtap.event.newKeyEvent=function() return generated('key',{}) end
client._running=true
local candidate=assert(client:_candidate(pointer))
assert(candidate.id==200 and candidate.target==22,'Desktop 2 counts ordinary desktops, skipping fullscreen spaces')
activeSpace=22; assert(client:_target(screen)==11,'next desktop must wrap from the last to the first'); activeSpace=11
thumb.AXTitle='Fi'
assert(client:_candidate(pointer),'a unique app window must still resolve when Mission Control shortens its title to two characters')
secondWindow=true; assert(not client:_candidate(pointer),'short titles must not guess between multiple app windows'); secondWindow=false
thumb.AXTitle='Fixture window'
secondWindow=true; assert(not client:_candidate(pointer),'ambiguous thumbnail titles must pass through'); secondWindow=false
thumb.AXIdentifier='example.app.space.22'; assert(not client:_candidate(pointer),'hidden thumbnails from another space must be ignored'); thumb.AXIdentifier='example.app.space.11'
display.AXChildren={thumb}; assert(not client:_candidate(pointer),'App Exposé without a desktop strip must pass through')
display.AXChildren={thumb,{AXIdentifier='mc.spaces',AXChildren={bar}}}
local function drain()
 local count=0
 while #timers>0 do
  count=count+1; assert(count<150,'timer loop must be bounded')
  local t=table.remove(timers,1); if not t.stopped then t.fn() end
 end
end
timers={}; client._pending=candidate; shift=true; client:_begin(candidate)
assert(#posts==0 and #timers==1,'wait for Shift release before generating drag')
shift=false; drain()
assert(currentSpace==22 and client.lastResult=='moved' and not downNumber,'drag must land on selected desktop and verify')
currentSpace=11; posts={}; timers={}; animateDesktop=true
client._pending=candidate; client:_begin(candidate); drain()
assert(currentSpace==22 and client.lastResult=='moved','desktop thumbnail animation must not cancel a move to the same desktop')
animateDesktop=false; bar.AXChildren[3].AXPosition={x=450,y=50}
currentSpace=11; posts={}; timers={}; reorderOnDrag=true
client._pending=candidate; client:_begin(candidate); drain()
assert(currentSpace==11 and client.lastResult=='canceled_or_failed' and not downNumber,'a real desktop reorder must still cancel and release the mouse')
reorderOnDrag=false; desktopOrder={11,99,22}
currentSpace=11; posts={}; timers={}; ignoreDrop=true
client._pending=candidate; client:_begin(candidate); drain()
assert(client.lastResult=='canceled_or_failed','ignored native drag must not report success')
local downs=0; for _,p in ipairs(posts) do if p.kind==types.leftMouseDown then downs=downs+1 end end
assert(downs==1,'failed move must not automatically retry')
posts={}; timers={}; ignoreDrop=false
client._pending=candidate; client:_begin(candidate)
client:_event(event(types.mouseMoved,{},500,500)); drain()
assert(#posts==1 and not client._moving,'real input cancels before pressing the mouse')
client._pending=candidate; timers={}; client:_begin(candidate)
client:stop(); drain()
assert(not client._moving and not client._running,'stop cancels pending work')
print('PASS MissionControlSend desktop numbering, ambiguous/hidden thumbnails, animated destination, reorder cancellation, modifier release and verified drag')
