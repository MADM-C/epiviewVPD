# ============================================================
# SERVER LOGIC – EPIVIEW VPD DASHBOARD
# ============================================================
#
# Holds the values shared across modules (such as selected_school_id),
# fills the dropdown menus and starts the Shiny modules listed below.
#
# Modules started here
# --------------------
# countyMapServer()     → county and district-level vaccination map
# subMapServer()        → facility-level map (schools/daycares)
# gradeDetailsServer()  → grade-level vaccination panel
# gtServer()            → county and district-level vaccination and case table
# proximityMapServer()  → proximity search map
# proximityTableServer()→ results table for proximity search
# StatewideCasesServer()→ historical measles cases on statewide map
# resourceServer()      → dashboard resources
#
# Input:  app_data, the standard app data returned by load_app_data();
#         dashboard_config, the settings from read_dashboard_settings()
# Output: the server function passed to shinyApp() in run_dashboard()
# ============================================================

app_server <- function(app_data, dashboard_config) {
  features <- dashboard_features(dashboard_config)
  # ==== Settings used by the modules ====
  # Coverage cutoffs and colors (settings `coverage_bins`, coverage_bands.R)
  bands <- coverage_bands(dashboard_config$coverage_bins,
                          dashboard_config$suppression$blurred_offset)
  # Case age groups (settings `case_age_groups`, or the data's; case_age_groups.R)
  age_groups <- case_age_groups(dashboard_config$case_age_groups, app_data$cases$age_group)
  # Starting view for the maps (settings `map`, or fit to the counties)
  map_view <- if (any(unlist(features[c("coverage_map", "cases_map", "facility_map", "proximity_map")]))) {
    dashboard_map_view(dashboard_config$map, app_data$counties)
  } else NULL
  # Footnotes about the data (settings `notes`)
  notes <- dashboard_config$notes

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
      if (!input$gt_selected_county %in% app_data$counties$county_name) return()
      current_county(input$gt_selected_county)
      # Switch dashboard back to county view when county selected on summary table
      if (isTRUE(input$boundary_type == "district")) {
        updateRadioButtons(session, "boundary_type", selected = "county")
      }

      # Update dashboard drop down when value selected on summary table
      updateSelectInput(session, "selected_county", selected = input$gt_selected_county)
    })

    observeEvent(input$boundary_type, {
      if (isTRUE(input$boundary_type == "county")) {
        updateSelectInput(session, "selected_county", selected = current_county())
      }
    })

    # Reactive value to store selected school ID (for use in grade/demographic lookup)
    selected_school_id <- reactiveVal(NULL)

    if (any(unlist(features[c("facility_map", "facility_overview", "grade_plot", "grade_table")]))) {
      facilitySelectionServer(input, output, session, selected_school_id,
        app_data$schools, app_data$facilities, app_data$counties, app_data$districts,
        map_enabled = features$facility_map)
    }

    # Initialize dropdowns when the app loads
    observe({
      updateSelectInput(session, "selected_county", choices = sort(unique(app_data$counties$county_name)))

      # Populate district dropdown (display name = district_name, value = district_id)
      district_choices <- setNames(app_data$districts$district_id, app_data$districts$district_name)
      district_choices <- district_choices[order(names(district_choices))]
      updateSelectInput(session, "selected_district", choices = district_choices)

      # Measles case age group selector
      updateSelectInput(
        session,
        "case_age_group",
        choices = c("All Ages", age_groups),
        selected = "All Ages"
      )
    })

    # === County-level Leaflet Map ====

    if (features$coverage_map) countyMapServer(
      input = input,
      output = output,
      session = session,
      counties = app_data$counties,
      bands = bands,
      districts = app_data$districts,
      map_view = map_view,
      settings = dashboard_config
    )

    # === Submap ====

    if (features$facility_map) subMapServer(
      input = input,
      output = output,
      session = session,
      schools = app_data$schools,
      facilities = app_data$facilities,
      counties = app_data$counties,
      selected_school_id = selected_school_id,
      format_vax_pct = format_vax_pct,
      districts = app_data$districts,
      bands = bands,
      settings = dashboard_config
    )

    # === Grade level Details Section ====

    if (any(unlist(features[c("facility_overview", "grade_plot", "grade_table")]))) gradeDetailsServer(
      input = input,
      output = output,
      session = session,
      selected_school_id = selected_school_id,
      schools = app_data$schools,
      facilities = app_data$facilities,
      grades = app_data$grades,
      format_vax_pct = format_vax_pct,
      counties = app_data$counties,
      districts = app_data$districts,
      notes = notes,
      map_view = map_view,
      bands = bands,
      features = features,
      settings = dashboard_config
    )

    # ==== GT Table Tab ====

    if (any(unlist(features[c("school_summary", "childcare_summary", "cases_summary", "epicurve")]))) gtServer(
      input = input,
      output = output,
      session = session,
      selected_school_id = selected_school_id,
      schools = app_data$schools,
      facilities = app_data$facilities,
      counties = app_data$counties,
      cases = app_data$cases,
      format_vax_pct = format_vax_pct,
      districts = app_data$districts,
      notes = notes,
      bands = bands,
      age_groups = age_groups,
      features = features,
      settings = dashboard_config
    )

    # ==== Measles Outbreak Tab ====


    if (features$proximity_map || features$proximity_table) {
    proximity_results <- proximityMapServer(
      schools = reactive(app_data$schools),
      facilities = reactive(app_data$facilities),
      counties = reactive(app_data$counties),
      healthcare_center_data = reactive(app_data$healthcare_centers),
      districts = app_data$districts,
      map_view = map_view,
      output = output,
      input = input,
      session = session,
      draw_map = features$proximity_map,
      settings = dashboard_config
    )

    # Uses the values returned by the proximity map module
    if (features$proximity_table) proximityTableServer(
      proximity_map_values = proximity_results,
      output = output,
      input = input
    )
    }

    # ==== Statewide Measles Cases ====


    if (features$cases_map) StatewideCasesServer(
      input = input,
      output = output,
      session = session,
      cases = app_data$cases,
      counties = app_data$counties,
      map_view = map_view,
      settings = dashboard_config
    )

    # === Resources ===


    if (features$resources) resourceServer(
      input = input,
      output = output,
      session = session,
      case_studies = dashboard_config$case_studies
    )

  }
}
