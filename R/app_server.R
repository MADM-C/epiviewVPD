# ============================================================
# SERVER LOGIC – MIDWEST EPIVIEW: MEASLES DASHBOARD
# ============================================================
#
# Purpose
# -------
# This file coordinates all server-side logic for the dashboard
# and initializes all modular components.
#
# The server primarily performs four roles:
#
# 1. Manage shared reactive state used across modules
#    (e.g., selected_school_id).
#
# 2. Initialize UI inputs such as dropdown menus and filters.
#
# 3. Load and execute Shiny modules responsible for rendering
#    maps, tables, and detailed facility views.
#
#
# Major Modules Initialized Here
# ------------------------------
# countyMapServer()     → county and district-level vaccination map
# subMapServer()        → facility-level map (schools/daycares)
# gradeDetailsServer()  → grade-level vaccination panel
# gtServer()            → county and district-level vaccination and case table
# proximityMapServer()  → proximity search map
# proximityTableServer()→ results table for proximity search
# StatewideCasesServer()→ historical measles cases on statewide map
# resourceServer()      → dashboard resources
#
# Input:  app_data, the standard app data returned by load_app_data()
# Output: the server function passed to shinyApp() in run_dashboard()
# ============================================================

app_server <- function(app_data) {
  # ==== Color Palette ====
  pal_county <- county_palette(app_data$counties$full_vax_pct_num)

  # ==== Server ====
  function(input, output, session) {
    # Reactive value to store the current county selection; starts at the
    # first county in the county dropdown
    current_county <- reactiveVal(sort(unique(app_data$counties$county_name))[1])

    # Update stored value when dashboard selection changes
    observeEvent(input$selected_county, {
      current_county(input$selected_county)
      # Update summary tab to match dashboard selection
      updateSelectInput(session, "gt_selected_county", selected = input$selected_county)
    })

    # Update stored value when summary table selection changes
    observeEvent(input$gt_selected_county, {
      current_county(input$gt_selected_county)
      # Switch dashboard back to county view when county selected on summary table
      if (input$boundary_type == "district") {
        updateRadioButtons(session, "boundary_type", selected = "county")
      }

      # Update dashboard drop down when value selected on summary table
      updateSelectInput(session, "selected_county", selected = input$gt_selected_county)
    })

    observeEvent(input$boundary_type, {
      if (input$boundary_type == "county") {
        updateSelectInput(session, "selected_county", selected = current_county())
      }
    })

    # Reactive value to store selected school ID (for use in grade/demographic lookup)
    selected_school_id <- reactiveVal(NULL)

    observeEvent(input$point_type, {
      selected_school_id(NULL)
    })

    observeEvent(input$boundary_type, {
      selected_school_id(NULL)
    })

    # Initialize dropdowns when the app loads
    observe({
      # Populate county dropdown with sorted list of unique county names
      updateSelectInput(session, "selected_county", choices = sort(unique(app_data$counties$county_name)))

      # Populate district dropdown (display name = district_name, value = district_id)
      district_choices <- setNames(app_data$districts$district_id, app_data$districts$district_name)
      district_choices <- district_choices[order(names(district_choices))]
      updateSelectInput(session, "selected_district", choices = district_choices)

      # Populate measles case age group selector
      updateSelectInput(
        session,
        "case_age_group",
        choices = c(
          "All Ages",
          "0-4", "5-11", "12-19", "20-49", "50+"
        ),
        selected = "All Ages"
      )
    })

    # === County-level Leaflet Map ====

    countyMapServer(
      input = input,
      output = output,
      session = session,
      counties = app_data$counties,
      pal_county = pal_county,
      districts = app_data$districts
    )

    # === Submap ====

    subMapServer(
      input = input,
      output = output,
      session = session,
      schools = app_data$schools,
      facilities = app_data$facilities,
      counties = app_data$counties,
      selected_school_id = selected_school_id,
      format_vax_pct = format_vax_pct,
      districts = app_data$districts
    )

    # === Grade level Details Section ====

    gradeDetailsServer(
      input = input,
      output = output,
      session = session,
      selected_school_id = selected_school_id,
      schools = app_data$schools,
      facilities = app_data$facilities,
      grades = app_data$grades,
      format_vax_pct = format_vax_pct,
      counties = app_data$counties,
      districts = app_data$districts
    )

    # ==== GT Table Tab ====

    gtServer(
      input = input,
      output = output,
      session = session,
      selected_school_id = selected_school_id,
      schools = app_data$schools,
      facilities = app_data$facilities,
      counties = app_data$counties,
      cases = app_data$cases,
      format_vax_pct = format_vax_pct,
      districts = app_data$districts
    )

    # ==== Measles Outbreak Tab ====


    # Initialize the proximity map module
    proximity_results <- proximityMapServer(
      schools = reactive(app_data$schools),
      facilities = reactive(app_data$facilities),
      counties = reactive(app_data$counties),
      healthcare_center_data = reactive(app_data$healthcare_centers),
      districts = app_data$districts,
      output = output,
      input = input,
      session = session
    )

    # Initialize the proximity table module (uses values from the map module)
    proximityTableServer(
      proximity_map_values = proximity_results,
      output = output,
      input = input
    )

    # ==== Statewide Measles Cases ====


    StatewideCasesServer(
      input = input,
      output = output,
      session = session,
      cases = app_data$cases,
      counties = app_data$counties
    )

    # === Resources ===


    resourceServer(
      input = input,
      output = output,
      session = session
    )

  }
}
