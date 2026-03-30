# leaflet ![build](https://github.com/royfrancis/quarto-leaflet/workflows/deploy/badge.svg) ![status: experimental](https://github.com/GIScience/badges/raw/master/status/experimental.svg)

A Quarto shortcode extension to embed interactive [Leaflet](https://leafletjs.com/) maps in **HTML** and **revealjs** formats.

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
      - position: [59.33, 18.07]
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

### Markers with icons

```yaml
markers:
  - position: [48.86, 2.35]
    popup: "Paris"
    icon: "bi-geo-alt-fill"    # Bootstrap Icon
    icon-color: "tomato"
    icon-size: 28
  - position: [48.86, 2.29]
    popup: "Eiffel Tower"
    icon: "fa-solid fa-tower-broadcast"  # FontAwesome
  - position: [48.85, 2.35]
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
    markers-separator: "|"
```

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

### Extension parameters

| Parameter | Default | Description |
|---|---|---|
| `height` | `"400px"` | CSS height of the map container |
| `width` | `"100%"` | CSS width of the map container |
| `tile` | *(OSM default)* | Tile layer configuration object |
| `tile.url` | OSM URL | Tile URL template |
| `tile.attribution` | OSM attribution | Tile attribution HTML |
| `markers` | `[]` | Array of marker objects |
| `markers-file` | — | Path to marker rows in a delimited text file |
| `markers-separator` | auto | Separator for `markers-file` (for example `,`, `\t`, `|`) |

### Passthrough parameters

All [Leaflet Map options](https://leafletjs.com/reference.html#map-option) are supported as passthrough. Common ones include:

| Parameter | Default | Description |
|---|---|---|
| `center` | *(required)* | Map center `[lat, lng]` |
| `zoom` | `13` | Initial zoom level |
| `minZoom` | — | Minimum zoom level |
| `maxZoom` | — | Maximum zoom level |
| `zoomControl` | `true` | Show zoom +/- controls |
| `dragging` | `true` | Allow map dragging |
| `scrollWheelZoom` | `true` | Zoom with scroll wheel |
| `doubleClickZoom` | `true` | Zoom on double click |
| `boxZoom` | `true` | Zoom to area by shift+drag |
| `maxBounds` | — | Restrict panning to bounds |

### Marker parameters

| Parameter | Default | Description |
|---|---|---|
| `position` | *(required)* | `[lat, lng]` |
| `popup` | — | HTML popup content |
| `tooltip` | — | Tooltip text |
| `icon` | *(default marker)* | Icon name or config object |
| `icon-color` | `"currentColor"` | CSS color for icon font |
| `icon-size` | `24` | Icon size in pixels |
| `icon-anchor` | *(auto)* | `[x, y]` anchor override |

### Tile layer parameters

Any [TileLayer option](https://leafletjs.com/reference.html#tilelayer-option) can be included inside the `tile` object:

| Parameter | Default | Description |
|---|---|---|
| `url` | OSM | URL template |
| `attribution` | OSM | Attribution HTML |
| `maxZoom` | `18` | Max zoom |
| `subdomains` | `"abc"` | URL subdomains |
| `opacity` | `1.0` | Layer opacity |

For full documentation, see the [usage guide](https://royfrancis.github.io/quarto-leaflet/usage.html).

---

2026 • Roy Francis
