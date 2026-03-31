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
        icon: "bi-geo-alt-fill"
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
center automatically. A single marker becomes the center; multiple markers use
their centroid. If `zoom` is omitted, it defaults to `13`.

### Markers with icons

```yaml
markers:
  - lat: 48.86
    lon: 2.35
    popup: "Paris"
    icon: "bi-geo-alt-fill"    # Bootstrap Icon
    icon-color: "tomato"
    icon-size: 28
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

Any option accepted by [`L.map()`](https://leafletjs.com/reference.html#map-option) can be added at the top level and will be forwarded verbatim. Any option accepted by [`L.tileLayer()`](https://leafletjs.com/reference.html#tilelayer-option) can be nested inside the `tile` sub-object.

### Marker sub-parameters

| Parameter | Default | Description |
|---|---|---|
| `lat` | *(required)* | Latitude of the marker |
| `lon` | *(required)* | Longitude of the marker |
| `popup` | — | HTML content shown in a popup |
| `tooltip` | — | Text shown as a tooltip |
| `icon` | *(default marker)* | Icon font class (Bootstrap Icons / FontAwesome), or sub-object `{url, size, anchor}` for a custom image |
| `icon-color` | `"currentColor"` | CSS colour for icon-font markers |
| `icon-size` | `24` | Size in pixels for icon-font markers |
| `icon-anchor` | *(auto)* | `[x, y]` pixel anchor override |

For full documentation, see the [usage guide](https://royfrancis.github.io/quarto-leaflet/usage.html).

---

2026 • Roy Francis
