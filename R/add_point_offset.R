# Moves schools that share a location slightly apart on the map.
add_micro_offset <- function(school_data) {
  if (is.null(school_data) || nrow(school_data) == 0) return(school_data)
  school_data %>%
    group_by(geometry) %>%
    mutate(
      lon = sf::st_coordinates(geometry)[, 1],
      lat = sf::st_coordinates(geometry)[, 2],
      n_at_location = n(),
      offset_distance = ifelse(n_at_location > 1, 0.0005, 0), # ~50 meters
      # Spread schools at the same location in a circle around it
      angle = (row_number() - 1) * (2 * pi / n_at_location),
      lon_offset = lon + offset_distance * cos(angle),
      lat_offset = lat + offset_distance * sin(angle),
      final_lon = ifelse(n_at_location == 1, lon, lon_offset),
      final_lat = ifelse(n_at_location == 1, lat, lat_offset)
    ) %>%
    ungroup()
}
