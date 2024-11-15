local function fail(s, ...) ya.notify { title = "bunny.yazi", content = string.format(s, ...), timeout = 3, level = "error" } end
local function info(s, ...) ya.notify { title = "bunny.yazi", content = string.format(s, ...), timeout = 3, level = "info" } end

local get_state_attr = ya.sync(function(state, attr)
  return state[attr]
end)

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
    return fail("Spawn `%s` failed with error code %s. Do you have it installed?", fuzzy_cmd, err)
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
    return fail("Cannot read `%s` output, error code %s", fuzzy_cmd, err)
  elseif not output.status.success and output.status.code ~= 130 then
    return fail("`%s` exited with error code %s", fuzzy_cmd, output.status.code)
  end
  -- Remove trailing newline
  local target = output.stdout:gsub("\n$", "")
  if not target or target == "" then
    return nil
  end
  -- Parse fzf output
  local tag, path = string.match(target, "(.-)\t(.-)\t.*")
  return { tag = tag, path = path }
end

local select_key = function(hops)
  local cands = {}
  for _, item in pairs(hops) do
    table.insert(cands, { desc = item.tag, on = item.key, path = item.path })
  end
  if #cands == 0 then
    fail("Empty hops table")
    return nil
  end
  local idx = ya.which { cands = cands }
  if idx == nil then
    return nil
  end
  local selection = cands[idx]
  return { tag = selection.desc, path = selection.path }
end

local hop = function(selected_hop, notify)
  if not selected_hop or not selected_hop.path then
    fail("Hop failed")
    return
  end
  ya.manager_emit("cd", { selected_hop.path })
  if notify then
    info('Hopped to "' .. selected_hop.tag .. '"')
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
  end,
  entry = function(_self, args)
    local init_error = get_state_attr("init_error")
    if init_error then
      fail(init_error)
      return
    end
    local fuzzy_cmd, hops, notify = get_state_attr("fuzzy_cmd"), get_state_attr("hops"), get_state_attr("notify")
    local select_by = args[1] or "key"
    if select_by == "key" then
      hop(select_key(hops), notify)
    elseif select_by == "fuzzy" then
      hop(select_fuzzy(hops, fuzzy_cmd), notify)
    end
  end,
}
