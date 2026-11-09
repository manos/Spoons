-- Run with: lua tests/test.lua init.lua
local source = assert(arg[1], "Pass the Spoon's init.lua path")
local failures, total = 0, 0
local clock, opened, scripts, alerts, pending, settings, hit, tap, launchTime, axDelay
local app = { pid = function() return 42 end,
  bundleID = function() return "com.apple.Safari" end }
local types = { leftMouseDown = 1, leftMouseUp = 2, leftMouseDragged = 3, keyDown = 4 }

local function element(role, url, parent, pid)
  return {
    setTimeout = function(self) return self end,
    attributeValue = function(_, key)
      clock = clock + (axDelay or 0)
      return ({ AXRole = role, AXURL = url, AXParent = parent })[key]
    end,
    pid = function() return pid or 10 end,
  }
end

local function event(kind, flags, x, y)
  return { getType = function() return types[kind] end,
    getFlags = function() return flags or {} end,
    location = function() return { x = x or 100, y = y or 100 } end }
end

local function fresh()
  clock, opened, scripts, alerts, pending, settings, hit = 100, {}, {}, {}, {}, {}, nil
  launchTime, axDelay = "test-start", 0
  hs = {
    settings = { get = function(k) return settings[k] end,
      set = function(k, v) settings[k] = v end,
      clear = function(k) settings[k] = nil end },
    application = { get = function() return app end,
      frontmostApplication = function() return app end },
    timer = { absoluteTime = function() return clock * 1e9 end,
      doAfter = function(_, fn) table.insert(pending, fn) end },
    alert = { show = function(message) table.insert(alerts, message) end },
    osascript = { applescript = function(script)
      table.insert(scripts, script)
      if script:find("return id of front window", 1, true) then return true, 900 end
      return true, true
    end },
    urlevent = { httpCallback = nil,
      openURLWithBundle = function(url, bundle)
        table.insert(opened, { url = url, bundle = bundle }); return true
      end,
      getDefaultHandler = function() return "com.apple.Safari" end,
      setDefaultHandler = function() end },
    axuielement = { systemElementAtPosition = function() return hit end },
    execute = function(command)
      return command:find("kern.bootsessionuuid", 1, true) and "test-boot\n" or launchTime .. "\n", true
    end,
    eventtap = { event = { types = types }, new = function(_, fn)
      tap = fn
      return { start = function(self) return self end,
        stop = function(self) return self end }
    end },
    menubar = { new = function() return nil end },
    processInfo = { bundleID = "org.hammerspoon.Hammerspoon" },
  }
  hs.axuielement.applicationElement = function()
    return { setTimeout = function(self) return self end,
      elementAtPosition = function() return hit end }
  end
  local spoon = dofile(source)
  spoon.showMenu = false
  spoon:start()
  spoon._target = { windowID = 900, pid = 42, processIdentity = "test-boot:test-start" }
  return spoon
end

local function check(condition, message)
  assert(condition, message)
end

local function test(name, fn)
  total = total + 1
  local ok, err = pcall(fn)
  if ok then print("PASS " .. name)
  else failures = failures + 1; print("FAIL " .. name .. ": " .. tostring(err)) end
end

test("ordinary URLs preserve their exact contents and bypass the default handler", function()
  fresh()
  local url = "https://example.test/a?next=%2Fpersonal&x=1#here"
  hs.urlevent.httpCallback("https", "example.test", {}, url, 10)
  check(#opened == 1 and opened[1].url == url and opened[1].bundle == "com.apple.Safari",
    "ordinary links must be forwarded directly to Safari")
end)

test("a released Shift-click still routes its URL to the personal window", function()
  fresh()
  hit = element("AXStaticText", nil, nil, 10)
  check(not tap(event("leftMouseDown", { shift = true })), "unknown link must reach its app")
  tap(event("leftMouseUp", {}))
  clock = 100.3
  hs.urlevent.httpCallback("https", "example.test", {}, "https://example.test/personal", 10)
  check(#opened == 0 and #scripts == 1, "released modifier must still select personal routing")
end)

test("stale gestures and URLs from a different app use ordinary routing", function()
  fresh()
  hit = element("AXStaticText", nil, nil, 10)
  tap(event("leftMouseDown", { shift = true }))
  clock = 103
  hs.urlevent.httpCallback("https", "example.test", {}, "https://example.test/stale", 10)
  tap(event("leftMouseDown", { shift = true }))
  hs.urlevent.httpCallback("https", "example.test", {}, "https://example.test/other", 20)
  check(#opened == 2 and #scripts == 0, "unrelated URL must not inherit a gesture")
end)

test("a new ordinary click or keystroke cancels the remembered Shift-click", function()
  fresh()
  tap(event("leftMouseDown", { shift = true }))
  tap(event("leftMouseDown", {}))
  hs.urlevent.httpCallback("https", "example.test", {}, "https://example.test/plain", 42)
  tap(event("leftMouseDown", { shift = true }))
  tap(event("keyDown", {}))
  hs.urlevent.httpCallback("https", "example.test", {}, "https://example.test/key", 42)
  check(#opened == 2 and #scripts == 0, "new input must cancel the old gesture")
end)

test("an unrelated app URL cannot consume another app's pending Shift-click", function()
  fresh()
  hit = element("AXStaticText", nil, nil, 10)
  tap(event("leftMouseDown", { shift = true }))
  hs.urlevent.httpCallback("https", "example.test", {}, "https://example.test/unrelated", 20)
  clock = 100.2
  hs.urlevent.httpCallback("https", "example.test", {}, "https://example.test/intended", 10)
  check(#opened == 1 and #scripts == 1, "only the matching app may consume its pending click")
end)

test("Shift-click on a nested link suppresses both mouse events and defers opening", function()
  fresh()
  hit = element("AXImage", nil, element("AXLink", "https://example.test/nested"))
  check(tap(event("leftMouseDown", { shift = true })), "link mouse-down must be consumed")
  check(#scripts == 0, "AppleScript must not block the input callback")
  check(tap(event("leftMouseUp", {})), "link mouse-up must also be consumed")
  check(#pending == 1, "one tab should be scheduled")
  pending[1]()
  check(#scripts == 1 and #opened == 0, "recognized link must open exactly once")
end)

test("Safari's structured Accessibility URL opens the clicked link", function()
  fresh()
  hit = element("AXStaticText", nil, element("AXLink", {
    url = "https://example.test/structured?x=1&y=2#section",
    __luaSkinType = "NSURL",
  }))
  check(tap(event("leftMouseDown", { shift = true })), "structured URL mouse-down must be consumed")
  check(tap(event("leftMouseUp", {})), "structured URL mouse-up must be consumed")
  check(#pending == 1, "structured URL must schedule one background tab")
  pending[1]()
  check(#scripts == 1 and scripts[1]:find("https://example.test/structured?x=1&y=2#section", 1, true),
    "the URL field must reach Safari without changing its query or fragment")
end)

test("structured non-web Accessibility URLs keep their native behavior", function()
  fresh()
  hit = element("AXLink", { url = "mailto:someone@example.test", __luaSkinType = "NSURL" })
  check(not tap(event("leftMouseDown", { shift = true })), "structured mailto URL must remain native")
  hit = element("AXLink", { filePath = "/tmp/example", __luaSkinType = "NSURL" })
  check(not tap(event("leftMouseDown", { shift = true })), "a file path is not a web URL")
end)

test("a page URL is never mistaken for a clicked link", function()
  fresh()
  hit = element("AXStaticText", nil, element("AXWebArea", "https://example.test/page"))
  check(not tap(event("leftMouseDown", { shift = true })), "plain text must retain its click")
  check(not tap(event("leftMouseUp", {})), "plain text mouse-up must pass through")
  check(#pending == 0, "plain text must not open the page")
end)

test("slow accessibility traversal gives the click back before the input deadline", function()
  fresh()
  hit = element("AXStaticText", nil, element("AXStaticText", nil,
    element("AXStaticText", nil, element("AXLink", "https://example.test/too-slow"))))
  axDelay = 0.04
  check(not tap(event("leftMouseDown", { shift = true })), "slow app must keep native handling")
  check(clock - 100 < 0.2, "accessibility traversal must have a total time budget")
end)

test("other modifier combinations and non-web links retain native behavior", function()
  fresh()
  hit = element("AXLink", "https://example.test/")
  check(not tap(event("leftMouseDown", { shift = true, cmd = true })), "Cmd-Shift-click is native")
  hit = element("AXLink", "mailto:someone@example.test")
  check(not tap(event("leftMouseDown", { shift = true })), "mailto must remain native")
end)

test("dragging a recognized link cancels the pending tab", function()
  fresh()
  hit = element("AXLink", "https://example.test/drag")
  tap(event("leftMouseDown", { shift = true }))
  check(tap(event("leftMouseDragged", { shift = true }, 160, 100)), "captured drag must be consumed")
  check(tap(event("leftMouseUp", {}, 160, 100)), "captured mouse-up must be consumed")
  check(#pending == 0 and #scripts == 0, "drag must not become a click")
end)

test("a missing or restarted Safari target never falls back to the wrong window", function()
  local spoon = fresh()
  spoon._target = nil
  check(not spoon:openPersonal("https://example.test/missing"), "missing target must fail")
  spoon._target = { windowID = 900, pid = 999 }
  check(not spoon:openPersonal("https://example.test/restarted"), "old process must fail")
  check(#opened == 0 and #scripts == 0 and #alerts == 2, "failed personal links must not open elsewhere")
end)

test("a restarted Safari with a reused PID cannot inherit the personal window", function()
  local spoon = fresh()
  launchTime = "a-later-process"
  check(not spoon:openPersonal("https://example.test/reused-pid"), "reused PID must not validate old selection")
  check(#scripts == 0 and #alerts == 1, "stale identity must not address any Safari window")
end)

test("URLs cannot inject AppleScript and invalid inputs never execute", function()
  local spoon = fresh()
  check(spoon:openPersonal('https://example.test/?q="&slash=\\'), "quoted URL should be supported")
  check(scripts[1]:find('q=\\"&slash=\\\\', 1, true), "URL must be escaped as one AppleScript string")
  check(not spoon:openPersonal("javascript:alert(1)"), "non-web scheme must be rejected")
  check(not spoon:openPersonal("https://example.test/\nactivate"), "control characters must be rejected")
  check(#scripts == 1, "invalid URL must not execute a script")
end)

test("stopping the Spoon restores its predecessor without overwriting a newer router", function()
  local spoon = fresh()
  local newer = function() end
  hs.urlevent.httpCallback = newer
  spoon:stop()
  check(hs.urlevent.httpCallback == newer, "stop must preserve a router installed later")
end)

print(string.format("%d tests, %d failures", total, failures))
os.exit(failures == 0 and 0 or 1)
