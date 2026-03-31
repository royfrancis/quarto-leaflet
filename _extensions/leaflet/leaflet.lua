-- leaflet.lua
-- Quarto shortcode extension for interactive Leaflet maps.
-- Supports two modes:
--   1. Named label: {{< leaflet map-name >}} (config from YAML frontmatter)
--   2. Inline args: {{< leaflet center="[lat,lon]" zoom=13 height="400px" >}}

local map_counter    = 0

-- ── Metadata helpers ────────────────────────────────────────────────────────

-- Convert any Pandoc metadata value to a plain string.
-- YAML scalars arrive as pandoc.MetaInlines; booleans arrive as native Lua
-- booleans; numbers as MetaInlines containing a digit string.
local function meta_to_str(val)
  if val == nil then return nil end
  if type(val) == "string"  then return val end
  if type(val) == "number"  then return tostring(val) end
  if type(val) == "boolean" then return tostring(val) end
  return pandoc.utils.stringify(val)
end

-- Convert metadata (including blocks/inlines) to HTML
local function meta_to_html(val)
  if val == nil then return nil end
  if type(val) == "string" then return val end
  -- Try rendering as HTML if it's structured (Inlines/Blocks)
  local ok, html = pcall(function()
    return pandoc.write(pandoc.Pandoc({pandoc.Para(val)}), "html")
  end)
  if ok and html then return html end
  return pandoc.utils.stringify(val)
end

-- Convert metadata to inline HTML (no block wrapper).
-- Useful for tooltips where <p> wrappers can add unwanted spacing.
local function meta_to_inline_html(val)
  if val == nil then return nil end
  if type(val) == "string" then return val end
  local ok, html = pcall(function()
    return pandoc.write(pandoc.Pandoc({pandoc.Plain(val)}), "html")
  end)
  if ok and html then
    return tostring(html):gsub("%s+$", "")
  end
  return pandoc.utils.stringify(val)
end

local function meta_to_num(val)
  local s = meta_to_str(val)
  return s and tonumber(s)
end

local function meta_to_nonempty_str(val)
  local s = meta_to_str(val)
  if s ~= nil then
    s = tostring(s):gsub("^%s+", ""):gsub("%s+$", "")
  end
  if s == nil or s == "" then return nil end
  return s
end

local function meta_to_bool(val)
  if type(val) == "boolean" then return val end
  local s = meta_to_str(val)
  if s == "true"  then return true  end
  if s == "false" then return false end
  return nil
end

-- Convert a MetaList of scalars to a Lua array of numbers.
-- Used for center: [lat, lon].
local function meta_list_to_nums(val)
  if type(val) ~= "table" then return nil end
  local result = {}
  for _, item in ipairs(val) do
    local n = meta_to_num(item)
    if n == nil then return nil end
    table.insert(result, n)
  end
  return #result > 0 and result or nil
end

-- ── Value parsers ────────────────────────────────────────────────────────────

-- Parse "[lat, lon]" string (from inline kwargs) into {lat, lon}.
local function parse_coord_str(s)
  if s == nil then return nil end
  local inner = s:match("^%s*%[(.-)%]%s*$")
  if inner == nil then return nil end
  local nums = {}
  for part in inner:gmatch("[^,]+") do
    local n = tonumber(part:match("^%s*(.-)%s*$"))
    if n == nil then return nil end
    table.insert(nums, n)
  end
  return #nums == 2 and nums or nil
end

local function trim(s)
  if s == nil then return nil end
  return (tostring(s):gsub("^%s+", ""):gsub("%s+$", ""))
end

local function append_markers(target, markers)
  if type(markers) ~= "table" then return end
  if target.markers == nil then target.markers = {} end
  for _, marker in ipairs(markers) do
    table.insert(target.markers, marker)
  end
end

local function marker_coords(marker)
  if type(marker) ~= "table" then return nil end

  local lat = tonumber(marker.lat)
  local lon = tonumber(marker.lon)
  if lat ~= nil and lon ~= nil then
    return lat, lon
  end

  if type(marker.position) == "table" and #marker.position == 2 then
    lat = tonumber(marker.position[1])
    lon = tonumber(marker.position[2])
    if lat ~= nil and lon ~= nil then
      return lat, lon
    end
  end

  return nil
end

local function marker_from_meta_entry(m_meta)
  if type(m_meta) ~= "table" then return nil end

  local m = {}
  local lat = meta_to_num(m_meta["lat"] or m_meta["latitude"])
  local lon = meta_to_num(m_meta["lon"] or m_meta["lng"] or m_meta["long"] or m_meta["longitude"])
  if lat ~= nil and lon ~= nil then
    m.lat = lat
    m.lon = lon
  elseif m_meta["position"] then
    -- Backward-compatible fallback for older docs using position: [lat, lon].
    local pos = meta_list_to_nums(m_meta["position"])
    if pos and #pos == 2 then
      m.lat = pos[1]
      m.lon = pos[2]
    end
  end

  if m_meta["popup"]   then m.popup   = meta_to_html(m_meta["popup"]) end
  if m_meta["tooltip"] then m.tooltip = meta_to_inline_html(m_meta["tooltip"]) end
  if m_meta["icon"] then
    local iv = m_meta["icon"]
    if type(iv) == "table" and iv["url"] then
      m.icon = {
        url    = meta_to_str(iv["url"]),
        size   = iv["size"]   and meta_list_to_nums(iv["size"]),
        anchor = iv["anchor"] and meta_list_to_nums(iv["anchor"]),
      }
    else
      m.icon = meta_to_str(iv)
    end
  end
  if m_meta["icon-color"]  then m.icon_color  = meta_to_str(m_meta["icon-color"]) end
  if m_meta["icon-size"]   then m.icon_size   = meta_to_num(m_meta["icon-size"]) end
  if m_meta["icon-anchor"] then m.icon_anchor = meta_list_to_nums(m_meta["icon-anchor"]) end

  return m
end

local function marker_from_json_entry(mj)
  if type(mj) ~= "table" then return nil end

  local m = {}
  local lat = tonumber(mj["lat"] or mj["latitude"])
  local lon = tonumber(mj["lon"] or mj["lng"] or mj["long"] or mj["longitude"])
  if lat ~= nil and lon ~= nil then
    m.lat = lat
    m.lon = lon
  elseif type(mj["position"]) == "table" and #mj["position"] == 2 then
    -- Backward-compatible fallback for older docs using position: [lat, lon].
    m.lat = tonumber(mj["position"][1])
    m.lon = tonumber(mj["position"][2])
  end
  m.popup       = mj["popup"]
  m.tooltip     = mj["tooltip"]
  m.icon        = mj["icon"]
  m.icon_color  = mj["icon-color"]
  m.icon_size   = mj["icon-size"]
  m.icon_anchor = mj["icon-anchor"]

  return m
end

-- Returns the midpoint of the bounding box of all marker coordinates.
-- Unlike the centroid (arithmetic mean), this is unbiased with respect to
-- point density: every point contributes equally to the spatial extent
-- regardless of how many neighbours it has nearby.
local function center_from_markers(markers)
  if type(markers) ~= "table" then return nil end

  local count = 0
  local lat_min, lat_max = math.huge, -math.huge
  local lon_min, lon_max = math.huge, -math.huge

  for _, marker in ipairs(markers) do
    local lat, lon = marker_coords(marker)
    if lat ~= nil and lon ~= nil then
      count = count + 1
      if lat < lat_min then lat_min = lat end
      if lat > lat_max then lat_max = lat end
      if lon < lon_min then lon_min = lon end
      if lon > lon_max then lon_max = lon end
    end
  end

  if count == 0 then return nil end
  return { (lat_min + lat_max) / 2, (lon_min + lon_max) / 2 }
end

local function split_delimited_line(line, separator)
  local cells = {}
  line = (line or ""):gsub("\r$", "")
  local sep = separator or "\t"

  if sep == "\\t" then sep = "\t" end
  if sep == "" then
    table.insert(cells, trim(line) or "")
    return cells
  end

  -- CSV quoting support is kept for comma-delimited files.
  if sep == "," then
    local cell = ""
    local in_quotes = false
    local i = 1

    while i <= #line do
      local ch = line:sub(i, i)
      if ch == '"' then
        if in_quotes and line:sub(i + 1, i + 1) == '"' then
          cell = cell .. '"'
          i = i + 1
        else
          in_quotes = not in_quotes
        end
      elseif ch == "," and not in_quotes then
        table.insert(cells, trim(cell) or "")
        cell = ""
      else
        cell = cell .. ch
      end
      i = i + 1
    end

    table.insert(cells, trim(cell) or "")
    return cells
  end

  local from = 1
  while true do
    local start_idx, end_idx = line:find(sep, from, true)
    if start_idx == nil then
      table.insert(cells, trim(line:sub(from)) or "")
      break
    end
    table.insert(cells, trim(line:sub(from, start_idx - 1)) or "")
    from = end_idx + 1
  end
  return cells
end

local function default_separator_for_path(path)
  if path == nil then return "\t" end
  local p = tostring(path):lower()
  if p:match("%.csv$") then return "," end
  if p:match("%.tsv$") then return "\t" end
  return "\t"
end

local function normalize_header_key(key)
  return ((trim(key) or ""):lower():gsub("[%s_%-]+", ""))
end

local function resolve_doc_path(path)
  if path == nil or path == "" then return path end
  if path:match("^/") or path:match("^%a:[/\\]") then return path end
  local input_files = PANDOC_STATE and PANDOC_STATE.input_files or nil
  local input_file = input_files and input_files[1] or nil
  if input_file == nil or input_file == "" then return path end
  local doc_dir = pandoc.path.directory(input_file)
  if doc_dir == nil or doc_dir == "" then return path end
  return pandoc.path.join({ doc_dir, path })
end

local function marker_from_row(row)
  local lat = tonumber(row.lat or row.latitude)
  local lon = tonumber(row.lon or row.lng or row.long or row.longitude)
  if lat == nil or lon == nil then return nil end

  local marker = { lat = lat, lon = lon }
  if row.popup and row.popup ~= "" then marker.popup = row.popup end
  if row.tooltip and row.tooltip ~= "" then marker.tooltip = row.tooltip end

  local icon_url = row.iconurl
  local icon = row.icon
  local icon_anchor = nil
  if row.iconanchor and row.iconanchor ~= "" then
    local x, y = tostring(row.iconanchor):match("(%d+),%s*(%d+)")
    if x and y then
      icon_anchor = { tonumber(x), tonumber(y) }
    end
  end
  local icon_size_pair = row.iconsize and parse_coord_str(row.iconsize) or nil

  if icon_url and icon_url ~= "" then
    marker.icon = { url = icon_url }
    if icon_size_pair then marker.icon.size = icon_size_pair end
    if icon_anchor then marker.icon.anchor = icon_anchor end
  elseif icon and icon ~= "" then
    marker.icon = icon
    if row.iconcolor and row.iconcolor ~= "" then marker.icon_color = row.iconcolor end
    if row.iconsize and row.iconsize ~= "" then marker.icon_size = tonumber(row.iconsize) end
    if icon_anchor then marker.icon_anchor = icon_anchor end
  end

  return marker
end

local function markers_from_file(markers_path, separator)
  local sep = separator or default_separator_for_path(markers_path)
  if sep == "\\t" then sep = "\t" end

  local resolved_path = resolve_doc_path(markers_path)
  local handle = nil
  local candidate_paths = { resolved_path }
  if resolved_path ~= markers_path then table.insert(candidate_paths, markers_path) end
  for _, candidate_path in ipairs(candidate_paths) do
    handle = io.open(candidate_path, "r")
    if handle ~= nil then break end
  end
  if handle == nil then
    return nil, string.format("could not read markers file '%s'", markers_path)
  end

  local header_keys = nil
  local markers = {}

  for line in handle:lines() do
    local trimmed = trim(line)
    if trimmed ~= nil and trimmed ~= "" and not trimmed:match("^#") then
      local cells = split_delimited_line(line, sep)
      if header_keys == nil then
        header_keys = {}
        for _, cell in ipairs(cells) do
          table.insert(header_keys, normalize_header_key(cell))
        end
      else
        local row = {}
        for idx, key in ipairs(header_keys) do
          row[key] = cells[idx] or ""
        end
        local marker = marker_from_row(row)
        if marker ~= nil then table.insert(markers, marker) end
      end
    end
  end

  handle:close()

  if header_keys == nil then
    return nil, string.format("markers file '%s' is empty", markers_path)
  end

  return markers
end

local function append_markers_from_file(cfg, markers_file, markers_sep)
  if not markers_file then return nil end
  local markers, err = markers_from_file(markers_file, markers_sep)
  if err then return err end
  append_markers(cfg, markers)
  return nil
end

-- ── JSON encoder ─────────────────────────────────────────────────────────────

local function json(val)
  if val == nil then return "null" end
  if type(val) == "boolean" then return tostring(val) end
  if type(val) == "number" then
    if val == math.floor(val) and math.abs(val) < 1e15 then
      return string.format("%d", val)
    end
    return tostring(val)
  end
  if type(val) == "string" then
    val = val
      :gsub('\\', '\\\\')
      :gsub('"',  '\\"')
      :gsub('\n', '\\n')
      :gsub('\r', '\\r')
      :gsub('\t', '\\t')
    return '"' .. val .. '"'
  end
  if type(val) == "table" then
    local n = #val
    -- Decide array vs object: array when #val > 0 and all keys are 1..n
    local is_arr = n > 0
    if is_arr then
      for i = 1, n do
        if val[i] == nil then is_arr = false; break end
      end
    end
    if is_arr then
      local parts = {}
      for _, v in ipairs(val) do table.insert(parts, json(v)) end
      return "[" .. table.concat(parts, ",") .. "]"
    else
      local keys = {}
      for k in pairs(val) do table.insert(keys, k) end
      table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
      local parts = {}
      for _, k in ipairs(keys) do
        table.insert(parts, json(tostring(k)) .. ":" .. json(val[k]))
      end
      return "{" .. table.concat(parts, ",") .. "}"
    end
  end
  return "null"
end

-- ── Config extraction ────────────────────────────────────────────────────────

-- Keys handled explicitly; everything else is treated as an L.map passthrough.
local SPECIAL = {
  center=true,
  zoom=true,
  height=true,
  width=true,
  markers=true,
  ["markers-file"]=true,
  markers_file=true,
  ["markers-sep"]=true,
  markers_sep=true,
  tile=true,
}

local function is_meta_map_value(val)
  if type(val) ~= "table" then return false end
  if val.t ~= nil then return val.t == "MetaMap" end
  for k, _ in pairs(val) do
    if type(k) ~= "number" then return true end
  end
  return false
end

local function build_leaflet_defaults_meta(leaflet_meta)
  if type(leaflet_meta) ~= "table" then return {} end

  local defaults = {}
  for k, v in pairs(leaflet_meta) do
    if k ~= "markers" then
      if SPECIAL[k] then
        defaults[k] = v
      elseif not is_meta_map_value(v) then
        defaults[k] = v
      end
    end
  end

  return defaults
end

local function merge_cfg(base_cfg, override_cfg)
  local merged = {}

  if type(base_cfg) == "table" then
    for k, v in pairs(base_cfg) do
      merged[k] = v
    end
  end

  if type(override_cfg) ~= "table" then return merged end

  for k, v in pairs(override_cfg) do
    if k == "markers" then
      if type(v) == "table" then
        append_markers(merged, v)
      end
    elseif k == "tile" and type(v) == "table" then
      local tile = {}
      if type(merged.tile) == "table" then
        for tk, tv in pairs(merged.tile) do tile[tk] = tv end
      end
      for tk, tv in pairs(v) do tile[tk] = tv end
      merged.tile = tile
    else
      merged[k] = v
    end
  end

  return merged
end

-- Build a config table from a YAML metadata map (MetaMap).
local function cfg_from_meta(mm)
  -- Guard: must be a table (MetaMap or similar); plain scalars have no map config.
  if type(mm) ~= "table" then return {} end
  local cfg = {}

  if mm["center"] then cfg.center = meta_list_to_nums(mm["center"]) end
  if mm["zoom"]   then cfg.zoom   = meta_to_num(mm["zoom"]) end
  if mm["height"] then cfg.height = meta_to_str(mm["height"]) end
  if mm["width"]  then cfg.width  = meta_to_str(mm["width"]) end

  -- tile sub-table
  if mm["tile"] and type(mm["tile"]) == "table" then
    cfg.tile = {}
    for k, v in pairs(mm["tile"]) do
      local s = meta_to_str(v)
      cfg.tile[k] = tonumber(s) or s
    end
  end

  -- markers list
  if mm["markers"] and type(mm["markers"]) == "table" then
    local markers = {}
    for _, m_meta in ipairs(mm["markers"]) do
      local m = marker_from_meta_entry(m_meta)
      if m ~= nil then table.insert(markers, m) end
    end
    append_markers(cfg, markers)
  end

  local markers_file =
    meta_to_nonempty_str(mm["markers-file"]) or
    meta_to_nonempty_str(mm["markers_file"])
  local markers_sep =
    meta_to_nonempty_str(mm["markers-sep"]) or
    meta_to_nonempty_str(mm["markers_sep"])
  local markers_err = append_markers_from_file(cfg, markers_file, markers_sep)
  if markers_err then return nil, markers_err end

  -- Passthrough: any non-special key → L.map option
  for k, v in pairs(mm) do
    if not SPECIAL[k] then
      local b = meta_to_bool(v)
      if b ~= nil then
        cfg[k] = b
      else
        cfg[k] = meta_to_num(v) or meta_to_str(v)
      end
    end
  end

  return cfg, nil
end

-- Build a config table from inline shortcode kwargs (values are strings or
-- pandoc.Inlines depending on Quarto version; meta_to_str handles both).
local function cfg_from_kwargs(kwargs)
  local cfg = {}

  local function kstr(k) return meta_to_nonempty_str(kwargs[k]) end

  local c_str = kstr("center")
  if c_str then cfg.center = parse_coord_str(c_str) end
  local z = kstr("zoom");   if z then cfg.zoom   = tonumber(z) end
  local h = kstr("height"); if h then cfg.height = h end
  local w = kstr("width");  if w then cfg.width  = w end

  -- tile as inline JSON string, e.g.
  -- tile='{"url":"https://.../{z}/{x}/{y}.png","attribution":"..."}'
  local t_str = kstr("tile")
  if t_str then
    local ok, parsed = pcall(pandoc.json.decode, t_str)
    if ok and type(parsed) == "table" then
      local tile_obj = nil
      if parsed.url ~= nil then
        tile_obj = parsed
      elseif #parsed == 1 and type(parsed[1]) == "table" and parsed[1].url ~= nil then
        -- Backward-compatible support for a single-item array wrapper.
        tile_obj = parsed[1]
      end

      if tile_obj ~= nil then
        cfg.tile = {}
        for k, v in pairs(tile_obj) do
          if type(v) == "string" then
            cfg.tile[k] = tonumber(v) or v
          else
            cfg.tile[k] = v
          end
        end
      end
    end
  end

  -- markers as inline JSON string, e.g. markers='[{"lat":51.5,"lon":-0.09,"popup":"text"}]'
  local m_str = kstr("markers")
  if m_str then
    local ok, parsed = pcall(pandoc.json.decode, m_str)
    if ok and type(parsed) == "table" then
      local markers = {}
      for _, mj in ipairs(parsed) do
        local m = marker_from_json_entry(mj)
        if m ~= nil then table.insert(markers, m) end
      end
      append_markers(cfg, markers)
    end
  end

  local markers_file =
    kstr("markers-file") or
    kstr("markers_file")
  local markers_sep =
    kstr("markers-sep") or
    kstr("markers_sep")
  local markers_err = append_markers_from_file(cfg, markers_file, markers_sep)
  if markers_err then return nil, markers_err end

  for k, v in pairs(kwargs) do
    if not SPECIAL[k] then
      local s = meta_to_str(v)
      local s_lc = s and s:lower() or nil
      if     s_lc == "true"  then cfg[k] = true
      elseif s_lc == "false" then cfg[k] = false
      else cfg[k] = tonumber(s) or s
      end
    end
  end

  return cfg, nil
end

-- ── JavaScript builder ───────────────────────────────────────────────────────

local function build_js(map_id, map_var, cfg)
  local out = {}

  -- Fix Leaflet default marker icon path for Quarto deployments.
  -- Leaflet's built-in _detectIconPath() has a broken link-element fallback that
  -- omits the images/ subdirectory.  This override uses the <link> href to build
  -- the correct absolute path before any marker is added.  The typeof guard makes
  -- it a no-op once imagePath is already set (e.g. by a previous map on the page).
  table.insert(out,
    'if (typeof L.Icon.Default.imagePath !== "string") {\n' ..
    '  var _ql = document.querySelector(\'link[href*="quarto-leaflet"][href$="leaflet.css"]\');\n' ..
    '  if (_ql) { L.Icon.Default.imagePath = _ql.href.replace(/leaflet\\.css$/, "") + "images/"; }\n' ..
    '}\n')

  -- revealjs: maps on non-present slides are initialized while hidden and can
  -- render with wrong dimensions. Keep a global registry and invalidate sizes
  -- when slides become visible.
  table.insert(out,
    'window.__quartoLeafletMaps = window.__quartoLeafletMaps || [];\n' ..
    'window.__quartoLeafletWireReveal = window.__quartoLeafletWireReveal || function() {\n' ..
    '  if (window.__quartoLeafletRevealFix || typeof Reveal === "undefined") { return; }\n' ..
    '  window.__quartoLeafletRevealFix = true;\n' ..
    '  var _qlRefresh = function() {\n' ..
    '    setTimeout(function() {\n' ..
    '      window.__quartoLeafletMaps.forEach(function(m) {\n' ..
    '        if (m && typeof m.invalidateSize === "function") { m.invalidateSize(true); }\n' ..
    '      });\n' ..
    '    }, 60);\n' ..
    '  };\n' ..
    '  Reveal.on("ready", _qlRefresh);\n' ..
    '  Reveal.on("slidechanged", _qlRefresh);\n' ..
    '  Reveal.on("resize", _qlRefresh);\n' ..
    '  _qlRefresh();\n' ..
    '};\n' ..
    'window.__quartoLeafletWireReveal();\n' ..
    'if (document.readyState === "loading") {\n' ..
    '  document.addEventListener("DOMContentLoaded", window.__quartoLeafletWireReveal, {once: true});\n' ..
    '} else {\n' ..
    '  setTimeout(window.__quartoLeafletWireReveal, 0);\n' ..
    '}\n')

  -- L.map(id, options)
  local map_opts = { center = cfg.center, zoom = cfg.zoom }
  for k, v in pairs(cfg) do
    if not SPECIAL[k] then map_opts[k] = v end
  end
  table.insert(out, string.format("var %s = L.map('%s', %s);\n",
    map_var, map_id, json(map_opts)))

  -- Tile layer
  local tile_url  = "https://tile.openstreetmap.org/{z}/{x}/{y}.png"
  local tile_opts = {
    attribution = '&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a> contributors'
  }
  if cfg.tile then
    if cfg.tile.url         then tile_url             = cfg.tile.url end
    if cfg.tile.attribution then tile_opts.attribution = cfg.tile.attribution end
    for k, v in pairs(cfg.tile) do
      if k ~= "url" and k ~= "attribution" then tile_opts[k] = v end
    end
  end
  table.insert(out, string.format("L.tileLayer(%s, %s).addTo(%s);\n",
    json(tile_url), json(tile_opts), map_var))

  -- Markers
  if cfg.markers then
    for _, m in ipairs(cfg.markers) do
      local lat, lon = marker_coords(m)

      if lat ~= nil and lon ~= nil then
        local coords = { lat, lon }
        local popup_offset = nil
        local tooltip_offset = nil
        
        if m.icon then
          local ic = m.icon
          if type(ic) == "table" and ic.url then
            -- Custom image icon
            local opts = {
              iconUrl    = ic.url,
              iconSize   = ic.size   or {25, 41},
              iconAnchor = m.icon_anchor or ic.anchor or {12, 41},
            }
            table.insert(out, string.format("var _icon = L.icon(%s);\n", json(opts)))
            table.insert(out, string.format(
              "var _m = L.marker(%s, {icon: _icon}).addTo(%s);\n",
              json(coords), map_var))
          else
            -- Font icon rendered as a white glyph on a colored location-pin background.
            local sz         = m.icon_size or 14
            local color      = m.icon_color or "currentColor"
            -- Keep a near-constant visual padding around the glyph across sizes.
            local pin_padding = 4
            local pin_head_ratio = 0.6
            local pin_size   = math.max(math.ceil((sz + 2 * pin_padding) / pin_head_ratio), sz + 10)
            local ax         = m.icon_anchor and m.icon_anchor[1] or math.floor(pin_size / 2)
            local ay         = m.icon_anchor and m.icon_anchor[2] or pin_size
            local html       = string.format(
              '<span class="quarto-leaflet-icon-pin" style="--ql-icon-size:%dpx;--ql-pin-size:%dpx;--ql-pin-color:%s;"><i class="fa-solid fa-location-pin quarto-leaflet-icon-pin-bg" aria-hidden="true"></i><i class="%s quarto-leaflet-icon-glyph" aria-hidden="true"></i></span>',
              sz, pin_size, color, ic)
            table.insert(out, string.format(
              'var _icon = L.divIcon({html: %s, className: "leaflet-div-icon-custom", iconSize: [%d, %d], iconAnchor: [%d, %d]});\n',
              json(html), pin_size, pin_size, ax, ay))
            table.insert(out, string.format(
              "var _m = L.marker(%s, {icon: _icon}).addTo(%s);\n",
              json(coords), map_var))
            -- Offset for font icons, scaled by pin size
            popup_offset = {0, -pin_size}
            tooltip_offset = {math.ceil(pin_size / 2), -math.ceil(pin_size / 2)}
          end
        else
          table.insert(out, string.format("var _m = L.marker(%s).addTo(%s);\n",
            json(coords), map_var))
        end
        
        if m.popup then
          if popup_offset then
            table.insert(out, string.format("_m.bindPopup(%s, {offset: %s});\n", json(m.popup), json(popup_offset)))
          else
            table.insert(out, string.format("_m.bindPopup(%s);\n", json(m.popup)))
          end
        end
        if m.tooltip then
          if tooltip_offset then
            table.insert(out, string.format("_m.bindTooltip(%s, {offset: %s});\n", json(m.tooltip), json(tooltip_offset)))
          else
            table.insert(out, string.format("_m.bindTooltip(%s);\n", json(m.tooltip)))
          end
        end
      end
    end
  end

  table.insert(out, string.format("window.__quartoLeafletMaps.push(%s);\n", map_var))

  return table.concat(out)
end

-- ── HTML helper ─────────────────────────────────────────────────────────────

-- Escape user-supplied strings so they are safe for inline HTML output.
local function html_esc(s)
  return (tostring(s)
    :gsub("&", "&amp;")
    :gsub("<", "&lt;")
    :gsub(">", "&gt;")
    :gsub('"', "&quot;"))
end

-- ── Resource inclusion ───────────────────────────────────────────────────────

local resources_added = false
local fontawesome_added = false

local function add_resources()
  if resources_added then return end
  resources_added = true
  if not fontawesome_added then
    quarto.doc.include_text("in-header",
      '<link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.5.2/css/all.min.css">')
    fontawesome_added = true
  end
  quarto.doc.add_html_dependency({
    name        = "quarto-leaflet",
    version     = "1.0.0",
    resources   = {
      { path = "assets/images/marker-icon.png",    name = "images/marker-icon.png"    },
      { path = "assets/images/marker-icon-2x.png", name = "images/marker-icon-2x.png" },
      { path = "assets/images/marker-shadow.png",  name = "images/marker-shadow.png"  },
      { path = "assets/images/layers.png",         name = "images/layers.png"         },
      { path = "assets/images/layers-2x.png",      name = "images/layers-2x.png"      },
    },
    stylesheets = { "assets/leaflet.css", "quarto-leaflet.css" },
    scripts     = { { path = "assets/leaflet.js" } },
  })
end

-- ── Shortcode entry point ────────────────────────────────────────────────────

return {
  ["leaflet"] = function(args, kwargs, meta)

    -- ── Parse config (needed for both HTML and static fallback) ──────────────
    local cfg
    local function err_str(msg)
      return pandoc.RawInline("html",
        '<span style="color:#c00;background:#fee;border:1px solid #c00;'
        .. 'padding:2px 6px;border-radius:3px;font-family:monospace;font-size:.9em;">'
        .. '&#x26A0; leaflet: ' .. html_esc(msg) .. '</span>')
    end

    if #args == 1 and next(kwargs) == nil then
      local label        = pandoc.utils.stringify(args[1])
      local leaflet_meta = meta["leaflet"]
      if leaflet_meta == nil then
        return err_str("no 'leaflet' key in document metadata")
      end
      local map_meta = leaflet_meta[label]
      if map_meta == nil then
        return err_str(string.format("map '%s' not found in metadata", label))
      end
      local cfg_err
      local defaults_cfg, defaults_err = cfg_from_meta(build_leaflet_defaults_meta(leaflet_meta))
      if defaults_err then return err_str(defaults_err) end

      local map_cfg
      map_cfg, cfg_err = cfg_from_meta(map_meta)
      if cfg_err then return err_str(cfg_err) end
      cfg = merge_cfg(defaults_cfg, map_cfg)
    else
      local cfg_err
      cfg, cfg_err = cfg_from_kwargs(kwargs)
      if cfg_err then return err_str(cfg_err) end
    end

    if cfg.center == nil then
      cfg.center = center_from_markers(cfg.markers)
    end

    if cfg.zoom == nil then
      cfg.zoom = 13
    end

    if cfg.center == nil then return err_str("'center' is required") end

    -- ── Non-HTML/revealjs formats: produce no output ─────────────────────────
    if not (quarto.doc.is_format("html") or quarto.doc.is_format("revealjs")) then
      return pandoc.RawBlock("latex", "")
    end

    -- ── HTML / revealjs output ───────────────────────────────────────────────
    add_resources()
    map_counter = map_counter + 1
    local map_id  = "quarto-leaflet-map-" .. map_counter   -- HTML element id
    local map_var = "quartoLeafletMap" .. map_counter       -- JS variable name

    local height = cfg.height or "400px"
    local width  = cfg.width or "100%"
    local div    = string.format(
      '<div id="%s" class="quarto-leaflet-map" style="height: %s; width: %s;"></div>',
      map_id, height, width)

    local ok_js, js_result = pcall(build_js, map_id, map_var, cfg)
    if not ok_js then
      return err_str("render error: " .. tostring(js_result))
    end
    local script = string.format("<script>\n%s</script>", js_result)

    return pandoc.RawInline("html", div .. "\n" .. script)
  end,
}
