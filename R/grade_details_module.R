# grade_details_module.R

# ============================================================
# GRADE DETAILS MODULE (Facility-Level Detail Panel)
# ============================================================
#
# Purpose
# -------
# This module renders the detailed information panel for the
# selected facility (school or child care). It displays grade-
# level MMR vaccination data for schools, along with enrollment
# totals and overall vaccination coverage. For child care
# facilities, grade-level information is not available, so a
# simplified message is displayed instead.
#
# Core Features
# -------------
# • Displays grade-level vaccination coverage for the selected
#   school in both a table and a bar chart.
# • Shows overall school-level enrollment and total MMR coverage.
# • Handles privacy redactions where grade-level enrollment is
#   fewer than 10 students.
# • Formats blurred vaccination values (e.g., ">95%") for both
#   table display and chart rendering.
# • Provides a searchable dropdown selector for schools and
#   child cares within the currently selected county.
#
# Data Inputs
# -----------
# selected_school_id
#   Shared reactive value that stores the ID of the currently
#   selected facility. This value is updated by the submap module
#   when users click a facility marker or select a location.
#
# school_demo_joined
#   School-level dataset containing enrollment totals and overall
#   vaccination coverage.
#
# daycare_joined
#   Dataset containing child care vaccination information used
#   primarily for the location selector.
#
# mmr_grade
#   Dataset containing grade-level vaccination coverage for
#   individual schools.
#
# format_vax_pct
#   Helper function used to format vaccination percentages for
#   consistent display across tables, charts, and popups.
#
# Reactive Inputs Used
# --------------------
# input$selected_location
#   Facility selected in the dropdown menu.
#
# input$selected_county
#   Used to populate the dropdown with schools and child cares
#   from the currently selected county.
#
# input$point_type
#   Determines whether the dropdown lists schools, child cares,
#   or both.
#
# Outputs
# -------
# output$grade_table
#   Table showing grade-level MMR vaccination coverage.
#
# output$grade_plot
#   Horizontal bar chart visualizing grade-level vaccination
#   coverage.
#
# output$grade_output
#   Combined UI panel displaying facility name, enrollment,
#   vaccination summary, and grade-level details.
#
# output$school_daycare_selector
#   Searchable dropdown menu allowing users to select a school
#   or child care facility within the selected county.
#
# Reactive Flow
# -------------
# Facility selected on submap or dropdown
#        ↓
# selected_school_id updated
#        ↓
# grade-level data pulled from mmr_grade
#        ↓
# table + bar chart rendered
#        ↓
# enrollment and coverage summary displayed
#
# ============================================================

gradeDetailsServer <- function(input, output, session,
                               selected_school_id,
                               school_demo_joined,
                               daycare_joined,
                               mmr_grade,
                               format_vax_pct,
                               district_map_data = NULL) {
  
  # === Table of Grade-Level MMR for Selected School ====
  output$grade_table <- render_gt({
    school_id <- resolve_school_id(selected_school_id, 
                                   input$selected_location,
                                   school_data = school_demo_joined)

    req(school_id)

    if (is_nonresponder(school_id, school_data = school_demo_joined)) {
      NULL
    } else {
      grade_level_table(school_id, grade_data = mmr_grade)
    }
  })

  # === Grade-Level Bar Chart (NA-safe) ===
  output$grade_plot <- renderPlot({
    school_id <- resolve_school_id(selected_school_id, input$selected_location, school_data = school_demo_joined)

    req(school_id)

    if (is_nonresponder(school_id, school_data = school_demo_joined)) {
      NULL
    } else {
      grade_level_plot(school_id, grade_data = mmr_grade)
    }
  })

  # === Facility Level Overview with District/County and Demographic Details ===

  output$grade_output <- renderUI({
    school_id <- resolve_school_id(selected_school_id, input$selected_location,
                                   school_data = school_demo_joined)

    req(school_id)

    is_school <- school_id %in% school_demo_joined$mde_school_id
    is_childcare <- school_id %in% daycare_joined$idsch

    if (is_school) {
      metrics <- get_facility_metrics(
        is_school = is_school,
        is_childcare = is_childcare,
        school_id = school_id,
        facility_data = school_demo_joined,
        county_data = county_map_data,
        district_data = district_map_data,
        grade_data = mmr_grade
      )

      render_school_overview(
        school_id = school_id,
        selected_location = input$selected_location,
        school_type = metrics$school_type,
        total_enrollment = metrics$total_enrollment,
        languages = metrics$languages,
        district_name = metrics$district_name,
        district_vax = metrics$district_vax,
        county_name_school = metrics$county_name_school,
        county_vax = metrics$county_vax,
        overall_cov = metrics$overall_cov,
        grade_rows = metrics$grade_rows,
        all_grades_redacted = metrics$all_grades_redacted,
        nonresponder_status = metrics$nonresponder_status,
        med_exempt = metrics$med_exempt,
        nonmed_exempt = metrics$nonmed_exempt,
        partial_vax = metrics$partial_vax
      )
    } else if (is_childcare) {
      metrics <- get_facility_metrics(
        is_school = is_school,
        is_childcare = is_childcare,
        school_id = school_id,
        facility_data = daycare_joined,
        county_data = county_map_data,
      )

      render_childcare_overview(
        school_id = school_id,
        facility_data = daycare_joined,
        overall_cov = metrics$overall_cov,
        total = metrics$total,
        total_elig = metrics$total_elig,
        county_name_daycare = metrics$county_name_daycare,
        county_vax = metrics$county_vax
      )
    }
  })

  # === UI: School/Daycare Selector ===
  output$school_daycare_selector <- renderUI({
    
    location_choices <- get_location_choices_data(
      drop_sf = TRUE,
      boundary_type = input$boundary_type,
      point_type = input$point_type,
      selected_district = input$selected_district,
      selected_county = input$selected_county,
      district_data = district_map_data,
      county_data = county_map_data,
      school_data = school_demo_joined,
      childcare_data = daycare_joined
    )
    selectizeInput(
      inputId = "selected_location",
      label = "School/Child Care:",
      choices = c("", location_choices),
      selected = NULL,
      options = list(
        placeholder = "Search school or child care...",
        maxOptions = 1000
      )
    )
  })

  # ===  Grade Level Details Download Summary ===

  output$download_dashboard_report <- downloadHandler(
    filename = function() {
      paste0(input$selected_location, " summary", ".html")
    },
    content = function(file) {
      # Create a temporary directory for the report
      temp_dir <- tempdir()
      temp_report <- file.path(temp_dir, "dashboard_report.Rmd")

      # Copy the Rmd template to temp directory
      file.copy("dashboard_report.Rmd", temp_report, overwrite = TRUE)

      # Set up parameters to pass to the Rmd
      params <- list(
        boundary = input$boundary_type,
        school_data = school_demo_joined,
        childcare_data = daycare_joined,
        selected_district = input$selected_district,
        selected_county = input$selected_county,
        point_type = input$point_type,
        selected_location = input$selected_location,
        selected_school_id = selected_school_id(),
        district_data = district_map_data,
        county_data = county_map_data,
        grade_data = mmr_grade
      )

      # Render the report
      rmarkdown::render(
        temp_report,
        output_file = file,
        params = params,
        envir = new.env(parent = globalenv())
      )
    }
  )
}
