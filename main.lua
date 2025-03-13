local function debug(...)
  local function toReadableString(val)
    if type(val) == "table" then
      local str = "{ "
      for k, v in pairs(val) do
        str = str .. "[" .. tostring(k) .. "] = " .. toReadableString(v) .. ", "
      end
      return str:sub(1, -3) .. " }"
    elseif type(val) == "Url" then
      return "Url:"..tostring(val)
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
local function fail(s, ...) ya.notify { title = "bunny.yazi", content = string.format(s, ...), timeout = 3, level = "error" } end
local function info(s, ...) ya.notify { title = "bunny.yazi", content = string.format(s, ...), timeout = 3, level = "info" } end

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

local function filename(pathstr)
  if pathstr == "/" then return pathstr end
  local url_name = Url(pathstr):name()
  if url_name then
    return tostring(url_name)
  else
    return pathstr
  end
end


local create_special_hops = function()
  local hops = {}
  table.insert(hops, { key = "<space>", tag = "fuzzy search", path = "__FUZZY__" })
  table.insert(hops, { key = "<enter>", tag = "create mark", path = "__MARK__" })
  local marked_dir = get_state("mark")
  if marked_dir and marked_dir ~= "" then
    table.insert(hops, { key = "<tab>", tag = filename(marked_dir), path = marked_dir, })
  end
  local tabhist = get_state("tabhist")
  local tab = get_current_tab_idx()
  if tabhist[tab] and tabhist[tab][2] then
    local previous_dir = tabhist[tab][2]
    table.insert(hops, { key = "<backspace>", tag = filename(previous_dir), path = previous_dir })
  end
  return hops
end

local validate_options = function(options)
  local hops, fuzzy_cmd, notify = options.hops, options.fuzzy_cmd, options.notify
  -- Validate hops
  if hops ~= nil and type(hops) ~= "table" then
    return "Invalid hops value"
  elseif hops ~= nil then
    local used_keys = ""
    for idx, item in pairs(hops) do
      local hop = "Hop #" .. idx .. " "
      if not item.key then
        return hop .. 'has missing key'
      elseif type(item.key) ~= "string" or #item.key ~= 1 then
        return hop .. 'has invalid key'
      elseif not item.path then
        return hop .. 'has missing path'
      elseif type(item.path) ~= "string" or #item.path == 0 then
        return hop .. 'has invalid path'
      elseif not item.tag then
        return hop .. 'has missing tag'
      elseif type(item.tag) ~= "string" or #item.tag == 0 then
        return hop .. 'has invalid tag'
      end
      -- Check for duplicate keys
      if string.find(used_keys, item.key, 1, true) then
        return hop .. 'has duplicate key'
      end
      used_keys = used_keys .. item.key
    end
  end
  -- Validate other options
  if fuzzy_cmd ~= nil and type(fuzzy_cmd) ~= "string" then
    return "Invalid fuzzy_cmd value"
  elseif notify ~= nil and type(notify) ~= "boolean" then
    return "Invalid notify value"
  end
end

-- https://github.com/sxyazi/yazi/blob/main/yazi-plugin/preset/plugins/fzf.lua
-- https://github.com/sxyazi/yazi/blob/main/yazi-plugin/src/process/child.rs
local select_fuzzy = function(hops, fuzzy_cmd)
  local _permit = ya.hide()
  local child, err =
      Command(fuzzy_cmd):stdin(Command.PIPED):stdout(Command.PIPED):stderr(Command.INHERIT):spawn()
  if not child then
    fail("Spawn `%s` failed with error code %s. Do you have it installed?", fuzzy_cmd, err)
    return
  end
  -- Build fzf input string
  local input_lines = {};
  for _, item in pairs(hops) do
    local line_elems = { item.tag, item.path, item.key }
    table.insert(input_lines, table.concat(line_elems, "\t"))
  end
  child:write_all(table.concat(input_lines, "\n"))
  child:flush()
  local output, err = child:wait_with_output()
  if not output then
    fail("Cannot read `%s` output, error code %s", fuzzy_cmd, err)
    return
  elseif not output.status.success and output.status.code ~= 130 then
    fail("`%s` exited with error code %s", fuzzy_cmd, output.status.code)
    return
  end
  -- Parse fzf output
  local tag, path = string.match(output.stdout, "(.-)\t(.-)\t(.-)")
  if not tag or not path or path == "" then
    fail("Failed to parse fuzzy searcher result")
    return
  end
  return { tag = tag, path = path }
end

local hop = function(hops, fuzzy_cmd, notify)
  local cands = {}
  for _, item in pairs(create_special_hops()) do
    table.insert(cands, { desc = item.tag, on = item.key, path = item.path })
  end
  for _, item in pairs(hops) do
    table.insert(cands, { desc = item.tag, on = item.key, path = item.path })
  end
  local idx = ya.which { cands = cands }
  if idx == nil then
    return
  end
  local selection = cands[idx]
  local selected_hop = { tag = selection.desc, path = selection.path }
  -- Handle special hops
  if selected_hop.path == "__MARK__" then
    local cwd = get_cwd()
    if cwd then
      set_state("mark", cwd)
      if notify then
        info("Marked current directory")
      end
    else
      fail("Failed to set mark")
    end
    return
  elseif selected_hop.path == "__NOOP__" then
    if notify then
      info("No marked directory")
    end
    return
  elseif selected_hop.path == "__FUZZY__" then
    local mark_state = get_state("mark")
    if mark_state and mark_state ~= "" then
      table.insert(hops, { key = "", tag = "marked", path = mark_state, })
    end
    local fuzzy_hop = select_fuzzy(hops, fuzzy_cmd)
    if fuzzy_hop then
      selected_hop = fuzzy_hop
    else
      return
    end
  end
  ya.mgr_emit("cd", { selected_hop.path })
  -- TODO: Better way to verify hop was successful?
  if notify then
    local tag = selected_hop.tag
    if tag == "hop to mark" then
      tag = "mark"
    end
    if tag then
      info('Hopped to ' .. tag)
    end
  end
end

return {
  setup = function(state, options)
    local err = validate_options(options)
    if err then
      state.init_error = err
      fail(err)
      return
    end
    state.fuzzy_cmd = options.fuzzy_cmd or "fzf"
    state.notify = options.notify or false
    local hops = options.hops or {}
    table.sort(hops, function(x, y)
      local same_letter = string.lower(x.key) == string.lower(y.key)
      if same_letter then
        -- lowercase comes first
        return x.key > y.key
      else
        return string.lower(x.key) < string.lower(y.key)
      end
    end)
    state.hops = hops
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
    local init_error = get_state("init_error")
    if init_error then
      fail(init_error)
      return
    end
    local hops, fuzzy_cmd, notify = get_state("hops"), get_state("fuzzy_cmd"), get_state("notify")
    hop(hops, fuzzy_cmd, notify)
  end,
}
