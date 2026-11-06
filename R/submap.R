# ============================================================
# SUBMAP MODULE (Facility-Level Map)
# ============================================================
#
# Purpose
# -------
# This module renders the facility-level map that appears after a county
# is selected on the main county dashboard map. The submap allows users to
# explore individual schools and child care facilities within the selected
# county and view their MMR vaccination coverage.
#
# Core Features
# -------------
# • Displays individual schools, child cares, or both depending on the
#   selected point_type filter.
# • Uses a small micro-offset for schools so that facilities sharing the
#   same geographic coordinates remain visible and clickable.
# • Clicking a marker updates the global selected_school_id reactive value
#   and synchronizes the dropdown selector.
# • Selecting a facility from the dropdown highlights the facility on the
#   map and centers the user’s attention on that location.
# • Shows facility-level vaccination information through popups and labels.
# • Provides optional layer controls when both schools and child cares are
#   displayed simultaneously.
#
# Data Inputs
# -----------
# schools, facilities, counties, districts
#   Standard schools, child cares, counties and districts
#   (load_app_data.R). County and district boundaries outline the
#   selected area; districts are also drawn over the selected county.
#
# selected_school_id
#   Reactive value shared across modules that stores the ID of the currently
#   selected facility. This allows the grade details module to update when a
#   school is selected from the map or dropdown.
#
# format_vax_pct
#   Helper function used to format vaccination percentages consistently in
#   labels, popups, and tables.
#
# bands
#   Coverage color bands from the settings (coverage_bands.R).
#
# Reactive Inputs Used
# --------------------
# input$selected_county
#   Determines which county’s facilities are shown on the submap.
#
# input$selected_location
#   Dropdown selection used to highlight a specific school or child care.
#
# input$point_type
#   Controls whether the map displays schools, child cares, or both.
#
# input$sub_map_marker_click
#   Triggered when a facility marker is clicked on the map.
#
# Outputs
# -------
# output$sub_map
#   Leaflet map displaying facility-level vaccination coverage and
#   interactive selection behavior.
#
# Reactive Flow
# -------------
# County selected on main map
#        ↓
# Facilities for that county rendered on submap
#        ↓
# User clicks facility marker OR selects from dropdown
#        ↓
# selected_school_id updated
#        ↓
# Grade details module updates facility-specific information
#
# ============================================================

subMapServer <- function(input, output, session,
                         schools, facilities,
                         counties, selected_school_id, format_vax_pct,
                         districts = NULL, bands = coverage_bands()) {
  # === Click school/daycare marker to update school ID and dropdown ===
  observeEvent(input$sub_map_marker_click, {
    clicked_raw <- input$sub_map_marker_click$id

    if (is.null(clicked_raw) || length(clicked_raw) == 0) {
      return()
    }

    clicked_id <- as.character(clicked_raw)[1]

    facilities$facility_id <- as.character(facilities$facility_id)
    schools$school_id <- as.character(schools$school_id)

    school_df <- sf::st_drop_geometry(schools)
    daycare_df <- sf::st_drop_geometry(facilities)

    school_match <- dplyr::filter(school_df, school_id == clicked_id)
    daycare_match <- dplyr::filter(daycare_df, facility_id == clicked_id)

    name <- NULL
    if (nrow(school_match) > 0) {
      name <- school_match$school_name[1]
      selected_school_id(school_match$school_id[1])
    } else if (nrow(daycare_match) > 0) {
      name <- as.character(daycare_match$facility_id[1])
      selected_school_id(daycare_match$facility_id[1])
    }

    if (!is.null(name) && !is.na(name)) {
      updateSelectInput(session, "selected_location", selected = name)
    }
  })


  # === Location selection triggers highlight and fly ===

  observeEvent(input$selected_location, {
    req(input$selected_location)

    area <- get_location_choices_data(
      drop_sf = FALSE,
      boundary_type = input$boundary_type,
      point_type = input$point_type,
      selected_district = input$selected_district,
      selected_county = input$selected_county,
      district_data = districts,
      county_data = counties,
      school_data = schools,
      childcare_data = facilities
    )
    # Highlight the selected school or child care on the submap and store its
    # ID in selected_school_id
    point_type <- input$point_type

    if (point_type == "Schools") {
      selected_row <- area$schools %>%
        filter(school_name == input$selected_location) %>%
        slice(1)

      if (nrow(selected_row) > 0) {
        selected_school_id(selected_row$school_id)
        leafletProxy("sub_map") %>%
          clearGroup("highlight") %>%
          addCircleMarkers(
            data = selected_row,
            radius = 9,
            color = "black",
            weight = 3,
            fillColor = "black",
            fillOpacity = 1,
            group = "highlight",
            popup = paste0(
              "<b>", selected_row$school_name, "</b><br>",
              "MMR: ", format_vax_pct(selected_row$full_vax_pct)
            )
          )
      }
    } else if (point_type == "Child Cares") {
      selected_row <- area$childcares %>%
        filter(facility_id == input$selected_location)

      if (nrow(selected_row) > 0) {
        selected_school_id(selected_row$facility_id)
        leafletProxy("sub_map") %>%
          clearGroup("highlight") %>%
          addCircleMarkers(
            data = selected_row,
            radius = 9,
            color = "black",
            weight = 3,
            fillColor = "black",
            fillOpacity = 1,
            group = "highlight",
            popup = paste0(
              "<b>", selected_row$facility_name, "</b><br>",
              "MMR: ", format_vax_pct(selected_row$full_vax_pct)
            )
          )
      }
    } else if (point_type == "Schools and Child Cares") {
      school_row <- area$schools %>%
        filter(school_name == input$selected_location) %>%
        slice(1)

      childcare_row <- area$childcares %>%
        filter(facility_name == input$selected_location) %>%
        slice(1)

      if (nrow(school_row) > 0) {
        selected_school_id(school_row$school_id)
        leafletProxy("sub_map") %>%
          clearGroup("highlight") %>%
          addCircleMarkers(
            data = school_row,
            radius = 12,
            color = "black",
            weight = 3,
            fillColor = "gold",
            fillOpacity = 1,
            group = "highlight",
            popup = paste0(
              "<b>", school_row$school_name, "</b><br>",
              "MMR: ", format_vax_pct(school_row$full_vax_pct)
            )
          )
      } else if (nrow(childcare_row) > 0) {
        selected_school_id(childcare_row$facility_id)
        leafletProxy("sub_map") %>%
          clearGroup("highlight") %>%
          addCircleMarkers(
            data = childcare_row,
            radius = 9,
            color = "black",
            weight = 3,
            fillColor = "black",
            fillOpacity = 1,
            group = "highlight",
            popup = paste0(
              "<b>", childcare_row$facility_name, "</b><br>",
              "MMR: ", format_vax_pct(childcare_row$full_vax_pct)
            )
          )
      }
    }
  })

  # === Render the sub map with micro-offset ===

  output$sub_map <- renderLeaflet({
    area <- get_location_choices_data(
      drop_sf = FALSE,
      boundary_type = input$boundary_type,
      point_type = input$point_type,
      selected_district = input$selected_district,
      selected_county = input$selected_county,
      district_data = districts,
      county_data = counties,
      school_data = schools,
      childcare_data = facilities
    )

    boundary_shape <- area$boundary
    boundary_schools <- area$schools
    boundary_childcares <- area$childcares

    # Apply micro-offset to schools
    boundary_schools_offset <- add_micro_offset(boundary_schools)

    # Base map with boundary outline
    map <- base_submap(boundary_shape)

    # Add markers for schools and child cares
    map <- map |>
      add_point_layers(
        point_type = input$point_type,
        school_data = boundary_schools_offset,
        childcare_data = boundary_childcares,
        bands = bands
      )

    # --- School District overlay (filtered to selected county) ---

    is_district_mode <- !is.null(input$boundary_type) && input$boundary_type == "district"

    if (!is_district_mode && !is.null(districts)) {
      county_districts <- filter_spatial_safe(districts, boundary_shape)

      if (nrow(county_districts) > 0) {
        map <- map |>
          county_district_overlay(county_districts)
      }
    }

    # --- Layer control (always shown; groups vary by point_type) ---

    map <- control_overlay_groups(
      point_type = input$point_type,
      boundary_type = input$boundary_type,
      map = map
    )

    # --- Add legend for school/daycare cut-points ---

    map <- add_coverage_legend(map, bands,
                               title = "School/Child Care MMR (%)",
                               missing_label = "Missing/Unknown")
    map
  })

  # --- Add/remove the legend depending on point_type ---
  observe({
    if (input$point_type == "Schools and Child Cares") {
      leafletProxy("sub_map") |>
        addControl(legend_html, position = "topleft", layerId = "type_legend")
    } else {
      leafletProxy("sub_map") |>
        removeControl("type_legend")
    }
  })

  # === Create submap title with county or district MMR coverage ===
  output$submap_title <- renderUI({
    submap_title_vax(
      boundary_type = input$boundary_type,
      selected_district = input$selected_district,
      district_data = districts,
      selected_county = input$selected_county,
      county_data = counties
    )
  })
}
