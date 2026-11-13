--- === MissionControlSend ===
--- Shift-click a Mission Control window to send it to another desktop.
local obj={name='MissionControlSend',version='0.2.1',_eventTag=0x4d4353,_eventNumber=32000}

function obj._inside(p,f)
  return f and p.x>=f.x and p.x<f.x+f.w and p.y>=f.y and p.y<f.y+f.h
end
function obj._titleMatches(short,title)
  if not short or not title or short=='' then return false end
  if short==title then return true end
  local first,last=short:match('^(.-)…(.*)$')
  return first~=nil and #first>=8 and title:sub(1,#first)==first and (last=='' or title:sub(-#last)==last)
end
local function locked()
  local state=hs.caffeinate.sessionProperties()
  return not state or state.CGSSessionScreenIsLocked==true
end
local function children(e) return e and e.AXChildren or {} end
local function center(f) return {x=f.x+f.w/2,y=f.y+f.h/2} end
local function distance(a,b) return math.sqrt((a.x-b.x)^2+(a.y-b.y)^2) end
function obj:_budget()
  if self._deadline and hs.timer.absoluteTime()/1e9>self._deadline then error('thumbnail inspection timed out') end
end

-- Restrict inspection to Mission Control; Stage Manager and App Exposé lack
-- the desktop strip and must never receive this gesture.
function obj:_displays()
  local found={}
  for _,bundle in ipairs({'com.apple.WindowManager','com.apple.dock'}) do
    self:_budget()
    local app=hs.application.get(bundle)
    if app then
      local root=hs.axuielement.applicationElement(app)
      if root and root:setTimeout(0.04) then
        local nodes=children(root)
        if bundle=='com.apple.dock' then
          local group
          for _,e in ipairs(nodes) do if e.AXIdentifier=='mc' then group=e; break end end
          nodes=children(group)
        end
        for _,e in ipairs(nodes) do
          self:_budget()
          if e.AXIdentifier=='mc.display' then
            for _,part in ipairs(children(e)) do
              if part.AXIdentifier=='mc.spaces' then
                for _,list in ipairs(children(part)) do
                  if list.AXIdentifier=='mc.spaces.list' then
                    found[#found+1]={element=e,root=root,list=list,modern=bundle=='com.apple.WindowManager'}
                  end
                end
              end
            end
          end
        end
        if #found>0 then return found end
      end
    end
  end
  return found
end

function obj:_screen(display)
  local f=display.element.AXFrame
  if not f then return nil end
  for _,screen in ipairs(hs.screen.allScreens()) do
    self:_budget()
    local full=screen:fullFrame()
    if math.abs(f.x-full.x)<3 and math.abs(f.y-full.y)<3 and math.abs(f.w-full.w)<3 and math.abs(f.h-full.h)<3 then return screen end
  end
end

function obj:_thumbnails(display,active)
  local out={}
  local function visit(e,depth)
    self:_budget()
    if depth>3 then return end
    local id=e.AXIdentifier or ''
    local space=tonumber(id:match('%.space%.(%d+)$'))
    if e.AXRole=='AXButton' and ((display.modern and space==active) or not display.modern) then
      out[#out+1]=e
    elseif depth==0 or id=='mc.windows' or (not display.modern and e.AXRole=='AXGroup') then
      for _,child in ipairs(children(e)) do
        if child.AXIdentifier~='mc.spaces' then visit(child,depth+1) end
      end
    end
  end
  visit(display.element,0)
  return out
end

function obj:_window(thumbnail,screen,source)
  self._matchReason='no_window_match'
  local ids=thumbnail.AXWindowsIDs
  local identifier=thumbnail.AXIdentifier or ''
  local bundle=identifier:match('^(.-)%.space%.%d+$')
  local windows={}
  local explicitID=type(ids)=='table' and #ids==1 and type(ids[1])=='number'
  if type(ids)=='table' and #ids>1 then self._matchReason='grouped_windows'; return nil end
  if explicitID then
    local w=hs.window.get(ids[1]); if w then windows={w} end
  elseif bundle then
    local app=hs.application.get(bundle)
    if app then
      local ax=hs.axuielement.applicationElement(app)
      if not ax or not ax:setTimeout(0.04) then return nil end
      windows=app:allWindows()
    end
  else windows=hs.window.visibleWindows() end
  local eligible={}
  for _,w in ipairs(windows) do
    self:_budget()
    local spaces=hs.spaces.windowSpaces(w) or {}
    local s=w:screen()
    if w:isStandard() and not w:isFullScreen() and s and s:getUUID()==screen:getUUID()
      and #spaces==1 and spaces[1]==source then
      eligible[#eligible+1]=w
    end
  end
  -- A unique native ID or a single eligible window from the identified app
  -- does not depend on Mission Control's aggressively shortened title.
  if #eligible==1 and (explicitID or bundle) then return eligible[1] end
  local match
  for _,w in ipairs(eligible) do
    if self._titleMatches(thumbnail.AXTitle,w:title()) then
      if match then self._matchReason='ambiguous_window'; return nil end
      match=w
    end
  end
  return match
end

function obj:_target(screen)
  local desktops={}
  for _,space in ipairs(hs.spaces.spacesForScreen(screen) or {}) do
    if hs.spaces.spaceType(space)=='user' then desktops[#desktops+1]=space end
  end
  if self.desktop then return desktops[self.desktop] end
  if #desktops<2 then return nil end
  local active=hs.spaces.activeSpaceOnScreen(screen)
  for i,space in ipairs(desktops) do
    if space==active then return desktops[i%#desktops+1] end
  end
end

function obj:_candidate(point)
  self.lastCaptureReason='mission_control_not_visible'
  for _,display in ipairs(self:_displays()) do
    self.lastCaptureReason='screen_or_desktop_strip'
    local screen=self:_screen(display)
    if screen and self._inside(point,screen:fullFrame()) and not self._inside(point,display.list.AXFrame) then
      local source=hs.spaces.activeSpaceOnScreen(screen)
      local target=self:_target(screen)
      self.lastCaptureReason='no_destination'
      if target and hs.spaces.spaceType(source)=='user' then
        self.lastCaptureReason='hit_not_in_active_thumbnails'
        local hit=display.root:elementAtPosition(point)
        local ancestors={}
        local ancestor=hit
        for _=1,6 do if not ancestor then break end; ancestors[#ancestors+1]=ancestor; ancestor=ancestor.AXParent end
        local covering={}
        for _,thumbnail in ipairs(self:_thumbnails(display,source)) do
          if self._inside(point,thumbnail.AXFrame) then covering[#covering+1]=thumbnail end
          for _,ancestor in ipairs(ancestors) do
            if thumbnail==ancestor and self._inside(point,thumbnail.AXFrame) then
              local window=self:_window(thumbnail,screen,source)
              self.lastCaptureReason=window and 'matched' or self._matchReason
              if window then return {id=window:id(),pid=window:application():pid(),source=source,target=target,screen=screen:getUUID(),point=point} end
            end
          end
        end
        -- WindowManager can hit-test an invisible thumbnail from another
        -- desktop. Recover only when exactly one active-desktop thumbnail
        -- covers the point, and the hidden hit belongs to this display/owner.
        local hitSpace=hit and tonumber((hit.AXIdentifier or ''):match('%.space%.(%d+)$'))
        if display.modern and hitSpace and hitSpace~=source and hit.AXRole=='AXButton'
          and hs.spaces.spaceDisplay(hitSpace)==screen:getUUID()
          and hit:pid()~=nil and hit:pid()==display.root:pid() and #covering==1 then
          local window=self:_window(covering[1],screen,source)
          self.lastCaptureReason=window and 'matched_visible_thumbnail' or self._matchReason
          if window then return {id=window:id(),pid=window:application():pid(),source=source,target=target,screen=screen:getUUID(),point=point} end
        end
      end
    end
  end
end

-- Re-resolve the exact window, source desktop and destination on every stage.
function obj:_resolve(item)
  if locked() then return nil end
  local window=hs.window.get(item.id)
  if not window or window:application():pid()~=item.pid then return nil end
  local spaces=hs.spaces.windowSpaces(window) or {}
  if #spaces~=1 or spaces[1]~=item.source then return nil end
  for _,display in ipairs(self:_displays()) do
    local screen=self:_screen(display)
    if screen and screen:getUUID()==item.screen and hs.spaces.activeSpaceOnScreen(screen)==item.source
      and self:_target(screen)==item.target then
      local match
      for _,thumbnail in ipairs(self:_thumbnails(display,item.source)) do
        local w=self:_window(thumbnail,screen,item.source)
        if w and w:id()==item.id then if match then return nil end; match=thumbnail end
      end
      if match then return display,match,screen end
    end
  end
end

function obj:_later(delay,fn)
  local epoch=self._epoch
  self._timer=hs.timer.doAfter(delay,function()
    self._timer=nil
    if self._running and self._epoch==epoch then
      local ok,err=pcall(fn)
      if not ok then self.lastError=tostring(err); self:_finish(false,'Could not move that window.') end
    end
  end)
end

function obj:_mouse(kind,point,number,previous)
  local properties=hs.eventtap.event.properties
  local event=hs.eventtap.event.newMouseEvent(kind,point):rawFlags(0)
    :setProperty(properties.eventSourceUserData,self._eventTag)
  if number then
    event:setProperty(properties.mouseEventNumber,number):setProperty(properties.mouseEventClickState,1)
    if previous then
      event:setProperty(properties.mouseEventDeltaX,math.floor(point.x)-math.floor(previous.x))
        :setProperty(properties.mouseEventDeltaY,math.floor(point.y)-math.floor(previous.y))
    end
  end
  event:post()
end

function obj:_finish(success,message,userInterrupted)
  local moving=self._moving
  if self._timer then self._timer:stop(); self._timer=nil end
  if moving and moving.buttonDown then
    -- Escape cancels the incomplete drag; release at its starting point.
    for _,down in ipairs({true,false}) do
      hs.eventtap.event.newKeyEvent({},'escape',down):setProperty(hs.eventtap.event.properties.eventSourceUserData,self._eventTag):post()
    end
    self:_mouse(hs.eventtap.event.types.leftMouseUp,moving.start,moving.number)
  end
  self._moving=nil
  self.lastResult=success and 'moved' or 'canceled_or_failed'
  if moving and not userInterrupted and not locked() then
    self:_mouse(hs.eventtap.event.types.mouseMoved,moving.item.point)
  end
  if message then hs.alert.show(message) end
end

function obj:_verify(item,attempt)
  local spaces=hs.spaces.windowSpaces(item.id) or {}
  local w=hs.window.get(item.id)
  if w and w:application():pid()==item.pid and #spaces==1 and spaces[1]==item.target then
    self:_finish(true)
  elseif attempt<8 then self:_later(0.1,function() self:_verify(item,attempt+1) end)
  else self:_finish(false,'macOS did not move that window. No automatic retry was made.') end
end

function obj:_dropPoint(display,screen,target)
  local buttons=children(display.list)
  local spaces=hs.spaces.spacesForScreen(screen) or {}
  if #buttons~=#spaces then return nil end
  for index,space in ipairs(spaces) do
    if space==target then
      local button=buttons[index]
      if button.AXRole~='AXButton' then return nil end
      local bar=display.list.AXFrame
      if not bar or bar.h<=40 then return nil end
      local point=display.modern and button.AXPosition or (button.AXFrame and center(button.AXFrame))
      if point and self._inside(point,bar) then return {x=point.x,y=point.y} end
    end
  end
end

function obj:_drag(item)
  local display,thumbnail,screen=self:_resolve(item)
  if not display then self:_finish(false,'Mission Control changed; move canceled.'); return end
  local target=self:_dropPoint(display,screen,item.target)
  local frame=thumbnail.AXFrame
  if not target or not frame then self:_finish(false,'Could not locate the destination desktop.'); return end
  local start=center(frame)
  local span=distance(start,target)
  if span<=8 then self:_finish(false); return end
  self._eventNumber=self._eventNumber+1
  local moving=self._moving
  local layout={}
  for i,space in ipairs(hs.spaces.spacesForScreen(screen) or {}) do layout[i]=space end
  moving.start=start; moving.number=self._eventNumber; moving.buttonDown=true
  local types=hs.eventtap.event.types
  self:_mouse(types.mouseMoved,start)
  self:_mouse(types.leftMouseDown,start,moving.number)
  local previous=start
  local settled=0
  local function step(index)
    local d,_,s=self:_resolve(item)
    local fresh=d and self:_dropPoint(d,s,item.target)
    local currentLayout=s and hs.spaces.spacesForScreen(s) or {}
    local sameLayout=#currentLayout==#layout
    for i,space in ipairs(layout) do if currentLayout[i]~=space then sameLayout=false end end
    if not fresh or not sameLayout then self:_finish(false,'Desktop layout changed; move canceled.'); return end
    if index>60 then self:_finish(false,'Desktop animation did not settle; move canceled.'); return end
    -- Thumbnail positions animate as the strip expands and a drag begins.
    -- Follow the same desktop ID, while rejecting real changes to space order.
    local remaining=distance(previous,fresh)
    if remaining>2 then
      settled=0
      local length=math.min(index==1 and 8 or 80,remaining)
      local point={x=previous.x+(fresh.x-previous.x)*length/remaining,y=previous.y+(fresh.y-previous.y)*length/remaining}
      self:_mouse(types.leftMouseDragged,point,moving.number,previous); previous=point
      self:_later(0.02,function() step(index+1) end)
    else
      settled=settled+1
      if settled<3 then self:_later(0.02,function() step(index+1) end)
      else
        self:_mouse(types.leftMouseUp,fresh,moving.number); moving.buttonDown=false
        self.lastResult='verifying'
        self:_later(0.1,function() self:_verify(item,1) end)
      end
    end
  end
  self:_later(0.02,function() step(1) end)
end

function obj:_begin(item,attempt)
  attempt=attempt or 0
  if self._pending~=item then return end
  if distance(hs.mouse.absolutePosition(),item.point)>6 or attempt>=40 then self._pending=nil; return end
  local flags=hs.eventtap.checkKeyboardModifiers()
  if flags.cmd or flags.alt or flags.ctrl or flags.fn then self._pending=nil; return end
  if flags.shift then self:_later(0.025,function() self:_begin(item,attempt+1) end); return end
  self._pending=nil
  if item.source==item.target then self.lastResult='already_there'; return end
  if self._moving or locked() then return end
  local display,_,screen=self:_resolve(item)
  if not display then self.lastResult='stale_click'; return end
  self._moving={item=item}
  self.lastResult='moving'
  local full=screen:fullFrame()
  self:_mouse(hs.eventtap.event.types.mouseMoved,{x=full.x+full.w/2,y=full.y+20})
  self:_later(0.3,function() self:_drag(item) end)
end

function obj:_event(event)
  local types=hs.eventtap.event.types
  if event:getProperty(hs.eventtap.event.properties.eventSourceUserData)==self._eventTag then return false end
  local kind=event:getType()
  if self._moving then self:_finish(false,nil,true); return false end
  if self._pending and (kind==types.leftMouseDown or kind==types.keyDown or
    ((kind==types.mouseMoved or kind==types.leftMouseDragged) and distance(event:location(),self._pending.point)>6)) then
    self._pending=nil
    if self._timer then self._timer:stop(); self._timer=nil end
  end
  if kind==types.leftMouseDown then self._captured=nil end
  if self._captured then
    if kind==types.leftMouseDragged or (kind==types.mouseMoved and distance(event:location(),self._captured.point)>6) then self._canceled=true end
    if kind==types.keyDown then self._canceled=true end
    if kind==types.leftMouseUp then
      local item=self._captured; self._captured=nil
      local flags=event:getFlags()
      if not self._canceled and not flags.cmd and not flags.alt and not flags.ctrl and not flags.fn and distance(event:location(),item.point)<=6 then
        self._pending=item
        self:_later(0,function() self:_begin(item) end)
      end
      return true
    end
    return kind==types.leftMouseDragged
  end
  if kind~=types.leftMouseDown or locked() then return false end
  local flags=event:getFlags()
  if not flags.shift or flags.cmd or flags.alt or flags.ctrl or flags.fn then return false end
  self._deadline=hs.timer.absoluteTime()/1e9+0.12
  local ok,item=pcall(self._candidate,self,event:location())
  self._deadline=nil
  if not ok then self.lastError=tostring(item); self.lastCaptureReason='inspection_error' end
  if not ok or not item then self.lastResult='not_a_window_thumbnail'; return false end
  self._captured=item; self._canceled=false
  self.lastResult='captured'
  return true
end

function obj:start()
  self:stop()
  assert(self.desktop==nil or (type(self.desktop)=='number' and self.desktop>=1 and self.desktop%1==0),'desktop must be nil (next desktop) or a positive integer')
  self._running=true; self.lastResult='ready'
  local t=hs.eventtap.event.types
  self._tap=hs.eventtap.new({t.leftMouseDown,t.leftMouseUp,t.leftMouseDragged,t.mouseMoved,t.keyDown,t.flagsChanged},function(e) return self:_event(e) end):start()
  self._previousShutdown=hs.shutdownCallback
  self._shutdown=function() local previous=self._previousShutdown; self:stop(); if previous then previous() end end
  hs.shutdownCallback=self._shutdown
  return self
end

function obj:stop()
  if self._moving then self:_finish(false) end
  self._running=false; self._epoch=(self._epoch or 0)+1
  if self._timer then self._timer:stop(); self._timer=nil end
  if self._tap then self._tap:stop(); self._tap=nil end
  self._captured=nil
  self._pending=nil
  if self._shutdown and hs.shutdownCallback==self._shutdown then hs.shutdownCallback=self._previousShutdown end
  return self
end
return obj
