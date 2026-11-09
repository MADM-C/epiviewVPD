# Map pieces used by the facility map and its server.
base_submap <- function(boundary_shape, map_view = map_view_from_counties(boundary_shape)) {
  map <- leaflet::leaflet(options = leaflet::leafletOptions(minZoom = 6, maxZoom = 18))
  map <- add_map_basemap(apply_map_view(map, map_view), map_view)
  leaflet::addPolygons(map, data = boundary_shape, fillOpacity = 0.2, color = "black", weight = 2)
}

add_point_layers <- function(map, point_type, school_data = NULL, childcare_data = NULL,
                             bands = coverage_bands()) {
  combined <- point_type == "Schools and Child Cares"
  school_data <- map_coverage_data(school_data, bands)
  childcare_data <- map_coverage_data(childcare_data, bands)
  if (point_type %in% c("Schools", "Schools and Child Cares") && !is.null(school_data) && nrow(school_data)) {
    if (!all(c("final_lon", "final_lat", "n_at_location") %in% names(school_data))) school_data <- add_micro_offset(school_data)
    school <- school_data
    for (col in c("school_type", "grade_range", "county_name")) if (!col %in% names(school)) school[[col]] <- NA_character_
    if (!"school_id" %in% names(school)) stop("schools is missing school_id.", call. = FALSE)
    text <- function(x) ifelse(is.na(x) | !nzchar(as.character(x)), "Data Not Available", map_text(x))
    coverage <- map_text(map_coverage_label(school$full_vax_pct))
    popup <- paste0("<b>", map_text(school$school_name), "</b><br>", text(school$county_name), " County<br>",
      if (combined) "Type: School<br>" else paste0("School Type: ", text(school$school_type), "<br>"),
      "Grades: ", text(school$grade_range), "<br>MMR Coverage: ", coverage,
      ifelse(school$n_at_location > 1, paste0("<br><i>", school$n_at_location, " schools at this location</i>"), ""))
    label <- paste0(school$school_name, if (combined) " (School)" else "", ": ", map_coverage_label(school$full_vax_pct))
    map <- leaflet::addCircleMarkers(map, lng = school$final_lon, lat = school$final_lat,
      radius = ifelse(school$n_at_location > 1, if (combined) 7 else 6, if (combined) 6 else 5),
      stroke = TRUE, weight = ifelse(school$n_at_location > 1, 2, 1), color = "black",
      fillColor = coverage_band_color(school$full_vax_pct_num, bands), fillOpacity = 0.9,
      layerId = paste0("school:", school$school_id), group = if (combined) "Schools" else NULL,
      popup = popup, label = label,
      labelOptions = leaflet::labelOptions(direction = "top", textsize = "13px", opacity = 0.85))
  }
  if (point_type %in% c("Child Cares", "Schools and Child Cares") && !is.null(childcare_data) && nrow(childcare_data)) {
    childcare <- childcare_data
    for (col in c("county_name", "enroll_eligible", "full_vax")) if (!col %in% names(childcare)) childcare[[col]] <- NA
    if (!"facility_id" %in% names(childcare)) stop("facilities is missing facility_id.", call. = FALSE)
    coords <- sf::st_coordinates(childcare)
    count <- function(x) ifelse(is.na(x), "Data Not Available", as.character(x))
    popup <- paste0(map_text(childcare$facility_name), "<br>", map_text(childcare$county_name), " County<br>",
      if (combined) "Type: Daycare<br>" else "", "Eligible: ", count(childcare$enroll_eligible),
      "<br>Vaccinated", if (!combined) " (1 dose)" else "", ": ", count(childcare$full_vax),
      "<br>Coverage: ", map_text(map_coverage_label(childcare$full_vax_pct)))
    map <- leaflet::addCircleMarkers(map, lng = coords[, 1], lat = coords[, 2],
      radius = if (combined) 4 else 5, stroke = TRUE, weight = 1, color = "black",
      fillColor = coverage_band_color(childcare$full_vax_pct_num, bands), fillOpacity = 0.9,
      layerId = paste0("facility:", childcare$facility_id), group = if (combined) "Child Cares" else NULL,
      popup = popup,
      label = paste0(childcare$facility_name, if (combined) " (Daycare)" else "", ": ", map_coverage_label(childcare$full_vax_pct)),
      labelOptions = leaflet::labelOptions(direction = "top", textsize = "13px", opacity = 0.85))
  }
  map
}
# ==== Create school district overlay (filtered to the selected counties) ====

county_district_overlay <- function(map, county_districts = NULL) {
  map |>
    addPolygons(
      data = county_districts,
      fill = FALSE,
      color = "#2c7bb6",
      weight = 1.5,
      opacity = 0.8,
      group = "School Districts",
      label = ~district_name,
      labelOptions = labelOptions(direction = "auto", textsize = "12px", opacity = 0.85)
    )
}

# === Layer control (always shown; groups vary by point_type) ===

control_overlay_groups <- function(point_type,
                                   boundary_type,
                                   map) {
  is_district_mode <- !is.null(boundary_type) && boundary_type == "district"

  overlay_groups <-
    if (point_type == "Schools and Child Cares") {
      if (is_district_mode) {
        c("Schools", "Child Cares")
      } else {
        c("Schools", "Child Cares", "School Districts")
      }
    } else { # if "Schools and Child Cares" not selected
      if (is_district_mode) {
        character(0)
      } else {
        "School Districts"
      }
    }

  if (length(overlay_groups) > 0) {
    map <- map |>
      addLayersControl(
        overlayGroups = overlay_groups,
        options = layersControlOptions(collapsed = FALSE)
      )
    if (!is_district_mode) {
      map <- map |> hideGroup("School Districts")
    }
  }
  return(map)
}

# ==== Extra legend for schools vs. childcares on submap ====

legend_html <- HTML("
    <div class='legend-box'>
      <b>Location Type</b><br>
      <svg height='14' width='14'><circle cx='7' cy='7' r='6' stroke='black' stroke-width='1' fill='black' /></svg> School<br>
      <svg height='14' width='14'><circle cx='7' cy='7' r='4' stroke='black' stroke-width='1' fill='black' /></svg> Daycare
    </div>
  ")

# ==== Vaccine coverage for boundary to display in submap title ====

submap_title_vax <- function(boundary_type,
                             selected_district,
                             district_data = NULL,
                             selected_county,
                             county_data = NULL,
                             has_childcares = TRUE) {
  is_district_mode <- !is.null(boundary_type) && boundary_type == "district"

  if (is_district_mode) {
    boundary_rate <- district_data |>
      dplyr::filter(district_id == selected_district) |>
      dplyr::pull(full_vax_pct) |>
      dplyr::first()
  } else {
    boundary_rate <- county_data |>
      dplyr::filter(county_name == selected_county) |>
      dplyr::pull(full_vax_pct) |>
      dplyr::first()
  }

  tagList(
    tags$h4(if (has_childcares) "MMR Coverage for Schools and Child Cares" else "MMR Coverage for Schools",
            class = "submap-title"),
    if (!is.na(boundary_rate)) {
      tags$div(
        paste0(
          ifelse(boundary_type == "county", "Countywide ", "District Wide "), "MMR Coverage: ",
          format_vax_pct(boundary_rate)
        )
      )
    } else {
      tags$div(
        paste0(ifelse(boundary_type == "county", "Countywide ", "District Wide "), "MMR Coverage: Not Available")
      )
    }
  )
}
