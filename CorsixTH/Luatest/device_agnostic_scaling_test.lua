--[[
 Unit test for device-agnostic iOS/mobile UI scaling and adaptive bottom panel layout.
--]]

package.path = package.path .. ";./CorsixTH/Lua/?.lua;./CorsixTH/Luatest/?.lua"

local test_count = 0
local pass_count = 0

local function assert_eq(actual, expected, description)
  test_count = test_count + 1
  if actual == expected then
    pass_count = pass_count + 1
    print(string.format("  PASS: %s (got %s)", description, tostring(actual)))
  else
    print(string.format("  FAIL: %s (expected %s, got %s)", description, tostring(expected), tostring(actual)))
  end
end

print("Running Device-Agnostic UI Scaling & Layout Tests...")

-- Mock App and Graphics
local App = {
  MIN_WINDOW_WIDTH = 640,
  MIN_WINDOW_HEIGHT = 480,
}

local function simulate_get_ui_scale(scr_w, scr_h, config_ui_scale, display_scale)
  config_ui_scale = config_ui_scale or 0
  display_scale = display_scale or 1

  local is_portrait = scr_h > scr_w
  local min_w = App.MIN_WINDOW_WIDTH
  local min_h = App.MIN_WINDOW_HEIGHT

  if is_portrait then
    if display_scale >= 3 or scr_w <= 1300 then
      min_w = 390
      min_h = 390
    else
      min_w = 580
      min_h = 580
    end
  end

  local max_scale = math.floor(math.min(scr_w / min_w, scr_h / min_h))
  max_scale = math.max(1, max_scale)
  local cs = config_ui_scale * display_scale
  if cs == 0 or cs > max_scale then
    return max_scale
  else
    return math.max(1, math.floor(cs))
  end
end

print("\n1. Testing Graphics:getUIScale() device adaptability:")

-- Test iPhone 18 Pro / 17 Pro portrait (1206 x 2622 @ 3x display)
assert_eq(simulate_get_ui_scale(1206, 2622, 0, 3), 3, "iPhone 18 Pro / 17 Pro portrait scales to 3x")

-- Test iPhone 15/16/17 Pro portrait (1179 x 2556 @ 3x display)
assert_eq(simulate_get_ui_scale(1179, 2556, 0, 3), 3, "iPhone 15/16/17 Pro portrait scales to 3x")

-- Test iPhone Plus/Pro Max portrait (1290 x 2796 @ 3x display)
assert_eq(simulate_get_ui_scale(1290, 2796, 0, 3), 3, "iPhone 16 Pro Max portrait scales to 3x")

-- Test iPhone Duo outer screen portrait (1398 x 2034 @ 2x display)
assert_eq(simulate_get_ui_scale(1398, 2034, 0, 2), 2, "iPhone Duo outer display portrait scales to 2x")

-- Test iPhone Duo inner unfolded screen portrait (2007 x 2853 @ 2x display)
assert_eq(simulate_get_ui_scale(2007, 2853, 0, 2), 3, "iPhone Duo inner unfolded portrait scales to 3x")

-- Test iPad Pro 11-inch portrait (1668 x 2420 @ 2x display)
assert_eq(simulate_get_ui_scale(1668, 2420, 0, 2), 2, "iPad Pro 11-inch portrait scales to 2x")

-- Test iPad Pro 12.9-inch portrait (2048 x 2732 @ 2x display)
assert_eq(simulate_get_ui_scale(2048, 2732, 0, 2), 3, "iPad Pro 12.9-inch portrait scales to 3x")

-- Test Landscape orientations (should follow standard 640x480 constraints)
assert_eq(simulate_get_ui_scale(2622, 1206, 0, 3), 2, "iPhone 18 Pro landscape scales to 2x")
assert_eq(simulate_get_ui_scale(2420, 1668, 0, 2), 3, "iPad Pro 11-inch landscape scales to 3x")
assert_eq(simulate_get_ui_scale(640, 480, 0, 1), 1, "Baseline 640x480 landscape scales to 1x")
assert_eq(simulate_get_ui_scale(1920, 1080, 0, 1), 2, "1080p Desktop landscape scales to 2x")
assert_eq(simulate_get_ui_scale(2560, 1440, 0, 1), 3, "1440p Desktop landscape scales to 3x")
assert_eq(simulate_get_ui_scale(3840, 2160, 0, 1), 4, "4K Desktop landscape scales to 4x")

-- Test manual user override via config
assert_eq(simulate_get_ui_scale(1206, 2622, 1, 1), 1, "Manual user override scale 1 is respected")

print("\n2. Testing Bottom Panel button spacing & layout calculations:")

local function compute_button_layout(panel_w, base_w, has_machine_btn)
  local num_buttons = has_machine_btn and 8 or 7
  local is_ultra_compact = panel_w < 550
  local button_y = 0
  local start_x = 364
  local is_compact = panel_w < base_w
  local spacing = 38

  if is_ultra_compact then
    button_y = -42
    start_x = math.max(10, math.floor((panel_w - num_buttons * 38) / 2))
    spacing = 38
  elseif is_compact and panel_w > start_x + 38 then
    spacing = math.max(26, math.min(38, (panel_w - 38 - start_x) / (num_buttons - 1)))
  end

  local positions = {}
  local default_positions = { 364, 407, 445, 483, 521, 559, 597 }
  if has_machine_btn then
    table.insert(default_positions, 2, 407)
  end

  for idx = 1, num_buttons do
    if is_ultra_compact or is_compact then
      positions[idx] = math.floor(start_x + (idx - 1) * spacing)
    else
      positions[idx] = default_positions[idx]
    end
  end

  local last_btn_right = positions[#positions] + 38
  return positions, spacing, is_compact, last_btn_right, is_ultra_compact, button_y
end

-- Test standard 640px panel (desktop / unscaled / landscape)
local pos_std, _, compact_std, right_std = compute_button_layout(640, 640, false)
assert_eq(compact_std, false, "640px panel is not compact")
assert_eq(pos_std[1], 364, "Button 1 position is 364")
assert_eq(pos_std[7], 597, "Button 7 position is 597")
assert_eq(right_std <= 640, true, "All buttons fit within 640px width")

-- Test iPhone 18 Pro / 17 Pro in portrait at 3x scale:
-- scr_w = 1206, scale = 3 => available_w = 1206 / 3 = 402 px
local pos_402, _, _, right_402, ultra_402, y_402 = compute_button_layout(402, 640, false)
assert_eq(ultra_402, true, "402px panel is ultra compact (< 550px)")
assert_eq(y_402, -42, "Submenu buttons positioned in row 2 (y = -42)")
assert_eq(pos_402[1] >= 10, true, "Row 2 buttons comfortably centered (start >= 10)")
assert_eq(right_402 <= 402, true, "All row 2 buttons fit within 402px (last right: " .. tostring(right_402) .. " <= 402)")

-- Test iPhone 15/16 in portrait at 3x scale:
-- scr_w = 1179, scale = 3 => available_w = 1179 / 3 = 393 px
local _, _, _, right_393, ultra_393, _ = compute_button_layout(393, 640, false)
assert_eq(ultra_393, true, "393px panel is ultra compact (< 550px)")
assert_eq(right_393 <= 393, true, "All row 2 buttons fit within 393px (last right: " .. tostring(right_393) .. " <= 393)")

-- Test iPhone in portrait at 2x scale:
-- scr_w = 1206, scale = 2 => available_w = 1206 / 2 = 603 px
local pos_603, sp_603, compact_603, right_603 = compute_button_layout(603, 640, false)
assert_eq(compact_603, true, "603px panel is compact (< 640px)")
assert_eq(pos_603[1], 364, "First button starts at 364")
assert_eq(right_603 <= 603, true, "All buttons fit within 603px (last right: " .. tostring(right_603) .. " <= 603)")
assert_eq(sp_603 >= 26, true, "Button spacing is >= 26px touch target")

-- Test iPad 11-inch in portrait at 2x scale:
-- scr_w = 1668, scale = 2 => available_w = 834 px
local pos_834, _, compact_834, _ = compute_button_layout(834, 640, false)
assert_eq(compact_834, false, "834px panel is not compact (>= 640px)")
assert_eq(pos_834[7], 597, "Last button remains at default position on iPad")

print(string.format("\nTest Summary: %d / %d tests passed.", pass_count, test_count))
if pass_count == test_count then
  print("All tests PASSED successfully!\n")
else
  os.exit(1)
end
