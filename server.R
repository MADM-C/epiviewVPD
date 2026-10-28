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
# ============================================================

source("packages_and_data.R")
source("params.R")
source("functions/server_functions.R")

# ==== Server ====
server <- function(input, output, session) {
  # Reactive value to store the current county selection
  current_county <- reactiveVal("Aitkin")

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
    updateSelectInput(session, "selected_county", choices = sort(unique(mn_counties$county_name)))

    # Populate district dropdown (display name = PREFNAME, value = join_key)
    district_choices <- setNames(district_map_data$join_key, district_map_data$PREFNAME)
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

  source("functions/county_level_map_functions.R")
  source("R/county_level_map.R")

  countyMapServer(
    input = input,
    output = output,
    session = session,
    county_map_data = county_map_data,
    mn_counties = mn_counties,
    pal_county = pal_county,
    school_district_data = school_district_data,
    district_map_data = district_map_data
  )

  # === Submap ====
  source("functions/add_point_offset.R")
  source("functions/submap_functions.R")
  source("R/submap.R")

  subMapServer(
    input = input,
    output = output,
    session = session,
    school_demo_joined = school_demo_joined,
    daycare_joined = daycare_joined,
    county_map_data = county_map_data,
    selected_school_id = selected_school_id,
    format_vax_pct = format_vax_pct,
    school_district_data = school_district_data,
    district_map_data = district_map_data
  )

  # === Grade level Details Section ====
  source("functions/grade_details_helper_functions.R")
  source("functions/grade_details_table_functions.R")
  source("functions/grade_details_plot_functions.R")
  source("functions/grade_details_overview_functions.R")
  source("R/grade_details_module.R")

  gradeDetailsServer(
    input = input,
    output = output,
    session = session,
    selected_school_id = selected_school_id,
    school_demo_joined = school_demo_joined,
    daycare_joined = daycare_joined,
    mmr_grade = mmr_grade,
    format_vax_pct = format_vax_pct,
    district_map_data = district_map_data
  )

  # ==== GT Table Tab ====

  source("R/gt_table_module.R")
  source("functions/table_vaccine_functions.R")
  source("functions/table_measles_functions.R")

  gtServer(
    input = input,
    output = output,
    session = session,
    selected_school_id = selected_school_id,
    school_demo_joined = school_demo_joined,
    daycare_joined = daycare_joined,
    mmr_grade = mmr_grade,
    mn_counties = mn_counties,
    measles_cases = measles_cases,
    format_vax_pct = format_vax_pct,
    district_map_data = district_map_data
  )

  # ==== Measles Outbreak Tab ====

  source("functions/combine_school_childcare_data.R")
  source("functions/analyze_point_proximity.R")
  source("functions/map_markers.R")
  source("R/measles_proximity_map.R")
  source("R/measles_proximity_table.R")
  source("functions/analyze_point_proximity.R")
  
  # Initialize the proximity map module
  ## For any updating of the app, switch out what dataframe is being utilized in the reactive expressions below
  proximity_results <- proximityMapServer(
    school_data = reactive(school_demo_joined),
    daycare_data = reactive(daycare_joined),
    county_map_data = reactive(county_map_data),
    healthcare_center_data = reactive(healthcare_center_data),
    school_district_data = school_district_data,
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
  
  source("R/statewide_cases_module.R")
  
  StatewideCasesServer(
    input = input,
    output = output,
    session = session,
    measles_cases = measles_cases,
    mn_counties = mn_counties
  )

  # === Resources ===
  
  source("R/resource_module.R")
  
  resourceServer(
    input = input,
    output = output,
    session = session
  )

}
