# county_level_map.R

# ============================================================
# COUNTY-LEVEL MAP MODULE
# ============================================================
#
# Purpose
# -------
# This module renders the main county map on the dashboard.
# The map displays county-level MMR vaccination coverage for K–12 schools
# and provides the primary geographic entry point for exploring the app.
# Users can click counties to drill down into facility-level data shown
# in the submap module.
#
# Core Features
# -------------
# • Displays the state's counties colored by MMR vaccination coverage.
# • Shows county demographic context including total enrollment,
#   students of color, and free/reduced lunch eligibility.
# • Optionally switches to historical measles case data when enabled.
# • Allows users to select a county directly by clicking on the map.
# • Visually highlights the currently selected county.
#
# Data Sources
# ------------
# counties, districts
#   Standard counties and districts objects (load_app_data.R):
#   boundaries with vaccination coverage and enrollment.
#
# pal_county
#   Color palette function used to shade counties according to MMR
#   vaccination coverage.
#
# map_view
#   Starting view for the map (map_view.R).
#
# Reactive Inputs Used
# --------------------
# input$show_cases
#   Toggles the measles case overlay on the county map.
#
# input$year_range
#   Filters measles cases to the selected year range.
#
# input$case_age_group
#   Filters measles cases by age group.
#
# input$selected_county
#   Name of the county currently selected in the dashboard controls.
#
# Outputs
# -------
# output$county_map
#   Leaflet map displaying county vaccination coverage and optional
#   measles case markers.
#
# Reactive Flow
# -------------
# User clicks county polygon
#        ↓
# county_map_shape_click event fires
#        ↓
# selected_county dropdown updates
#        ↓
# county highlight updates
#        ↓
# submap module loads facility-level data for that county
#
# ============================================================


countyMapServer <- function(input, output, session, counties, pal_county, districts = NULL,
                            map_view = map_view_from_counties(counties)) {

  # === County-level OR District-Level Leaflet Map ===
  output$county_map <- renderLeaflet({
    is_district_mode <- !is.null(input$boundary_type) && input$boundary_type == "district"

    if (is_district_mode && !is.null(districts)) {
      county_district_map_dashboard(districts, pal_county, "district", map_view)
    } else {
      county_district_map_dashboard(counties, pal_county, "county", map_view)
    }
  })

  # === Click county polygon to update county dropdown ===
  observeEvent(input$county_map_shape_click, {
    clicked <- input$county_map_shape_click$id
    is_district_mode <- !is.null(input$boundary_type) && input$boundary_type == "district"

    if (is_district_mode) {
      # clicked id is district_id
      updateSelectInput(session, "selected_district", selected = clicked)
    } else {
      # clicked id is the lower-case county name (map_layer_ids())
      match <- counties$county_name[map_layer_ids(counties, "county") == clicked]
      if (length(match) == 1) {
        updateSelectInput(session, "selected_county", selected = match)
      }
    }
  })

  # === Highlight selected county in orange ===
  observeEvent(input$selected_county, {
    req(input$selected_county)

    # Only act in county mode
    if (!is.null(input$boundary_type) && input$boundary_type == "district") {
      return()
    }

    highlight_selected(counties, tolower(input$selected_county), "county")

  })

  # === Highlight selected district in orange ===
  observeEvent(input$selected_district, {
    req(input$selected_district)
    # Only act in district mode
    if (is.null(input$boundary_type) || input$boundary_type != "district") {
      return()
    }
    if (is.null(districts)) {
      return()
    }

    highlight_selected(districts, input$selected_district, "district")

  })

  # === Create county map title with statewide MMR coverage ===

  output$county_map_title <- renderUI({
    rate <- calc_statewide_k12(counties)

    tagList(
      h4(
        "MMR Vaccine Coverage by County (K-12 Schools Only)",
        style = "font-weight:600;"
      ),
      if (!is.na(rate)) {
        tags$div(
          paste0("Statewide MMR Coverage: ", rate, "%"),
          style = "font-size:14px; color:#555; margin-bottom:8px;"
        )
      }
    )
  })
}
