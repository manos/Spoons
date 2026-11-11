local visible,content,escape=false,nil,nil
local app={title=function() return 'Fixture <App>' end,getMenuItems=function()
  return {{AXRole='AXMenuBarItem',AXTitle='File & Tools',AXChildren={{
    {AXRole='AXMenuItem',AXTitle='<img src="https://example.test/leak">',AXMenuItemCmdChar='N',AXMenuItemCmdGlyph='',AXMenuItemCmdModifiers={'cmd'}}
  }}}}
end}
local view={}
for _,name in ipairs({'windowTitle','windowStyle','allowGestures','allowNewWindows','level','frame'}) do
  view[name]=function(self) return self end
end
view.html=function(self,value) content=value; return self end
view.show=function(self) visible=true; return self end
view.hide=function(self) visible=false; return self end
view.hswindow=function() return {isVisible=function() return visible end} end
hs={application={menuGlyphs={},frontmostApplication=function() return app end},
  hotkey={new=function(mods,key,callback)
    assert(#mods==0 and key=='escape')
    escape={enabled=false,callback=callback,enable=function(self) self.enabled=true end,disable=function(self) self.enabled=false end}
    return escape
  end},
  webview={new=function() return view end},
  drawing={windowLevels={tornOffMenu=1}},
  screen={mainScreen=function() return {fullFrame=function() return {x=0,y=0,w=1200,h=800} end} end},
  fnutils={partial=function(fn,self) return function() fn(self) end end},
  spoons={bindHotkeysToSpec=function(actions,map)
    assert(type(actions.toggle)=='function' and map.toggle[2]=='K')
  end}}
local spoon=dofile(assert(arg[1]))
spoon:init()
assert(not escape.enabled,'Escape must remain native while sheet is closed')
spoon:show()
assert(visible and escape.enabled,'opening enables Escape')
escape.callback()
assert(not visible and not escape.enabled,'Escape closes the sheet and releases its binding')
spoon:toggle(); assert(visible)
spoon:toggle(); assert(not visible and not escape.enabled)
spoon:bindHotkeys({toggle={{'ctrl','alt','cmd'},'K'}})
assert(content:find('Fixture &lt;App&gt;',1,true),'application titles must display as text')
assert(content:find('File &amp; Tools',1,true),'menu headings must display as text')
assert(content:find('&lt;img',1,true) and not content:find('<img',1,true),'menu items must not inject external requests')
assert(not content:find('<script',1,true),'layout must work without remote scripts')
print('PASS KSheet toggle, Escape lifecycle, text escaping and offline rendering')
