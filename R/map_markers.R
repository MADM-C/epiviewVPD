# Builds HTML hover labels for school/child care markers
# Parameters:
#   facilities: facility data with facility_name, full_vax_pct, partial_vax_pct, contact_info
#   low_vaccine: if TRUE, appends " (LOW VACCINE)" for facilities that report data
facility_labels <- function(facilities, low_vaccine = FALSE) {
  # designate non-reporting schools as "Not Available"
  not_available <- facilities$full_vax_pct == "0" & facilities$partial_vax_pct == "0"
  vax_text <- ifelse(not_available, "Not Available", facilities$full_vax_pct)
  
  if (low_vaccine) {
    # only display "low vaccine" label for schools w/data, still highlight the not available data, but don't note as low vaccine
    vax_text <- paste0(vax_text, ifelse(not_available, "", " (LOW VACCINE)"))
  }
  
  has_contact <- !is.na(facilities$contact_info) &
    facilities$contact_info != "" &
    facilities$contact_info != "N/A"
  
  label_text <- paste0(
    facilities$facility_name, " - ", vax_text,
    ifelse(has_contact, paste0("<br>", facilities$contact_info), "")
  )
  
  lapply(label_text, htmltools::HTML)
}

# Adds school/child care circle markers to a leaflet map or leafletProxy
# Returns the map unchanged if there is nothing to draw
add_facility_markers <- function(map, facilities,
                                 radius = 3, color = "gray", fill_opacity = 0.7,
                                 group = "School/Child Care Markers",
                                 low_vaccine = FALSE) {
  if (is.null(facilities) || nrow(facilities) == 0 || !"geometry" %in% names(facilities)) {
    return(map)
  }
  coords <- sf::st_coordinates(facilities$geometry)
  if (nrow(coords) == 0) {
    return(map)
  }
  
  map %>%
    addCircleMarkers(
      lng = coords[, 1], lat = coords[, 2],
      radius = radius, color = color, fillColor = color, fillOpacity = fill_opacity,
      group = group,
      label = facility_labels(facilities, low_vaccine = low_vaccine),
      labelOptions = labelOptions(noHide = FALSE, textOnly = FALSE, direction = "auto")
    )
}

# Adds healthcare center circle markers to a leaflet map or leafletProxy
# Returns the map unchanged if there is nothing to draw
add_healthcare_markers <- function(map, healthcare) {
  if (is.null(healthcare) || nrow(healthcare) == 0 || !"geometry" %in% names(healthcare)) {
    return(map)
  }
  coords <- sf::st_coordinates(healthcare$geometry)
  if (nrow(coords) == 0) {
    return(map)
  }
  
  tooltips <- ifelse(!is.na(healthcare$healthcare_name), healthcare$healthcare_name, "Unnamed Healthcare Center")
  map %>%
    addCircleMarkers(
      lng = coords[, 1], lat = coords[, 2],
      radius = 3, color = "green", fillColor = "green", fillOpacity = 0.7,
      group = "Healthcare Centers",
      label = tooltips
    )
}