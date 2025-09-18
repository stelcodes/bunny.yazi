--- @since 25.5.28
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

local some = function(...)
  for _, v in ipairs({ ... }) do
    if v ~= nil then
      return v
    end
  end
end

local function filename(pathstr)
  if pathstr == "/" then return pathstr end
  local url_name = Url(pathstr):name()
  if url_name then
    return tostring(url_name)
  else
    return pathstr
  end
end

local function path_to_desc(path, strategy)
  if strategy == "filename" then
    return filename(path)
  end
  local home = os.getenv("HOME")
  if home and home ~= "" then
    local startPos, endPos = string.find(path, home)
    -- Only substitute if the match is from the start of path, very important
    if startPos == 1 then
      return "~" .. path:sub(endPos + 1)
    end
  end
  return tostring(path)
end

local function sort_hops(hops)
  local function convert_key(key)
    local t = type(key)
    if t == "table" then
      -- If table, sort by first key string
      return key[1]
    elseif t == "string" and string.lower(key) ~= key then
      -- If uppercase letter (signifying an ephemeral hop), prepend "z"
      -- so it gets sorted after lowercase persistent hops
      return "z" .. key
    end
    return key
  end
  table.sort(hops, function(x, y)
    return convert_key(x.key) < convert_key(y.key)
  end)
  return hops
end

local create_special_hops = function(config)
  local hops = {}
  local desc_strategy, tabs, ephemeral = config.desc_strategy, config.tabs, config.ephemeral
  if ephemeral then
    table.insert(hops, { key = "<Enter>", desc = "Create hop", path = "__MARK__" })
  end
  table.insert(hops, { key = "<Space>", desc = "Fuzzy search", path = "__FUZZY__" })
  local tabhist = get_state("tabhist")
  local tab = get_current_tab_idx()
  if tabhist[tab] and tabhist[tab][2] then
    local previous_dir = tabhist[tab][2]
    table.insert(hops, {
      key = "<Backspace>",
      path = previous_dir,
      desc = path_to_desc(previous_dir, desc_strategy)
    })
  end
  if tabs then
    for idx, tab_path in pairs(get_tabs_as_paths()) do
      table.insert(hops, {
        key = tostring(idx),
        path = tab_path,
        desc = path_to_desc(tab_path, desc_strategy)
      })
    end
  end
  return hops
end

local function validate_options(options)
  local function validate_key(key)
    local kt = type(key)
    if not key then
      return false, "key is missing"
    elseif kt == "string" then
      if utf8.len(key) ~= 1 then
        return false, "key must be single character"
      end
    elseif kt == "table" then
      if #key == 0 then
        return false, "key cannot be empty table"
      end
      for _, char in pairs(key) do
        if utf8.len(char) ~= 1 then
          return false, "key list must contain single characters"
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
  local hops, desc_strategy, tabs, ephemeral, fuzzy_cmd, notify =
      options.hops, options.desc_strategy, options.tabs,
      options.ephemeral, options.fuzzy_cmd, options.notify
  -- Validate hops
  if type(hops) == "table" then
    local used_keys = {}
    for idx, hop in pairs(hops) do
      hop.desc = hop.desc or hop.tag or nil -- used to be tag, allow for backwards compat
      local key_is_validated, key_err = validate_key(hop.key)
      local err = 'Invalid "hops" config value: #' .. idx .. " "
      if not key_is_validated then
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
  if desc_strategy ~= nil and desc_strategy ~= "path" and desc_strategy ~= "filename" then
    return 'Invalid "desc_strategy" config value'
  elseif tabs ~= nil and type(notify) ~= "boolean" then
    return 'Invalid "tabs" config value'
  elseif ephemeral ~= nil and type(notify) ~= "boolean" then
    return 'Invalid "ephemeral" config value'
  elseif fuzzy_cmd ~= nil and type(fuzzy_cmd) ~= "string" then
    return 'Invalid "fuzzy_cmd" config value'
  elseif notify ~= nil and type(notify) ~= "boolean" then
    return 'Invalid "notify" config value'
  end
end

-- https://github.com/sxyazi/yazi/blob/main/yazi-plugin/preset/plugins/fzf.lua
-- https://github.com/sxyazi/yazi/blob/main/yazi-plugin/src/process/child.rs
-- Returns nil if fzf command failed or user exited with escape key
local select_fuzzy = function(hops, config)
  local permit = ya.hide()
  local child, spawn_err =
      Command(config.fuzzy_cmd):stdin(Command.PIPED):stdout(Command.PIPED):stderr(Command.INHERIT):spawn()
  if not child then
    fail("Command `%s` failed with code %s. Do you have it installed?", config.fuzzy_cmd, spawn_err.code)
    return
  end
  local fuzzy_entries = {}
  for _, hop in pairs(hops) do
    local existing_desc = fuzzy_entries[hop.path]
    if not existing_desc or existing_desc == "" then
      local fuzzy_desc = hop.desc
      -- Avoid repeating path in description
      if fuzzy_desc == hop.path then
        fuzzy_desc = ""
      end
      fuzzy_entries[hop.path] = fuzzy_desc
    end
  end
  -- Build fzf input string
  local input_lines = {}
  for entry_path, entry_desc in pairs(fuzzy_entries) do
    local line = entry_desc .. string.rep(" ", 23 - #entry_desc) .. "\t" .. entry_path
    table.insert(input_lines, line)
  end
  child:write_all(table.concat(input_lines, "\n"))
  child:flush()
  local output, output_err = child:wait_with_output()
  permit:drop()
  if not output.status.success then
    if output.status.code ~= 130 then -- user pressed escape to quit
      fail("Command `%s` failed with code %s", config.fuzzy_cmd, output_err.code)
    end
    return
  end
  -- Parse fzf output, remove right padded spaces from desc
  local desc, path = string.match(output.stdout, "^(.-) *\t(.-)\n$")
  if not desc or not path or path == "" then
    fail("Failed to parse fuzzy searcher result")
    return
  end
  if desc == "" then
    desc = path_to_desc(path, config.desc_strategy)
  end
  return { desc = desc, path = path }
end

local cd = function(selected_hop, config)
  local _, dir_list_err = fs.read_dir(Url(selected_hop.path), { limit = 1, resolve = true })
  if dir_list_err then
    fail("Invalid directory " .. path_to_desc(selected_hop.path))
    return
  end
  -- Assuming that if I can fs.read_dir, then this will also succeed
  ya.emit("cd", { selected_hop.path })
  if config.notify then
    info('Hopped to ' .. selected_hop.desc)
  end
end

local attempt_hop = function(hops, config)
  local cands = {}
  for _, hop in pairs(create_special_hops(config)) do
    table.insert(cands, { desc = hop.desc, on = hop.key, path = hop.path })
  end
  for _, hop in pairs(hops) do
    table.insert(cands, { desc = hop.desc, on = hop.key, path = hop.path })
  end
  local hops_idx = ya.which { cands = cands }
  if not hops_idx then return end
  local selected_hop = cands[hops_idx]
  -- Handle special hops
  if selected_hop.path == "__MARK__" then
    local mark_cands = {};
    -- Ideally any unicode character would be supported, but yazi.which
    -- requies a concrete list of candidates
    local candidate_chars = {
      'a', 'b', 'c', 'd', 'e', 'f', 'g', 'h', 'i', 'j', 'k', 'l', 'm', 'n', 'o', 'p',
      'q', 'r', 's', 't', 'u', 'v', 'w', 'x', 'y', 'z', 'A', 'B', 'C', 'D', 'E', 'F',
      'G', 'H', 'I', 'J', 'K', 'L', 'M', 'N', 'O', 'P', 'Q', 'R', 'S', 'T', 'U', 'V',
      'W', 'X', 'Y', 'Z', '`', '~', '!', '@', '#', '$', '%', '^', '&', '*', '(', ')',
      '-', '_', '=', '+', '[', '{', ']', '}', '\\', '|', ';', ':', "'", '"', ',', '<',
      '.', '>', '/', '?', '0', '1', '2', '3', '4', '5', '6', '7', '8', '9'
    }
    for _, char in pairs(candidate_chars) do
      table.insert(mark_cands, { on = char })
    end
    info("Press a key to create new hop")
    local char_idx = ya.which { cands = mark_cands, silent = true }
    if char_idx ~= nil then
      local selected_char = mark_cands[char_idx].on
      local cwd = get_cwd()
      table.insert(hops, { key = selected_char, path = cwd, desc = path_to_desc(cwd, config.desc_strategy) })
      set_state("hops", sort_hops(hops))
    end
    return
  elseif selected_hop.path == "__FUZZY__" then
    local fuzzy_hop = select_fuzzy(hops, config)
    if not fuzzy_hop then return end
    selected_hop = fuzzy_hop
  end
  cd(selected_hop, config)
end

local function init()
  local options = get_state("options")
  local err = validate_options(options)
  if err then
    set_state("init_error", err)
    fail(err)
    return
  end
  -- Set default config values
  local desc_strategy = options.desc_strategy or "path"
  set_state("config", {
    desc_strategy = desc_strategy,
    fuzzy_cmd = some(options.fuzzy_cmd, "fzf"),
    notify = some(options.notify, false),
    ephemeral = some(options.ephemeral, true),
    tabs = some(options.tabs, true),
  })
  -- Set hops after ensuring they all have a description
  local hops = {}
  for _, hop in pairs(options.hops) do
    hop.desc = hop.desc or path_to_desc(hop.path, desc_strategy)
    -- Manually replace ~ from users so we can make a valid Url later to check if dir exists
    if string.sub(hop.path, 1, 1) == "~" then
      hop.path = os.getenv("HOME") .. hop.path:sub(2)
    end
    table.insert(hops, hop)
  end
  set_state("hops", sort_hops(hops))
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
  entry = function(self, job)
    if not get_state("init") then
      init()
    end
    local init_error = get_state("init_error")
    if init_error then
      fail(init_error)
      return
    end
    local hops, config = get_state("hops"), get_state("config")
    if job.args[1] == "fuzzy" then
      local fuzzy_hop = select_fuzzy(hops, config)
      if fuzzy_hop then
        cd(fuzzy_hop, config)
      end
    else
      attempt_hop(hops, config)
    end
  end,
}
