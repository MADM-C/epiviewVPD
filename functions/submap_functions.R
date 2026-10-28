# ====================================================
# FUNCTIONS TO EXECUTE SUB MAP MODULE
# ====================================================

# ==== Helper function to decide on fill color for locations on submap ====
get_fill_color <- function(vax_pct) {
  vax_num <- suppressWarnings(as.numeric(vax_pct))

  dplyr::case_when(
    is.na(vax_pct) ~ "gray", # Missing/unknown
    grepl("^>", vax_pct) ~ "darkgreen", # Blurred ('>95%')
    vax_num < 85 ~ "red", # <85%
    vax_num < 90 ~ "orange", # 85–89%
    vax_num < 95 ~ "gold", # 90–94%
    vax_num >= 95 ~ "darkgreen", # ≥95%
    TRUE ~ "gray" # Fallback
  )
}

# ==== Create map background for the submap ====

base_submap <- function(boundary_shape) {
  leaflet(options = leafletOptions(minZoom = 6, maxZoom = 18)) |>
    addProviderTiles("Esri.WorldTopoMap") |>
    addPolygons(data = boundary_shape, fillOpacity = 0.2, color = "black", weight = 2)
}

# ==== Add Markers for Schools & Childcares to Leaflet Map ====

add_point_layers <- function(map, point_type, school_data = NULL, childcare_data = NULL) {
  show_schools <- point_type %in% c("Schools", "Schools and Child Cares")
  show_childcares <- point_type %in% c("Child Cares", "Schools and Child Cares")
  is_combined <- point_type == "Schools and Child Cares"

  # --- Add Schools Layer ---
  if (show_schools && !is.null(school_data) && nrow(school_data) > 0) {
    base_radius <- if (is_combined) 6 else 5

    map <- map |>
      addCircleMarkers(
        data = school_data,
        lng = ~final_lon,
        lat = ~final_lat,
        radius = ~ ifelse(n_at_location > 1, base_radius + 1, base_radius),
        stroke = TRUE,
        weight = ~ ifelse(n_at_location > 1, 2, 1),
        color = "black",
        fillColor = ~ get_fill_color(full_vax_pct),
        fillOpacity = 0.9,
        layerId = ~mde_school_id,
        group = if (is_combined) "Schools" else NULL,
        popup = ~ paste0(
          "<b>", school_name, "</b><br>", COUNTYNAME, " County<br>",
          if (is_combined) "Type: School<br>" else paste0("School Type: ", sch_type, "<br>"),
          "Grades: ", GRADERANGE, "<br>",
          "MMR Coverage: ", paste0(if_else(school_data$full_vax_pct == 0 & school_data$partial_vax_pct == 0, "Data unavailable",
                                           format_vax_pct(school_data$full_vax_pct))),
          ifelse(
            n_at_location > 1,
            paste0("<br><i>", if (!is_combined) "Warning: " else "", n_at_location, " schools at this location</i>"),
            ""
          )
        ),
        label = ~ paste0(
          school_name,
          if (is_combined) " (School)" else "",
          ": ", paste0(if_else(school_data$full_vax_pct == 0 & school_data$partial_vax_pct == 0, "Data unavailable",
                                           format_vax_pct(school_data$full_vax_pct)))
        ),
        labelOptions = labelOptions(direction = "top", textsize = "13px", opacity = 0.85)
      )
  }

  # --- Add Daycares Layer ---
  if (show_childcares && !is.null(childcare_data) && nrow(childcare_data) > 0) {
    childcare_radius <- if (is_combined) 4 else 5

    map <- map |>
      addCircleMarkers(
        data = childcare_data,
        radius = childcare_radius,
        stroke = TRUE,
        weight = 1,
        color = "black",
        fillColor = ~ get_fill_color(full_vax_pct),
        fillOpacity = 0.9,
        layerId = ~idsch,
        group = if (is_combined) "Child Cares" else NULL,
        popup = ~ paste0(
          daycare_name, "<br>", COUNTYNAME, " County<br>",
          if (is_combined) "Type: Daycare<br>" else "",
          "Eligible: ", enroll_mmreligible, "<br>",
          "Vaccinated", if (!is_combined) " (1 dose)" else "", ": ", full_vax, "<br>",
          "Coverage: ", format_vax_pct(full_vax_pct)
        ),
        label = ~ paste0(
          daycare_name,
          if (is_combined) " (Daycare)" else "",
          ": ", format_vax_pct(full_vax_pct)
        ),
        labelOptions = labelOptions(direction = "top", textsize = "13px", opacity = 0.85)
      )
  }

  return(map)
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
      label = ~PREFNAME,
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
    } # end overlay groups if else

  # add overlays to map
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

# ==== Create legend for facility vaccine coverage cut points ====

legend_vax_cutpoints <- function(map) {
  map |>
    addLegend(
      position = "bottomright",
      colors = c("red", "orange", "gold", "darkgreen", "gray"),
      labels = c(
        "0-85", # red
        "85-90", # orange
        "90-95", # gold
        "95-100", # dark green
        "Missing/Unknown" # gray
      ),
      title = "School/Child Care MMR (%)",
      opacity = 0.9
    )
}

# ==== Vaccine coverage for boundary to display in submap title ====

submap_title_vax <- function(boundary_type,
                             selected_district,
                             district_data = NULL,
                             selected_county,
                             county_data = NULL) {
  is_district_mode <- !is.null(boundary_type) && boundary_type == "district"

  if (is_district_mode) {
    boundary_rate <- district_data |>
      dplyr::filter(join_key == selected_district) |>
      dplyr::pull(mmr_vax_pert) |> # need adaptable variables names
      dplyr::first()
  } else {
    boundary_rate <- county_data |>
      dplyr::filter(county_name == selected_county) |>
      dplyr::pull(full_vax_pct) |>
      dplyr::first()
  }

  tagList(
    tags$h4("MMR Coverage for Schools and Child Cares", class = "submap-title"),
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
