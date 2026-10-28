# Function to add micro-offset to duplicate locations
add_micro_offset <- function(school_data) {
  school_data %>%
    group_by(geometry) %>%
    mutate(
      # Get original coordinates
      lon = sf::st_coordinates(geometry)[, 1],
      lat = sf::st_coordinates(geometry)[, 2],
      # Count schools at this location
      n_at_location = n(),
      # Create offset pattern for duplicates
      offset_distance = ifelse(n_at_location > 1, 0.0005, 0), # ~50 meters
      # Create circular pattern around original point
      angle = (row_number() - 1) * (2 * pi / n_at_location),
      # Apply offset
      lon_offset = lon + offset_distance * cos(angle),
      lat_offset = lat + offset_distance * sin(angle),
      # Keep original coordinates for single schools
      final_lon = ifelse(n_at_location == 1, lon, lon_offset),
      final_lat = ifelse(n_at_location == 1, lat, lat_offset)
    ) %>%
    ungroup()
}
