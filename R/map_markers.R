# Labels and layer helpers used by the Leaflet maps.
facility_labels <- function(facilities, low_vaccine = FALSE) {
  facilities <- map_coverage_data(facilities, coverage_bands())
  vax_text <- map_coverage_label(facilities$full_vax_pct)
  known <- !is.na(facilities$full_vax_pct_num)
  if (low_vaccine) vax_text <- paste0(vax_text, ifelse(known, " (LOW VACCINE)", ""))
  contact <- if ("contact_info" %in% names(facilities)) facilities$contact_info else rep("", nrow(facilities))
  has_contact <- !is.na(contact) & nzchar(contact) & contact != "N/A"
  labels <- paste0(map_text(facilities$facility_name), " - ", map_text(vax_text),
                    ifelse(has_contact, paste0("<br>", map_text(contact)), ""))
  lapply(labels, htmltools::HTML)
}

add_facility_markers <- function(map, facilities,
                                 radius = 3, color = "gray", fill_opacity = 0.7,
                                 group = "School/Child Care Markers", low_vaccine = FALSE) {
  facilities <- map_points(facilities)
  if (is.null(facilities) || !nrow(facilities)) return(map)
  coords <- sf::st_coordinates(facilities)
  ids <- if ("facility_id" %in% names(facilities)) {
    paste0(group, ":", if ("facility_type" %in% names(facilities)) facilities$facility_type else "facility", ":", facilities$facility_id)
  } else NULL
  leaflet::addCircleMarkers(map, lng = coords[, 1], lat = coords[, 2],
    radius = radius, color = color, fillColor = color, fillOpacity = fill_opacity,
    layerId = ids, group = group, label = facility_labels(facilities, low_vaccine),
    labelOptions = leaflet::labelOptions(noHide = FALSE, textOnly = FALSE, direction = "auto"))
}

add_healthcare_markers <- function(map, healthcare) {
  healthcare <- map_points(healthcare)
  if (is.null(healthcare) || !nrow(healthcare)) return(map)
  coords <- sf::st_coordinates(healthcare)
  name <- if ("healthcare_name" %in% names(healthcare)) healthcare$healthcare_name else healthcare$name
  tooltips <- ifelse(!is.na(name) & nzchar(name), name, "Unnamed Healthcare Center")
  leaflet::addCircleMarkers(map, lng = coords[, 1], lat = coords[, 2], radius = 3,
    color = "green", fillColor = "green", fillOpacity = 0.7,
    group = "Healthcare Centers", label = tooltips)
}
