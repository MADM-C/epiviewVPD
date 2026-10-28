# county_level_map.R

# ============================================================
# COUNTY-LEVEL MAP MODULE
# ============================================================
#
# Purpose
# -------
# This module renders the main Minnesota county map on the dashboard.
# The map displays county-level MMR vaccination coverage for K–12 schools
# and provides the primary geographic entry point for exploring the app.
# Users can click counties to drill down into facility-level data shown
# in the submap module.
#
# Core Features
# -------------
# • Displays Minnesota counties colored by MMR vaccination coverage.
# • Shows county demographic context including total enrollment,
#   students of color, and free/reduced lunch eligibility.
# • Optionally switches to historical measles case data when enabled.
# • Allows users to select a county directly by clicking on the map.
# • Visually highlights the currently selected county.
#
# Data Sources
# ------------
# county_map_data
#   Spatial dataset of Minnesota counties joined with vaccination
#   coverage and aggregated school demographic data.
#
# measles_cases
#   County-level measles case dataset containing counts by year and
#   age group used for secondary map switch.
#
# mn_counties
#   Base county shapefile used for spatial joins and lookup of county
#   names when map polygons are clicked.
#
# pal_county
#   Color palette function used to shade counties according to MMR
#   vaccination coverage.
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


countyMapServer <- function(input, output, session, county_map_data, mn_counties, pal_county,
                            school_district_data = NULL, district_map_data = NULL) {
  
  # === County-level OR District-Level Leaflet Map ===
  output$county_map <- renderLeaflet({
    is_district_mode <- !is.null(input$boundary_type) && input$boundary_type == "district"
    
    if (is_district_mode && !is.null(district_map_data)) {
      county_district_map_dashboard(district_map_data)
    } else {
      county_district_map_dashboard(county_map_data)
    }
  })

  # === Click county polygon to update county dropdown ===
  observeEvent(input$county_map_shape_click, {
    clicked <- input$county_map_shape_click$id
    is_district_mode <- !is.null(input$boundary_type) && input$boundary_type == "district"

    if (is_district_mode) {
      # clicked id is join_key (unique per district, handles Minneapolis = "S1")
      updateSelectInput(session, "selected_district", selected = clicked)
    } else {
      # clicked id is county_lower
      match <- mn_counties %>%
        filter(county_lower == clicked) %>%
        pull(county_name)
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

    selected_lower <- tolower(input$selected_county)
    highlight_selected(county_map_data, selected_lower)

  })

  # === Highlight selected district in orange ===
  observeEvent(input$selected_district, {
    req(input$selected_district)
    # Only act in district mode
    if (is.null(input$boundary_type) || input$boundary_type != "district") {
      return()
    }
    if (is.null(district_map_data)) {
      return()
    }
    
    selected_lower <- input$selected_district
    highlight_selected(district_map_data, selected_lower)

  })
  
  # === Create county map title with statewide MMR coverage ===
  
  output$county_map_title <- renderUI({
    # TEMPORARY FIX FOR STATEWIDE MMR COVERAGE - NEED TO MAKE ACTUAL FIX LATER
    # rate <- statewide_k12_rate()
    rate <- 92.8
    
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
