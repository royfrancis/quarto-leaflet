# leaflet ![build](https://github.com/royfrancis/quarto-leaflet/workflows/deploy/badge.svg) ![status: experimental](https://github.com/GIScience/badges/raw/master/status/experimental.svg)

A Quarto shortcode extension to embed interactive [Leaflet](https://leafletjs.com/) maps in **HTML** and **revealjs** formats.

:warning: This does not support all leaflet features. It is intended for simple maps with markers and custom tiles.

## Install

Requires Quarto >= 1.4.0. In your project root:

```bash
quarto add royfrancis/quarto-leaflet
```

## Usage

### YAML metadata

Define maps in the YAML frontmatter and reference by label:

```yaml
---
leaflet:
  mymap:
    center: [59.33, 18.07]
    zoom: 12
    height: "400px"
    markers:
      - lat: 59.33
        lon: 18.07
        popup: "<b>Stockholm</b>"
        icon: "fa-solid fa-location-dot"
        icon-color: "red"
---

{{< leaflet mymap >}}
```

### Inline arguments

```
{{< leaflet center="[51.505, -0.09]" zoom=13 height="400px" >}}
```

Inline markers are passed as JSON using `lat` and `lon`:

```lua
{{< leaflet center="[59.33, 18.07]" zoom=12 markers='[{"lat":59.33,"lon":18.07,"popup":"Stockholm"}]' >}}
```

If `center` is omitted and markers are provided, the extension derives the
center automatically as the midpoint of the bounding box of all marker
coordinates. This is unbiased with respect to point density — a dense cluster
has no more influence on the center than a single isolated point. If `zoom` is
omitted, it defaults to `13`.

### Markers with icons

```yaml
markers:
  - lat: 48.86
    lon: 2.35
    popup: "Paris"
    icon: "fa-solid fa-location-dot"    # Font Awesome
    icon-color: "tomato"
    icon-size: 24
  - lat: 48.86
    lon: 2.29
    popup: "Eiffel Tower"
    icon: "fa-solid fa-tower-broadcast"  # FontAwesome
  - lat: 48.85
    lon: 2.35
    popup: "Custom"
    icon:
      url: "marker.png"       # Custom image
      size: [25, 41]
      anchor: [12, 41]
```

### Markers from text files

You can load markers from any delimited text file:

```yaml
leaflet:
  mymap:
    center: [59.33, 18.07]
    zoom: 12
    markers-file: "data/stockholm-markers.txt"
    markers-sep: "|"
```

The file must include coordinate columns (`lat` + `lon`).

Defaults: comma for `.csv`, tab for `.tsv`, tab otherwise.

### Passthrough options

Any [Leaflet Map option](https://leafletjs.com/reference.html#map-option) can be passed directly:

```yaml
leaflet:
  mymap:
    center: [40.71, -74.00]
    zoom: 14
    zoomControl: false
    scrollWheelZoom: false
    maxZoom: 18
```

### Custom tiles

```yaml
leaflet:
  mymap:
    center: [35.68, 139.65]
    zoom: 11
    tile:
      url: "https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png"
      attribution: "&copy; OpenStreetMap &copy; CARTO"
      maxZoom: 20
```

## Parameters reference

### Extension-specific parameters

These are handled by the shortcode itself and are not passed to Leaflet:

| Parameter | Default | Description |
|---|---|---|
| `center` | derived from markers when available | Map center `[lat, lng]`; still required when no marker coordinates are available |
| `zoom` | `13` | Initial zoom level |
| `height` | `"400px"` | CSS height of the map container |
| `width` | `"100%"` | CSS width of the map container |
| `markers` | `[]` | Array of marker objects (see syntax below) |
| `markers-file` | — | Path to a delimited text file with `lat` and `lon` columns |
| `markers-sep` | auto | Field separator for `markers-file`; defaults to `,` for `.csv`, `\t` otherwise |
| `tile` | *(OSM)* | Tile layer sub-object (see syntax below) |

### Passthrough Leaflet options

The shortcode handles a small set of extension-specific parameters itself, then forwards supported Leaflet options into `L.map(...)` and `L.tileLayer(...)`.

Pass-through values are serialized from Quarto metadata or inline shortcode args, so scalar and boolean options are supported reliably. Structured values and callbacks from the Leaflet docs are not supported directly here. In practice, that means options such as `crs`, `layers`, `maxBounds`, `renderer`, tile `bounds`, function callbacks, or point/object forms of options like `tileSize` are outside the shortcode's current pass-through support.

#### Top-level pass-through to `L.map()`

Use these at the top level beside shortcode parameters such as `center`, `zoom`, `height`, `markers`, and `tile`.

| Option | Type | Description |
|---|---|---|
| `zoomControl` | boolean | Show or hide the default zoom control. |
| `attributionControl` | boolean | Show or hide the attribution control. |
| `closePopupOnClick` | boolean | Close the currently open popup when the map is clicked. |
| `minZoom` | number | Minimum zoom level allowed for the map. |
| `maxZoom` | number | Maximum zoom level allowed for the map. |
| `zoomSnap` | number | Force zoom levels to snap to this increment. |
| `zoomDelta` | number | Zoom step used by zoom controls and keyboard shortcuts. |
| `trackResize` | boolean | Automatically update the map when the browser window is resized. |
| `boxZoom` | boolean | Enable shift-drag box zoom interaction. |
| `doubleClickZoom` | boolean or string | Enable double-click zooming; Leaflet also accepts values such as `"center"`. |
| `dragging` | boolean | Enable mouse/touch dragging of the map. |
| `scrollWheelZoom` | boolean or string | Enable scroll-wheel zooming; Leaflet also accepts values such as `"center"`. |
| `inertia` | boolean | Enable inertial panning after drag release. |
| `inertiaDeceleration` | number | Deceleration rate used by inertial panning. |
| `inertiaMaxSpeed` | number | Maximum speed used by inertial panning. |
| `easeLinearity` | number | Control the rate curve of inertial panning. |
| `worldCopyJump` | boolean | Reposition overlays when panning across the international date line. |
| `maxBoundsViscosity` | number | Resistance when dragging outside `maxBounds` if you set bounds elsewhere in JS. |
| `keyboard` | boolean | Enable keyboard navigation. |
| `keyboardPanDelta` | number | Pixel distance to pan per keyboard step. |
| `wheelDebounceTime` | number | Debounce time for mouse-wheel zoom. |
| `wheelPxPerZoomLevel` | number | Mouse-wheel pixel delta required for one zoom level. |
| `touchZoom` | boolean or string | Enable touch pinch zoom; Leaflet also accepts values such as `"center"`. |
| `bounceAtZoomLimits` | boolean | Bounce pinch zoom when the map is already at min/max zoom. |
| `tapHold` | boolean | Simulate a `contextmenu` event on long press for mobile Safari. |
| `tapTolerance` | number | Maximum finger movement tolerated during tap interactions. |
| `zoomAnimation` | boolean | Enable animated zoom transitions. |
| `zoomAnimationThreshold` | number | Disable zoom animation when the zoom jump is larger than this value. |
| `fadeAnimation` | boolean | Fade tiles in and out during zoom. |
| `markerZoomAnimation` | boolean | Animate markers during zoom transitions. |
| `transform3DLimit` | number | Maximum CSS translation before Leaflet resets transforms. |
| `preferCanvas` | boolean | Prefer the Canvas renderer for vector layers. |

#### Nested pass-through to `L.tileLayer()`

Use these inside the shortcode-handled `tile:` sub-object.

| Option | Type | Description |
|---|---|---|
| `url` | string | Tile URL template, for example `https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png`. |
| `attribution` | string | Attribution HTML shown in the map attribution control. |
| `minZoom` | number | Minimum zoom level at which tiles are requested. |
| `maxZoom` | number | Maximum zoom level at which tiles are requested. |
| `minNativeZoom` | number | Minimum native zoom level available from the tile source. |
| `maxNativeZoom` | number | Maximum native zoom level available from the tile source. |
| `subdomains` | string | Subdomain set used for `{s}` in the tile URL template. |
| `errorTileUrl` | string | Fallback tile image to use when a tile fails to load. |
| `zoomOffset` | number | Offset between map zoom and tile zoom. |
| `tms` | boolean | Use TMS tile coordinates instead of the standard XYZ scheme. |
| `zoomReverse` | boolean | Reverse zoom numbering for the tile source. |
| `detectRetina` | boolean | Request higher-resolution tiles on retina displays. |
| `crossOrigin` | boolean or string | Set the tile image `crossorigin` attribute. |
| `referrerPolicy` | string or boolean | Set the tile image `referrerpolicy` attribute. |
| `opacity` | number | Tile layer opacity. |
| `zIndex` | number | Tile layer stacking order. |
| `className` | string | CSS class name added to tile elements. |
| `pane` | string | Map pane in which the tile layer is rendered. |
| `tileSize` | number | Tile size in pixels when supplied as a single numeric value. |
| `updateWhenIdle` | boolean | Delay tile updates until panning ends. |
| `updateWhenZooming` | boolean | Update tiles continuously while zooming. |
| `updateInterval` | number | Minimum delay between tile update batches. |
| `keepBuffer` | number | Number of extra tile rows/columns kept outside the viewport. |
| `noWrap` | boolean | Disable wrapping across the antimeridian. |

Any additional scalar tile template variables are also forwarded. For example, if your `tile.url` contains `{foo}`, then `tile.foo: "bar"` will be passed through to Leaflet.

### Marker sub-parameters

| Parameter | Default | Description |
|---|---|---|
| `lat` | *(required)* | Latitude of the marker |
| `lon` | *(required)* | Longitude of the marker |
| `popup` | — | HTML content shown in a popup |
| `tooltip` | — | Text shown as a tooltip |
| `icon` | *(default marker)* | Font Awesome class, or sub-object `{url, size, anchor}` for a custom image |
| `icon-color` | `"currentColor"` | Background colour for the circular badge behind icon-font markers; the glyph itself is rendered in white |
| `icon-size` | `16` | Base size in pixels for icon-font markers; scales both the white glyph and its circular badge |
| `icon-anchor` | *(auto)* | `[x, y]` pixel anchor override |

For full documentation, see the [usage guide](https://royfrancis.github.io/quarto-leaflet/usage.html).

---

2026 • Roy Francis
