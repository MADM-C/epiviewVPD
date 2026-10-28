# Core function to analyze proximity and identify low-vaccine facilities
# This function is called when user clicks map, selects a facility, or searches an address
# Parameters:
#   lat: latitude of search center
#   lng: longitude of search center
#   popup_title: descriptive title for the search location marker
#   combined_facilities: reactive expression returning combined school/daycare data
#   healthcare_centers: reactive expression returning healthcare center data
#   radius_km: reactive expression returning search radius in kilometers
#   low_vaccine_threshold: reactive expression returning vaccine threshold percentage
#   values: reactiveValues object; clicked_point and low_vaccine_facilities_data are written to it
#           (low_vaccine_facilities_data includes a distance_mi column used by proximityTableServer)
#   session: Shiny session object
# Note: Only schools and daycares are analyzed (religious centers excluded)
# Depends on map_markers.R being sourced
analyze_proximity <- function(lat, lng, popup_title,
                              combined_facilities, healthcare_centers,
                              radius_km, low_vaccine_threshold,
                              values, session) {
  facilities <- combined_facilities()
  if (is.null(facilities) || nrow(facilities) == 0) {
    return()
  }
  
  values$clicked_point <- list(lat = lat, lng = lng)
  
  if ("geometry" %in% names(facilities)) {
    coords <- sf::st_coordinates(facilities$geometry)
    if (nrow(coords) > 0) {
      lat1_rad <- lat * pi / 180
      lng1_rad <- lng * pi / 180
      lat2_rad <- coords[, 2] * pi / 180
      lng2_rad <- coords[, 1] * pi / 180
      dlat <- lat2_rad - lat1_rad
      dlng <- lng2_rad - lng1_rad
      a <- sin(dlat / 2)^2 + cos(lat1_rad) * cos(lat2_rad) * sin(dlng / 2)^2
      c <- 2 * atan2(sqrt(a), sqrt(1 - a))
      distances_km <- 6371 * c
      within_radius <- distances_km <= radius_km()
      nearby_facilities <- facilities[within_radius, ]
      nearby_facilities$distance_mi <- round(distances_km[within_radius] * 0.621371, 1)
    } else {
      nearby_facilities <- facilities[0, ]
    }
  } else {
    nearby_facilities <- facilities
  }
  
  if (nrow(nearby_facilities) > 0 && "full_vax_pct" %in% names(nearby_facilities)) {
    vax_numeric <- as.numeric(gsub("[^0-9.]", "", nearby_facilities$full_vax_pct))
    low_vaccine_facilities <- nearby_facilities[
      !is.na(vax_numeric) & vax_numeric < low_vaccine_threshold(),
    ]
  } else {
    low_vaccine_facilities <- nearby_facilities[0, ]
  }
  
  values$low_vaccine_facilities_data <- low_vaccine_facilities
  
  # Specific settings for proximity circle zoom in
  zoom_level <- dplyr::case_when(
    radius_km() <= 0.1 ~ 19,
    radius_km() <= 0.2 ~ 17,
    radius_km() <= 0.5 ~ 16,
    radius_km() <= 1 ~ 15,
    radius_km() <= 2 ~ 14,
    radius_km() <= 5 ~ 13,
    radius_km() <= 10 ~ 12,
    TRUE ~ 10
  )
  
  # Clear only specific elements
  leafletProxy("proximity_map", session) %>%
    removeMarker("search_center") %>%
    removeShape("search_radius") %>%
    clearGroup("highlighted_facilities") %>%
    setView(lng = lng, lat = lat, zoom = zoom_level) %>%
    addMarkers(
      lng = lng, lat = lat, layerId = "search_center",
      popup = paste(popup_title, "<br>Low-vaccine facilities:", nrow(low_vaccine_facilities))
    ) %>%
    addCircles(
      lng = lng, lat = lat, radius = radius_km() * 1000,
      layerId = "search_radius", color = "red", fillOpacity = 0.1
    )
  
  # Re-add all facility markers with tooltips to ensure they persist
  leafletProxy("proximity_map", session) %>%
    clearGroup("School/Child Care Markers") %>%
    add_facility_markers(combined_facilities())
  
  # Re-add healthcare centers with tooltips to ensure they persist [NEW]
  leafletProxy("proximity_map", session) %>%
    clearGroup("Healthcare Centers") %>%
    add_healthcare_markers(healthcare_centers())
  
  # Add highlighted low-vaccine facilities on top
  leafletProxy("proximity_map", session) %>%
    add_facility_markers(
      low_vaccine_facilities,
      radius = 5, color = "red", fill_opacity = 0.9,
      group = "highlighted_facilities",
      low_vaccine = TRUE
    )
}