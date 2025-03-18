local function debug(...)
  local function toReadableString(val)
    if type(val) == "table" then
      local str = "{ "
      for k, v in pairs(val) do
        str = str .. "[" .. tostring(k) .. "] = " .. toReadableString(v) .. ", "
      end
      return str .. "}"
    elseif type(val) == "Url" then
      return "Url:" .. tostring(val)
    else
      return tostring(val)
    end
  end
  local args = { ... }
  local processed_args = {}
  for _, arg in pairs(args) do
    table.insert(processed_args, toReadableString(arg))
  end
  ya.dbg("BUNNY.YAZI", table.unpack(processed_args))
end
local function fail(s, ...) ya.notify { title = "bunny.yazi", content = string.format(s, ...), timeout = 4, level = "error" } end
local function info(s, ...) ya.notify { title = "bunny.yazi", content = string.format(s, ...), timeout = 2, level = "info" } end

local get_state = ya.sync(function(state, attr)
  return state[attr]
end)

local set_state = ya.sync(function(state, attr, value)
  state[attr] = value
end)

local get_cwd = ya.sync(function(state)
  return tostring(cx.active.current.cwd) -- Url objects are evil >.<"
end)

local get_current_tab_idx = ya.sync(function(state)
  return cx.tabs.idx
end)

local get_tabs_as_paths = ya.sync(function(state)
  local tabs = cx.tabs
  local active_tab_idx = tabs.idx
  local result = {}
  for idx = 1, #tabs, 1 do
    if idx ~= active_tab_idx and tabs[idx] then
      result[idx] = tostring(tabs[idx].current.cwd)
    end
  end
  return result
end)

local function filename(pathstr)
  if pathstr == "/" then return pathstr end
  local url_name = Url(pathstr):name()
  if url_name then
    return tostring(url_name)
  else
    return pathstr
  end
end

local function hop_desc(hop)
  return hop.desc or hop.tag or filename(hop.path)
end

local create_special_hops = function()
  local hops = {}
  table.insert(hops, { key = "<Space>", desc = "Create mark", path = "__MARK__" })
  table.insert(hops, { key = "<Enter>", desc = "Fuzzy search", path = "__FUZZY__" })
  local tabhist = get_state("tabhist")
  local tab = get_current_tab_idx()
  if tabhist[tab] and tabhist[tab][2] then
    local previous_dir = tabhist[tab][2]
    table.insert(hops, { key = "<Backspace>", path = previous_dir })
  end
  for idx, tab_path in pairs(get_tabs_as_paths()) do
    table.insert(hops, { key = tostring(idx), path = tab_path })
  end
  return hops
end

local function validate_options(options)
  local function validate_key(key)
    local kt = type(key)
    if not key then
      return false, "key is missing"
    elseif kt == "string" then
      if string.len(key) ~= 1 or string.upper(key) == key then
        return false, "key must be lowercase letter"
      end
    elseif kt == "table" then
      if #key == 0 then
        return false, "key cannot be empty table"
      end
      for _, char in pairs(key) do
        if type(char) ~= "string" or string.len(char) ~= 1 or string.upper(char) == char then
          return false, "key list must contain lowercase letters"
        end
      end
    else
      return false, "key must be string or table"
    end
    return true, ""
  end
  if type(options) ~= "table" then
    return "Invalid config"
  end
  local hops, fuzzy_cmd, notify, marks = options.hops, options.fuzzy_cmd, options.notify, options.marks
  -- Validate hops
  if type(hops) == "table" then
    local used_keys = {}
    for idx, hop in pairs(hops) do
      hop.desc = hop.desc or hop.tag or nil -- used to be tag, allow for backwards compat
      local key_is_valid, key_err = validate_key(hop.key)
      local err = 'Invalid "hops" config value: #' .. idx .. " "
      if not key_is_valid then
        return err .. key_err
      elseif not hop.path then
        return err .. 'path is missing'
      elseif type(hop.path) ~= "string" or string.len(hop.path) == 0 then
        return err .. 'path must be non-empty string'
      elseif hop.desc and (type(hop.desc) ~= "string" or string.len(hop.path) == 0) then
        return err .. 'desc must be non-empty string'
      end
      -- Check for duplicate keys
      if used_keys[hop.key] then
        return err .. 'needs unique key'
      end
      -- Insert hop keys as table keys to easily check for set membership
      used_keys[hop.key] = true
    end
  else
    return 'Invalid "hops" config value'
  end
  -- Validate other options
  if fuzzy_cmd ~= nil and type(fuzzy_cmd) ~= "string" then
    return 'Invalid "fuzzy_cmd" config value'
  elseif notify ~= nil and type(notify) ~= "boolean" then
    return 'Invalid "notify" config value'
  elseif marks ~= nil and type(marks) ~= "boolean" then
    return 'Invalid "marks" config value'
  end
end

-- https://github.com/sxyazi/yazi/blob/main/yazi-plugin/preset/plugins/fzf.lua
-- https://github.com/sxyazi/yazi/blob/main/yazi-plugin/src/process/child.rs
local select_fuzzy = function(hops, fuzzy_cmd)
  local permit = ya.hide()
  local child, spawn_err =
      Command(fuzzy_cmd):stdin(Command.PIPED):stdout(Command.PIPED):stderr(Command.INHERIT):spawn()
  if not child then
    fail("Command `%s` failed with code %s. Do you have it installed?", fuzzy_cmd, spawn_err.code)
    return
  end
  -- Build fzf input string
  local input_lines = {};
  for _, hop in pairs(hops) do
    table.insert(input_lines, hop_desc(hop) .. "\t" .. hop.path)
  end
  child:write_all(table.concat(input_lines, "\n"))
  child:flush()
  local output, output_err = child:wait_with_output()
  permit:drop()
  if not output.status.success then
    if output.status.code ~= 130 then -- user pressed escape to quit
      fail("Command `%s` failed with code %s", fuzzy_cmd, output_err.code)
    end
    return
  end
  -- Parse fzf output
  local desc, path = string.match(output.stdout, "(.-)\t(.-)\n")
  if not desc or not path or path == "" then
    fail("Failed to parse fuzzy searcher result")
    return
  end
  return { desc = desc, path = path }
end

local hop = function(hops, fuzzy_cmd, notify)
  local cands = {}
  for _, hop in pairs(create_special_hops()) do
    table.insert(cands, { desc = hop_desc(hop), on = hop.key, path = hop.path })
  end
  for _, hop in pairs(hops) do
    table.insert(cands, { desc = hop_desc(hop), on = hop.key, path = hop.path })
  end
  local hops_idx = ya.which { cands = cands }
  if not hops_idx then return end
  local selected_hop = cands[hops_idx]
  -- Handle special hops
  if selected_hop.path == "__MARK__" then
    local valid_chars = {
      'a', 'b', 'c', 'd', 'e', 'f', 'g', 'h', 'i', 'j', 'k', 'l', 'm',
      'n', 'o', 'p', 'q', 'r', 's', 't', 'u', 'v', 'w', 'x', 'y', 'z',
      'A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'I', 'J', 'K', 'L', 'M',
      'N', 'O', 'P', 'Q', 'R', 'S', 'T', 'U', 'V', 'W', 'X', 'Y', 'Z'
    }
    local mark_cands = {};
    for _, char in pairs(valid_chars) do
      table.insert(mark_cands, { on = char })
    end
    info("Press a letter to create mark")
    local char_idx = ya.which { cands = mark_cands, silent = true }
    if char_idx ~= nil then
      local selected_char = string.upper(mark_cands[char_idx].on)
      debug(type(get_cwd()), get_cwd())
      table.insert(hops, { key = selected_char, path = get_cwd() })
      set_state("hops", hops)
    end
    return
  elseif selected_hop.path == "__FUZZY__" then
    local fuzzy_hop = select_fuzzy(hops, fuzzy_cmd)
    if not fuzzy_hop then return end
    selected_hop = fuzzy_hop
  end
  ya.mgr_emit("cd", { selected_hop.path })
  -- TODO: Better way to verify hop was successful?
  if notify then
    local desc = selected_hop.desc
    if desc then
      info('Hopped to ' .. desc)
    end
  end
end

local function init()
  local options = get_state("options")
  local err = validate_options(options)
  if err then
    set_state("init_error", err)
    fail(err)
    return
  end
  set_state("fuzzy_cmd", options.fuzzy_cmd or "fzf")
  set_state("notify", options.notify or false)
  local hops = options.hops
  table.sort(hops, function(x, y)
    local x_compare, y_compare = x.key, y.key
    if type(x.key) == "table" then
      x_compare = x.key[1]
    end
    if type(y.key) == "table" then
      y_compare = y.key[1]
    end
    return x_compare > y_compare
  end)
  set_state("hops", hops)
  set_state("init", true)
end

return {
  setup = function(state, options)
    state.options = options
    ps.sub("cd", function(body)
      -- Note: This callback is sync and triggered at startup!
      local tab = body.tab -- type number
      -- Very important to turn this into a string because Url has ownership issues
      -- when passed to standard utility functions >.<'
      -- https://github.com/sxyazi/yazi/issues/2159
      local cwd = tostring(cx.active.current.cwd)
      -- Upon startup this will be nil so initialize if necessary
      local tabhist = state.tabhist or {}
      -- tabhist structure:{ <tab_index> = { <current_dir>, <previous_dir?> }, ... }
      if not tabhist[tab] then
        -- If fresh tab, initialize tab history table
        tabhist[tab] = { cwd }
      else
        -- Otherwise, shift history table to the right and add cwd to the front
        tabhist[tab] = { cwd, tabhist[tab][1] }
      end
      state.tabhist = tabhist
    end)
  end,
  entry = function()
    if not get_state("init") then
      init()
    end
    local init_error = get_state("init_error")
    if init_error then
      fail(init_error)
      return
    end
    local hops, fuzzy_cmd, notify = get_state("hops"), get_state("fuzzy_cmd"), get_state("notify")
    hop(hops, fuzzy_cmd, notify)
  end,
}
