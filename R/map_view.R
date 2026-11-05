# ============================================================
# MAP VIEW
# ============================================================
# Starting view and panning limits shared by the dashboard's maps
# (county/district map, statewide cases map, proximity map, and the
# map in the dashboard report).
#
# A view is either
#   list(center = c(lng, lat), zoom = <number>, max_bounds = c(lng1, lat1, lng2, lat2))
#     from the settings file's `map` entry, or
#   list(bounds = c(lng1, lat1, lng2, lat2), max_bounds = ...)
#     from map_view_from_counties(), which fits the county boundaries.
# max_bounds is optional in both.
# ============================================================

# Input:  counties (sf) from the standard app data
# Output: a view that fits the counties, with panning limited to an
#         area one state-width/height beyond them on each side
map_view_from_counties <- function(counties) {
  bb <- as.numeric(sf::st_bbox(counties))  # xmin, ymin, xmax, ymax
  width <- bb[3] - bb[1]
  height <- bb[4] - bb[2]
  list(
    bounds = bb,
    max_bounds = c(bb[1] - width, bb[2] - height, bb[3] + width, bb[4] + height)
  )
}

# Input:  settings map entry (or NULL) and the counties
# Output: the view to use: the settings' one if given, else one that
#         fits the counties
dashboard_map_view <- function(map_settings, counties) {
  if (is.null(map_settings)) map_view_from_counties(counties) else map_settings
}

# Input:  a leaflet map, a view (see top of file), and whether to limit
#         panning to the view's max_bounds
# Output: the map with its starting view (and panning limits) set
apply_map_view <- function(map, view, limit_panning = TRUE) {
  if (!is.null(view$center)) {
    map <- leaflet::setView(map, lng = view$center[[1]], lat = view$center[[2]], zoom = view$zoom)
  } else {
    b <- view$bounds
    map <- leaflet::fitBounds(map, b[1], b[2], b[3], b[4])
  }
  if (limit_panning && !is.null(view$max_bounds)) {
    m <- view$max_bounds
    map <- leaflet::setMaxBounds(map, m[1], m[2], m[3], m[4])
  }
  map
}

# Input:  counties (sf)
# Output: "lng1,lat1,lng2,lat2" around the counties (10% margin), the
#         area address searches are limited to
search_area <- function(counties) {
  bb <- as.numeric(sf::st_bbox(counties))
  dx <- 0.1 * (bb[3] - bb[1])
  dy <- 0.1 * (bb[4] - bb[2])
  paste(round(c(bb[1] - dx, bb[2] - dy, bb[3] + dx, bb[4] + dy), 4), collapse = ",")
}
