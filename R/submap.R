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
# school_demo_joined
#   Spatial dataset containing school vaccination coverage, demographic
#   attributes, and geometry.
#
# daycare_joined
#   Spatial dataset containing child care vaccination coverage and geometry.
#
# county_map_data
#   County boundary geometry used to draw the outline of the currently
#   selected county.
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
                         school_demo_joined, daycare_joined,
                         county_map_data, selected_school_id, format_vax_pct,
                         school_district_data = NULL, district_map_data = NULL) {
  # === Click school/daycare marker to update school ID and dropdown ===
  observeEvent(input$sub_map_marker_click, {
    clicked_raw <- input$sub_map_marker_click$id

    if (is.null(clicked_raw) || length(clicked_raw) == 0) {
      return()
    }

    clicked_id <- as.character(clicked_raw)[1]

    daycare_joined$idsch <- as.character(daycare_joined$idsch)
    school_demo_joined$mde_school_id <- as.character(school_demo_joined$mde_school_id)

    school_df <- sf::st_drop_geometry(school_demo_joined)
    daycare_df <- sf::st_drop_geometry(daycare_joined)

    school_match <- dplyr::filter(school_df, mde_school_id == clicked_id)
    daycare_match <- dplyr::filter(daycare_df, idsch == clicked_id)

    name <- NULL
    if (nrow(school_match) > 0) {
      name <- school_match$school_name[1]
      selected_school_id(school_match$mde_school_id[1])
    } else if (nrow(daycare_match) > 0) {
      name <- as.character(daycare_match$idsch[1])
      selected_school_id(daycare_match$idsch[1])
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
      district_data = district_map_data,
      county_data = county_map_data,
      school_data = school_demo_joined,
      childcare_data = daycare_joined
    )
    # **** HERE IS WHERE MY ATTEMPT AT FUNCTIONIZING MESSED WITH THE REACTIVITY
    point_type <- input$point_type

    if (point_type == "Schools") {
      selected_row <- area$schools %>%
        dplyr::filter(school_name == input$selected_location) %>%
        dplyr::slice(1)

      if (nrow(selected_row) > 0) {
        selected_school_id(selected_row$mde_school_id)
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
        dplyr::filter(idsch == input$selected_location)

      if (nrow(selected_row) > 0) {
        selected_school_id(selected_row$idsch)
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
              "<b>", selected_row$daycare_name, "</b><br>",
              "MMR: ", format_vax_pct(selected_row$full_vax_pct)
            )
          )
      }
    } else if (point_type == "Schools and Child Cares") {
      school_row <- area$schools %>%
        dplyr::filter(school_name == input$selected_location) %>%
        dplyr::slice(1)

      childcare_row <- area$childcares %>%
        dplyr::filter(daycare_name == input$selected_location) %>%
        dplyr::slice(1)

      if (nrow(school_row) > 0) {
        selected_school_id(school_row$mde_school_id)
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
        selected_school_id(daycare_row$idsch)
        leafletProxy("sub_map") %>%
          clearGroup("highlight") %>%
          addCircleMarkers(
            data = daycare_row,
            radius = 9,
            color = "black",
            weight = 3,
            fillColor = "black",
            fillOpacity = 1,
            group = "highlight",
            popup = paste0(
              "<b>", daycare_row$daycare_name, "</b><br>",
              "MMR: ", format_vax_pct(daycare_row$full_vax_pct)
            )
          )
      }
      # ******** END REACTIVITY PROBLEM AREA 
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
      district_data = district_map_data,
      county_data = county_map_data,
      school_data = school_demo_joined,
      childcare_data = daycare_joined
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
        childcare_data = boundary_childcares
      )

    # --- School District overlay (filtered to selected county) ---

    is_district_mode <- !is.null(input$boundary_type) && input$boundary_type == "district"

    if (!is_district_mode && !is.null(school_district_data)) {
      county_districts <- filter_spatial_safe(school_district_data, boundary_shape)

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

    map <- legend_vax_cutpoints(map = map)
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
      district_data = district_map_data,
      selected_county = input$selected_county,
      county_data = county_map_data
    )
  })
}
