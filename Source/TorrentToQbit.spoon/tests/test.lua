local source=assert(arg[1])
local f=io.open(source)
local spoon=f and dofile(source) or {}; if f then f:close() end
assert(type(spoon._torrent)=='function','torrent validation not implemented')
local info='d6:lengthi0e4:name7:fixture12:piece lengthi16384e6:pieces0:e'
local torrent='d4:info'..info..'e'
hs={hash={SHA1=function(s) assert(s==info); return 'fixturehash' end}}
local parsed=assert(spoon._torrent(torrent))
assert(parsed.hash=='fixturehash' and parsed.name=='fixture')
for _,bad in ipairs({'<html>bad download</html>',torrent:sub(1,-2),torrent..'junk','d4:infoi1ee','d4:infod4:name3:fooe4:infod4:name3:baree'}) do
  assert(spoon._torrent(bad)==nil,'invalid or incomplete metadata must not upload')
end
assert(spoon._cookie({['Set-Cookie']='QBT_SID_8080=example; Path=/; HttpOnly; SameSite=Strict'})=='QBT_SID_8080=example')
assert(spoon._cookie({['set-cookie']='SID=legacy; path=/'})=='SID=legacy')
assert(spoon._cookie({['Set-Cookie']='unrelated=value'})==nil)
local body,kind=spoon._multipart(torrent,'Books\r\nTest','boundary123',true)
assert(body:find(torrent,1,true),'original binary metadata must be preserved')
assert(body:find('name="category"\r\n\r\nBooks\r\nTest',1,true))
assert(body:find('name="stopped"\r\n\r\ntrue',1,true))
assert(body:sub(-17)=='--boundary123--\r\n')
assert(kind=='multipart/form-data; boundary=boundary123')
print('PASS torrent validation, current/legacy sessions and multipart binary upload')

-- Exercise the real watcher/chooser/upload state machine with synthetic filesystem
-- notifications and an API boundary. No browser or real torrent client is used.
local time,entries,notices,requests=0,{}, {},{}
local timers,chooser,state,uploaded={},nil,{},false
local apiMode,addCalls='normal',0
local filename=os.tmpname()..'.torrent'
local function write(data)
  local handle=assert(io.open(filename,'wb')); handle:write(data); handle:close()
  entries[filename]={mode='file',size=#data,modification=time,change=time,ino=1}
end
local function timer(fn)
  local t={fn=fn,stop=function(self) self.stopped=true end,start=function(self) return self end}
  timers[#timers+1]=t; return t
end
hs={
  configdir='/private-test-config',
  hash={SHA1=function() return 'fixturehash' end,SHA256=function(data) return 'digest'..#data end},
  timer={absoluteTime=function() return time*1e9 end,doAfter=function(_,fn) return timer(fn) end,doEvery=function(_,fn) return timer(fn) end},
  fs={attributes=function(_,key) if key=='mode' then return 'directory' end end,
      symlinkAttributes=function(file) return entries[file] end,
      dir=function() local names={}; for file in pairs(entries) do names[#names+1]=file:match('[^/]+$') end; local i=0; return function() i=i+1; return names[i] end end},
  json={read=function() return {baseURL='https://example.test',username='test',password='fixture',watchDirectory=filename:match('^(.*)/')} end,
        decode=function(body) if body=='categories' then return {Books={name='Books',savePath='/books'}} elseif body=='empty' then return {} elseif body=='present' then return {{hash='fixturehash',category='Books'}} end end},
  settings={get=function(k) return state[k] end,set=function(k,v) state[k]=v end},
  pathwatcher={new=function(_,fn) return timer(fn) end},
  host={uuid=function() return 'fixture-boundary' end},
  notify={new=function(message) notices[#notices+1]=message.informativeText; return {send=function() end} end},
  chooser={new=function(callback)
    chooser={callback=callback}
    for _,method in ipairs({'choices','rows','searchSubText','placeholderText','show','hide','delete'}) do
      chooser[method]=function(self,value) self[method..'Value']=value or true; return self end
    end
    return chooser
  end},
  http={doAsyncRequest=function(url,method,body,headers,callback,redirect)
    assert(redirect==false,'credentials must not follow redirects')
    requests[#requests+1]={url=url,method=method,body=body,headers=headers}
    if url:match('/auth/login$') then
      if apiMode=='login_rejected' then callback(401,'',{}) else callback(204,'',{['Set-Cookie']='QBT_SID_8080=fixture; path=/'}) end
    elseif url:match('/categories$') then callback(200,apiMode=='category_deleted' and 'empty' or 'categories',{})
    elseif url:find('/torrents/info?',1,true) then callback(200,uploaded and 'present' or 'empty',{})
    elseif url:match('/torrents/add$') then
      addCalls=addCalls+1
      assert(headers.Cookie=='QBT_SID_8080=fixture','current API session cookie required')
      assert(body:find(torrent,1,true) and body:find('name="category"\r\n\r\nBooks',1,true))
      if apiMode=='upload_timeout' then callback(-1,'',{}) else uploaded=true; callback(204,'',{}) end
    else error('Unexpected request') end
  end},
}
local client=dofile(source)
write(torrent)
client:start()
assert(#requests==0,'startup must ignore the existing backlog')
entries[filename]=nil; client:_scan()
write(torrent:sub(1,-2)); client:_scan()
time=2; client:_scan()
assert(#requests==0,'partial metadata must not prompt or upload')
write(torrent); client:_scan()
time=4; client:_scan()
assert(chooser and not uploaded,'completed download should prompt before uploading')
chooser.callback(nil)
assert(not uploaded,'Escape must cancel without an upload')
local canceled=chooser
client:addFile(filename)
assert(chooser~=canceled,'manual retry should show a fresh chooser')
chooser.callback({category='Books'})
assert(uploaded and client.lastResult=='added','selected category must upload and confirm the item')
local count=#requests
client:addFile(filename)
assert(#requests==count,'a successful torrent must not be uploaded twice')
client:stop()
assert(chooser.deleteValue,'stopping must dispose the chooser')
state={}; uploaded=false
client:start(); client:addFile(filename)
local late=chooser
client:stop()
count=#requests
late.callback({category='Books'})
assert(#requests==count,'a late chooser callback after stop must not upload')
entries[filename].mode='link'
client:start()
assert(not client:addFile(filename),'symlinked files must not upload')
client:stop()
entries[filename].mode='file'; state={}; uploaded=false
apiMode='login_rejected'
client:start(); count=#requests
client:addFile(filename); client:addFile(filename)
assert(#requests==count+1,'rejected credentials must not cause repeated login attempts')
client:stop()
apiMode='normal'; client:start(); client:addFile(filename)
apiMode='category_deleted'; count=addCalls
chooser.callback({category='Books'})
assert(addCalls==count,'a removed category must not create a new category or upload')
client:stop()
apiMode='normal'; client:start(); client:addFile(filename)
apiMode='upload_timeout'; count=addCalls
chooser.callback({category='Books'})
timers[#timers].fn(); timers[#timers].fn()
assert(addCalls==count+1 and not client._active,'uncertain uploads must be checked without being resent')
client:stop()
os.remove(filename)
print('PASS baseline, completion, category selection, cancellation, deduplication and stop guards')
print('PASS rejected-login lockout, removed categories and uncertain-upload protection')
