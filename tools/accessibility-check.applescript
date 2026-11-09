-- External AX + keyboard regression. Requires Keyboard Navigation enabled and a
-- visible VHS control window with no edits to lose. Brings VHS to the foreground.
-- Run: osascript tools/accessibility-check.applescript
on press(k, mods)
 tell application "System Events" to key code k using mods
 delay 0.3
end press
on expectMenu(labelText, expectedUndo, expectedRedo)
 tell application "System Events" to tell process "VHS"
  click menu bar item "Edit" of menu bar 1
  set u to enabled of menu item "Undo Color Change" of menu 1 of menu bar item "Edit" of menu bar 1
  set r to enabled of menu item "Redo Color Change" of menu 1 of menu bar item "Edit" of menu bar 1
  key code 53
 end tell
 if u is not expectedUndo or r is not expectedRedo then error "FAIL " & labelText & " menu"
 log "PASS " & labelText & ": Undo=" & u & ", Redo=" & r
end expectMenu
on expectFocus(channel, expectedValue)
 tell application "System Events" to tell process "VHS"
  set f to value of attribute "AXFocusedUIElement"
  set roleText to role of f
  set desc to description of f
  set v to value of f
 end tell
 if roleText is not "AXSlider" or desc does not contain channel then error "FAIL focus " & channel
 if (v - expectedValue) > 0.00001 or (expectedValue - v) > 0.00001 then error "FAIL value " & channel & ": " & v
 log "PASS keyboard focus/value: " & channel & " " & v
end expectFocus

set keyboardMode to do shell script "defaults read -g AppleKeyboardUIMode"
if keyboardMode is not "2" and keyboardMode is not "3" then error "Enable macOS Keyboard Navigation (Control-F7) before running this check."

tell application "System Events" to tell process "VHS"
 set frontmost to true
 if exists sheet 1 of window 1 then error "Close the open sheet first."
 if exists static text "Edited" of group 1 of window 1 then error "Use a clean project; this check creates a new project."
end tell
delay 0.5
my press(18, {command down}) -- Show Control
my press(45, {command down}) -- New, known clean baseline
my expectMenu("clean", false, false)
-- Focus only through Tab; never programmatically select a slider.
repeat 12 times
 tell application "System Events" to tell process "VHS"
  set f to value of attribute "AXFocusedUIElement"
  if f is not missing value then
   if role of f is "AXSlider" and description of f contains "red" then exit repeat
  end if
 end tell
 my press(48, {})
end repeat
my expectFocus("red", 0.24)
my press(124, {})
my expectFocus("red", 0.29)
my press(124, {})
my expectFocus("red", 0.34)
my expectMenu("two keyboard edits", true, false)
my press(6, {command down})
my expectFocus("red", 0.29)
my expectMenu("one undo", true, true)
my press(6, {command down})
my expectFocus("red", 0.24)
my expectMenu("all undone", false, true)
my press(6, {command down, shift down})
my press(6, {command down, shift down})
my expectFocus("red", 0.34)
my expectMenu("all redone", true, false)
my press(48, {})
my expectFocus("green", 0.08)
my press(124, {})
my expectFocus("green", 0.13)
my press(6, {command down})
my expectFocus("green", 0.08)
my press(6, {command down, shift down})
my expectFocus("green", 0.13)
my press(48, {})
my expectFocus("blue", 0.62)
my press(124, {})
my expectFocus("blue", 0.67)
my press(6, {command down})
my expectFocus("blue", 0.62)
my press(6, {command down, shift down})
my expectFocus("blue", 0.67)
my press(48, {shift down})
my expectFocus("green", 0.13)
my press(48, {shift down})
my expectFocus("red", 0.34)
repeat 4 times
 my press(6, {command down})
end repeat
my expectFocus("red", 0.24)
my expectMenu("restored baseline", false, true)
log "PASS all RGB sliders: Tab/Shift-Tab, arrow adjustment, discrete key undo and redo"
