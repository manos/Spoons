--- === TorrentToQbit ===
--- Choose a qBittorrent category when a new .torrent finishes downloading.
local obj = {name='TorrentToQbit', version='0.1.0', settleSeconds=1, maxBytes=16*1024*1024}
local function now() return hs.timer.absoluteTime()/1e9 end
local function trim(s) return (s or ''):match('^%s*(.-)%s*$') end
local function encode(s) return (s:gsub('[^%w%-_%.~]',function(c) return string.format('%%%02X',c:byte()) end)) end
local function decode(s)
  local ok,value=pcall(hs.json.decode,s or '')
  if ok and type(value)=='table' then return value end
end

-- Hash the original encoded info dictionary, never a re-encoding. Also reject
-- partial downloads/HTML before showing a chooser or sending data to the server.
function obj._torrent(data)
  if type(data)~='string' or data:sub(1,1)~='d' then return nil end
  local at,nodes,infoBytes=1,0,nil
  local function stringValue()
    local digits,finish=data:match('^(%d+)():',at)
    assert(digits and #digits<=9 and (digits=='0' or digits:sub(1,1)~='0'))
    local length=tonumber(digits); at=finish+1
    assert(at+length-1<=#data)
    local value=data:sub(at,at+length-1); at=at+length
    return value
  end
  local parse
  parse=function(depth)
    nodes=nodes+1; assert(depth<=64 and nodes<=100000)
    local kind=data:sub(at,at)
    if kind:match('%d') then return stringValue() end
    if kind=='i' then
      local value,finish=data:match('^i(-?%d+)()e',at)
      assert(value and #value<20 and value~='-0' and not value:match('^%-?0%d'))
      at=finish+1; return assert(tonumber(value))
    end
    assert(kind=='d' or kind=='l'); at=at+1
    local values={}
    while data:sub(at,at)~='e' do
      assert(at<=#data)
      local key=kind=='d' and stringValue() or #values+1
      assert(values[key]==nil)
      local start=at
      values[key]=parse(depth+1)
      if depth==0 and key=='info' then
        assert(data:sub(start,start)=='d'); infoBytes=data:sub(start,at-1)
      end
    end
    at=at+1; return values
  end
  local ok,root=pcall(parse,0)
  if not ok or at~=#data+1 or not infoBytes or type(root.info)~='table' then return nil end
  local info=root.info
  if type(info.name)~='string' or #info.name==0 then return nil end
  local hash
  if type(info.pieces)=='string' and #info.pieces%20==0 and type(info['piece length'])=='number'
      and info['piece length']>0 and (type(info.length)=='number' or type(info.files)=='table') then
    hash=hs.hash.SHA1(infoBytes)
  elseif info['meta version']==2 and type(info['file tree'])=='table' then
    hash=hs.hash.SHA256(infoBytes):sub(1,40)
  end
  if hash then return {hash=hash,name=info.name} end
end

function obj._cookie(headers)
  for key,value in pairs(headers or {}) do
    if key:lower()=='set-cookie' and type(value)=='string' then
      for name,token in value:gmatch('([%w_-]+)=([^;,%s]+)') do
        if name=='SID' or name:match('^QBT_SID_%d+$') then return name..'='..token end
      end
    end
  end
end

function obj._multipart(data,category,boundary,stopped)
  assert(not data:find(boundary,1,true) and not category:find(boundary,1,true))
  local parts={}
  local function field(name,value)
    parts[#parts+1]='--'..boundary..'\r\nContent-Disposition: form-data; name="'..name..'"\r\n\r\n'..value..'\r\n'
  end
  field('category',category)
  if stopped~=nil then field('stopped',stopped and 'true' or 'false') end
  parts[#parts+1]='--'..boundary..'\r\nContent-Disposition: form-data; name="torrents"; filename="download.torrent"\r\nContent-Type: application/x-bittorrent\r\n\r\n'..data..'\r\n'
  parts[#parts+1]='--'..boundary..'--\r\n'
  return table.concat(parts),'multipart/form-data; boundary='..boundary
end

function obj:_notice(message)
  hs.notify.new({title='Torrent to qBittorrent',informativeText=message}):send()
end

function obj:_request(method,route,body,contentType,callback)
  local epoch=self._epoch
  local headers={Origin=self._origin,Referer=self._config.baseURL..'/'}
  if self._cookieValue then headers.Cookie=self._cookieValue end
  if contentType then headers['Content-Type']=contentType end
  local completed=false
  local timer
  local function finish(code,result,responseHeaders)
    if completed then return end
    completed=true
    if timer then timer:stop(); self._timers[timer]=nil end
    if self._running and self._epoch==epoch then callback(code,result,responseHeaders or {}) end
  end
  timer=hs.timer.doAfter(15,function() finish(-1,'') end)
  self._timers[timer]=true
  -- Do not follow redirects with credentials, session cookies, or torrent data.
  hs.http.doAsyncRequest(self._config.baseURL..'/api/v2/'..route,method,body,headers,finish,false)
end

function obj:_login(callback)
  local c=self._config
  if not c.username then self._authenticated=true; callback(true); return end
  if self._authBlocked then callback(false,'Login failed. Check the private config before reloading Hammerspoon.'); return end
  self:_request('POST','auth/login','username='..encode(c.username)..'&password='..encode(c.password),
    'application/x-www-form-urlencoded',function(code,body,headers)
      -- qBittorrent 5.2 uses HTTP 204 and QBT_SID_<port>; older versions use Ok./SID.
      if code>=200 and code<300 and (code==204 or trim(body)=='Ok.') then
        self._cookieValue=self._cookie(headers); self._authenticated=true
        callback(true)
      else
        self._authBlocked=code==401 or code==403 or trim(body)=='Fails.'
        callback(false,'Could not log in to qBittorrent. Check the private config and server login status.')
      end
    end)
end

function obj:_get(route,callback,retried)
  if not self._authenticated then
    self:_login(function(ok,why)
      if ok then self:_get(route,callback,retried) else callback(nil,why) end
    end)
    return
  end
  self:_request('GET',route,nil,nil,function(code,body)
    if (code==401 or code==403) and not retried and self._config.username then
      self._authenticated=false; self._cookieValue=nil
      self:_get(route,callback,true)
      return
    end
    local result=code==200 and decode(body)
    if result then callback(result) else callback(nil,'Could not read qBittorrent. The torrent file is still in Downloads.') end
  end)
end

function obj:_read(file)
  local a=hs.fs.symlinkAttributes(file)
  if not a or a.mode~='file' or a.size==0 or a.size>self.maxBytes then return nil end
  local handle=io.open(file,'rb'); if not handle then return nil end
  local data=handle:read(self.maxBytes+1); handle:close()
  local after=hs.fs.symlinkAttributes(file)
  if not after or after.mode~='file' or #data~=a.size or after.size~=a.size or after.modification~=a.modification then return nil end
  local torrent=self._torrent(data)
  if torrent then torrent.data=data; torrent.digest=hs.hash.SHA256(data); return torrent end
end

function obj:_remember(hash)
  self._sent[hash]=os.time()
  local entries={}
  for key,time in pairs(self._sent) do entries[#entries+1]={hash=key,time=time} end
  table.sort(entries,function(a,b) return a.time>b.time end)
  for index=2001,#entries do self._sent[entries[index].hash]=nil end
  hs.settings.set(self._settingsKey,self._sent)
end

function obj:_finish(message,success)
  if not self._active then return end
  local item=self._active
  if success then self:_remember(item.hash) end
  self._queued[item.hash]=nil; self._active=nil
  if self._chooser then
    local chooser=self._chooser; self._chooser=nil
    chooser:hide(); chooser:delete()
  end
  self.lastResult=success and 'added' or 'skipped_or_failed'
  if message then self:_notice(message) end
  self:_pump()
end

function obj:_verify(item,category,attempt)
  self.lastResult='verifying_upload'
  self:_get('torrents/info?hashes='..encode(item.hash),function(rows)
    if self._active~=item then return end
    if rows and #rows>0 then
      if rows[1].category==category then self:_finish('Added to '..(category~='' and category or 'Uncategorized')..'.',true)
      else self:_finish('The torrent is in qBittorrent, but its category differs. Check it in the Web UI.',true) end
    elseif attempt<3 then
      local epoch=self._epoch
      local timer
      timer=hs.timer.doAfter(1,function()
        self._timers[timer]=nil
        if self._running and self._epoch==epoch then self:_verify(item,category,attempt+1) end
      end)
      self._timers[timer]=true
    else self:_finish('Could not confirm the upload. Check qBittorrent before trying again; no automatic resend was made.') end
  end)
end

function obj:_submit(item,category)
  local fresh=self:_read(item.file)
  if not fresh or fresh.digest~=item.digest then self:_finish('The torrent file changed or disappeared. Download it again to retry.'); return end
  self:_get('torrents/info?hashes='..encode(item.hash),function(rows,why)
    if not rows then self:_finish(why); return end
    if #rows>0 then self:_finish('Already in qBittorrent; no duplicate was added.',true); return end
    self:_get('torrents/categories',function(categories,errorMessage)
      if not categories then self:_finish(errorMessage); return end
      if category~='' and not categories[category] then self:_finish('That category no longer exists. Download the torrent again to choose another.'); return end
      local boundary='Hammerspoon'..hs.host.uuid():gsub('-','')
      local body,contentType=self._multipart(fresh.data,category,boundary,self._config.addStopped)
      self.lastResult='uploading'
      self:_request('POST','torrents/add',body,contentType,function(code)
        if code>=200 and code<300 or code==-1 then self:_verify(item,category,1)
        else self:_finish('qBittorrent rejected the upload (HTTP '..code..'). The file was kept.') end
      end)
    end)
  end)
end

function obj:_pump()
  if not self._running or self._active or #self._queue==0 then return end
  local item=table.remove(self._queue,1); self._active=item
  self.lastResult='reading_categories'
  self:_get('torrents/categories',function(categories,why)
    if not categories then self:_finish(why); return end
    local choices={{text='Uncategorized',category=''}}
    for name in pairs(categories) do
      if type(name)=='string' then choices[#choices+1]={text=name,category=name} end
    end
    table.sort(choices,function(a,b) return a.text:lower()<b.text:lower() end)
    local epoch=self._epoch
    self.lastResult='choosing_category'
    self._chooser=hs.chooser.new(function(choice)
      if self._epoch~=epoch or self._active~=item then return end
      if choice then self:_submit(item,choice.category) else self:_finish() end
    end)
    self._chooser:choices(choices):rows(math.min(10,#choices)):searchSubText(false)
      :placeholderText('Category for '..item.file:match('[^/]+$'):gsub('%c',' ')):show()
  end)
end

function obj:addFile(file)
  if not self._running then return false end
  local torrent=self:_read(file)
  if not torrent then return false end
  if self._sent[torrent.hash] or self._queued[torrent.hash] then return true end
  if #self._queue>=50 then self:_notice('Too many queued torrents. Remaining files were kept.'); return true end
  local item={file=file,hash=torrent.hash,digest=torrent.digest}
  self._queued[item.hash]=true; self._queue[#self._queue+1]=item
  self:_pump(); return true
end

local function signature(a)
  return table.concat({a.size,a.modification,a.change or 0,a.ino or 0},':')
end

function obj:_scan(baseline)
  local time=now()
  local present={}
  for name in hs.fs.dir(self._config.watchDirectory) do
    if name:lower():match('%.torrent$') then
      local file=self._config.watchDirectory..'/'..name
      local a=hs.fs.symlinkAttributes(file)
      if a and a.mode=='file' then
        present[file]=true
        local stamp=signature(a)
        if baseline then self._observed[file]=stamp
        elseif self._observed[file]~=stamp then
          self._observed[file]=stamp; self._pending[file]={since=time,started=time}
        elseif self._pending[file] and time-self._pending[file].since>=self.settleSeconds then
          if self:addFile(file) then self._pending[file]=nil
          elseif time-self._pending[file].started>=10 then
            self._pending[file]=nil; self:_notice('A .torrent file could not be read as complete torrent metadata. It was kept.')
          end
        end
      end
    end
  end
  for file in pairs(self._observed) do
    if not present[file] then self._observed[file]=nil; self._pending[file]=nil end
  end
end

function obj:start(configFile)
  if self._running then return self end
  local c=hs.json.read(configFile or self.configFile or hs.configdir..'/torrent-to-qbit.json')
  assert(type(c)=='table','TorrentToQbit: local JSON configuration is missing or invalid')
  assert(type(c.baseURL)=='string' and c.baseURL:match('^https://[^/@?#%s]+/?$'),'TorrentToQbit: baseURL must be an HTTPS origin')
  c.baseURL=c.baseURL:gsub('/$','')
  c.watchDirectory=(c.watchDirectory or os.getenv('HOME')..'/Downloads'):gsub('/$','')
  assert(hs.fs.attributes(c.watchDirectory,'mode')=='directory','TorrentToQbit: download directory does not exist')
  assert(not c.username or (type(c.username)=='string' and type(c.password)=='string'),'TorrentToQbit: username requires a password in the private config')
  self._config=c; self._origin=c.baseURL
  self._epoch=(self._epoch or 0)+1; self._running=true
  self._queue,self._queued,self._observed,self._pending,self._timers={},{},{},{},{}
  self._authenticated,self._authBlocked,self._cookieValue=false,false,nil
  self._settingsKey='TorrentToQbit.sent.'..hs.hash.SHA256(c.baseURL)
  self._sent=hs.settings.get(self._settingsKey) or {}
  for hash,time in pairs(self._sent) do
    if type(time)~='number' or os.time()-time>7*86400 then self._sent[hash]=nil end
  end
  self:_scan(true) -- Starting/reloading never imports the existing Downloads backlog.
  self._watcher=hs.pathwatcher.new(c.watchDirectory,function() self._dirty=true end):start()
  self._scanner=hs.timer.doEvery(0.5,function()
    if self._dirty or next(self._pending) then self._dirty=false; self:_scan() end
  end)
  local previous=hs.shutdownCallback
  self._shutdown=function() self:stop(); if previous then previous() end end
  self._previousShutdown=previous; hs.shutdownCallback=self._shutdown
  self.lastResult='watching'
  return self
end

function obj:stop()
  self._running=false; self._epoch=(self._epoch or 0)+1
  if self._watcher then self._watcher:stop(); self._watcher=nil end
  if self._scanner then self._scanner:stop(); self._scanner=nil end
  if self._chooser then self._chooser:hide(); self._chooser:delete(); self._chooser=nil end
  for timer in pairs(self._timers or {}) do timer:stop() end
  self._active,self._config,self._cookieValue=nil,nil,nil
  if hs.shutdownCallback==self._shutdown then hs.shutdownCallback=self._previousShutdown end
  self._shutdown=nil
  return self
end

return obj
