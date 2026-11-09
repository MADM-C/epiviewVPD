# Layer IDs used by the maps and their click handlers.
map_layer_ids <- function(map_data, boundary) {
  if (boundary == "county") tolower(map_data$county_name) else map_data$district_id
}

# County or district coverage map; calls build_coverage_map().
county_district_map_dashboard <- function(map_data, bands, boundary = c("county", "district"),
                                          map_view = map_view_from_counties(map_data)) {
  build_coverage_map(map_data, boundary = match.arg(boundary), bands = bands, map_view = map_view)
}

# Highlights the selected county or district on the dashboard map.
highlight_selected <- function(map_data, selected_id, boundary = c("county", "district")) {
  add_coverage_highlight(leaflet::leafletProxy("county_map"), map_data, selected_id, match.arg(boundary))
}
