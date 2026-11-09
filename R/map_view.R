# ============================================================
# MAP VIEW
# ============================================================
# Starting view and panning limits shared by the dashboard's maps
# (county/district map, statewide cases map, proximity map, and the
# map in the dashboard report).
#
# A view is either
#   list(center = c(lng, lat), zoom = <number>, max_bounds = c(lng1, lat1, lng2, lat2))
#     from the settings file's `map` entry (checked and put in lng, lat
#     order by check_settings() in dashboard_settings.R), or
#   list(bounds = c(lng1, lat1, lng2, lat2), max_bounds = ...)
#     from map_view_from_counties(), which fits the county boundaries.
# max_bounds is optional in both.
# ============================================================

# Input:  counties (sf) from the standard app data
# Output: a view that fits the counties, with panning limited to an
#         area one state-width/height beyond them on each side
map_view_from_counties <- function(counties) {
  if (is.null(counties) || nrow(counties) == 0) {
    stop("Map boundaries must contain at least one feature.", call. = FALSE)
  }
  counties <- sf::st_transform(sf::st_as_sf(counties), 4326)
  bb <- as.numeric(sf::st_bbox(counties))  # xmin, ymin, xmax, ymax
  if (any(!is.finite(bb))) stop("Map boundaries have no usable geometry.", call. = FALSE)
  # Alaska's western Aleutian islands have positive longitudes. Shifts longitudes
  # past the date line when that makes the map extent smaller.
  shifted <- sf::st_shift_longitude(sf::st_geometry(counties))
  shifted_bb <- as.numeric(sf::st_bbox(shifted))
  wrap <- bb[3] - bb[1] > 180 && shifted_bb[3] - shifted_bb[1] < bb[3] - bb[1]
  if (wrap) bb[c(1, 3)] <- shifted_bb[c(1, 3)]
  width <- bb[3] - bb[1]
  height <- bb[4] - bb[2]
  view <- list(
    bounds = bb,
    max_bounds = c(bb[1] - width, max(-85.05112878, bb[2] - height),
                   bb[3] + width, min(85.05112878, bb[4] + height))
  )
  if (wrap) view$longitude_center <- mean(bb[c(1, 3)])
  view
}

# Input:  settings map entry (or NULL) and the counties
# Output: the view to use: the settings' center and zoom if given, else
#         one that fits the counties; the settings' max_bounds, if given,
#         replace the panning limits
dashboard_map_view <- function(map_settings, counties) {
  fitted <- map_view_from_counties(counties)
  view <- if (!is.null(map_settings$center)) map_settings else fitted
  if (!is.null(fitted$longitude_center)) {
    view$longitude_center <- fitted$longitude_center
    if (!is.null(view$center)) view$center[1] <- map_display_longitude(view$center[1], view)
  }
  if (!is.null(map_settings$max_bounds)) view$max_bounds <- map_settings$max_bounds
  if (!is.null(view$longitude_center) && !is.null(map_settings$max_bounds)) {
    # A west/east limit may cross the date line. Shifts it to match the county shapes.
    if (view$max_bounds[1] > view$max_bounds[3]) view$max_bounds[3] <- view$max_bounds[3] + 360
    offset <- 360 * round((view$longitude_center - mean(view$max_bounds[c(1, 3)])) / 360)
    view$max_bounds[c(1, 3)] <- view$max_bounds[c(1, 3)] + offset
  }
  # Default basemap, or the `map` setting's basemap (NULL: no tiles).
  view["basemap"] <- list(if (is.null(map_settings)) "Esri.WorldTopoMap" else map_settings$basemap)
  view
}

# Longitude helpers for drawing: shift map data to the world copy in the view.
map_display_longitude <- function(longitude, view) {
  if (is.null(view$longitude_center)) return(longitude)
  longitude + 360 * round((view$longitude_center - longitude) / 360)
}

map_geographic_longitude <- function(longitude) (longitude + 180) %% 360 - 180

map_display_data <- function(data, view) {
  if (is.null(data) || is.null(view$longitude_center)) return(data)
  move <- function(geometry) {
    if (is.matrix(geometry)) {
      geometry[, 1] <- map_display_longitude(geometry[, 1], view)
    } else if (is.numeric(geometry)) {
      if (length(geometry)) geometry[1] <- map_display_longitude(geometry[1], view)
    } else if (is.list(geometry)) {
      geometry[] <- lapply(geometry, move)
    }
    geometry
  }
  sf::st_geometry(data) <- sf::st_sfc(lapply(sf::st_geometry(data), move), crs = sf::st_crs(data))
  if ("final_lon" %in% names(data)) data$final_lon <- map_display_longitude(data$final_lon, view)
  data
}

# Adds the view's basemap tiles, if any.
add_map_basemap <- function(map, view = NULL) {
  provider <- if ("basemap" %in% names(view)) view$basemap else "Esri.WorldTopoMap"
  if (is.null(provider)) map else leaflet::addProviderTiles(map, provider)
}

# Input:  a leaflet map, a view (see top of file), and whether to limit
#         panning to the view's max_bounds
# Output: the map with its starting view (and panning limits) set
apply_map_view <- function(map, view, limit_panning = TRUE) {
  # Lowers the minimum zoom if needed to fit the region or allow the settings' zoom.
  if (!is.null(view$bounds)) {
    bounds <- as.numeric(view$bounds)
    mercator_y <- function(latitude) log(tan(pi / 4 + pmax(-85.05112878, pmin(85.05112878, latitude)) * pi / 360))
    span_y <- mercator_y(bounds[4]) - mercator_y(bounds[2])
    fit_zoom <- floor(min(log2(360 * 400 / (256 * (bounds[3] - bounds[1]))),
                          log2(2 * pi * 300 / (256 * span_y))))
    map$x$options$minZoom <- min(map$x$options$minZoom, max(0, fit_zoom))
  } else if (!is.null(view$zoom)) {
    map$x$options$minZoom <- min(map$x$options$minZoom, view$zoom)
  }
  if (!is.null(view$center)) {
    center <- as.numeric(view$center)
    map <- leaflet::setView(map, lng = center[[1]], lat = center[[2]], zoom = as.numeric(view$zoom))
  } else if (!is.null(view$bounds)) {
    b <- as.numeric(view$bounds)
    map <- leaflet::fitBounds(map, b[1], b[2], b[3], b[4])
  }
  if (limit_panning && !is.null(view$max_bounds)) {
    m <- as.numeric(view$max_bounds)
    map <- leaflet::setMaxBounds(map, m[1], m[2], m[3], m[4])
  }
  map
}

# Regional view for the proximity map, with pan limits from the counties when
# the settings give none. region_bounds holds the county extent.
proximity_map_view <- function(view, counties, settings = NULL) {
  fitted <- map_view_from_counties(counties)
  if (is.null(view)) view <- dashboard_map_view(map_settings(settings)$map, counties)
  if (is.null(view$max_bounds)) view$max_bounds <- fitted$max_bounds
  view$region_bounds <- fitted$bounds
  view
}

# Sets the proximity map's minimum zoom in the browser, from the map's actual
# size on screen.
limit_proximity_zoom <- function(map, view) {
  htmlwidgets::onRender(map, "function(el, x, data) {
    var map = this;
    var b = data.bounds;
    var region = L.latLngBounds([b[1], b[0]], [b[3], b[2]]);
    function updateMinimum(event) {
      var size = map.getSize();
      if (!size.x || !size.y) return;
      var previous = map.getMinZoom();
      var overview = map.getZoom() <= previous;
      // getBoundsZoom respects the existing minimum; temporarily remove
      // that floor so shrinking the viewport can still fit the full region.
      map.options.minZoom = 0;
      var minimum = Math.max(0, map.getBoundsZoom(region));
      map.options.minZoom = previous;
      // Raising setMinZoom alone starts a zoom animation. Finish the
      // adjustment immediately so a search proxy can navigate straight away.
      if (map._loaded && map.getZoom() < minimum) {
        map.setZoom(minimum, {animate: false});
      }
      map.setMinZoom(minimum);
      if (event && overview && data.fitted) {
        map.fitBounds(region, {animate: false});
      }
    }
    map.whenReady(function() { updateMinimum(); });
    map.on('resize', updateMinimum);
  }", data = list(bounds = as.numeric(view$region_bounds), fitted = is.null(view$center)))
}

# Input:  counties (sf)
# Output: "lng1,lat1,lng2,lat2" around the counties (10% margin), the
#         area address searches are limited to
search_area <- function(counties) {
  bb <- as.numeric(sf::st_bbox(sf::st_transform(counties, 4326)))
  dx <- 0.1 * (bb[3] - bb[1])
  dy <- 0.1 * (bb[4] - bb[2])
  # Map limits in longitude and latitude.
  paste(round(c(max(-180, bb[1] - dx), max(-90, bb[2] - dy),
                min(180, bb[3] + dx), min(90, bb[4] + dy)), 4), collapse = ",")
}
