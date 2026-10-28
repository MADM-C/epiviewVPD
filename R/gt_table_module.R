# ==== GT TABLE MODULE (Statewide Data Tables and Epicurve) ====
#
# Purpose
# -------
# This module generates the statewide data tables displayed on the
# "Tables" tab of the dashboard (now called "Summary Figures"). 
# It provides summary views of:
# • School vaccination coverage
# • Child care vaccination coverage
# • Historical measles case counts (with accompanying epi curve)
#
# Core Features
# -------------
# • Called functions build three cleaned datasets used for table display:
#     - school_table
#     - daycare_table
#     - case_table
#
# • Displays vaccination coverage tables using the `gt` package with:
#     - color-coded MMR coverage
#     - sortable columns
#     - formatted enrollment values
#     - privacy-safe display for blurred values (e.g. ">95%")
#
# • Displays measles case counts by year and age group in a wide-format
#   table when historical case data are selected.
#
# • Synchronizes the county selector with the selected table type,
#   including a "Statewide" option for historical cases.
#
# • Renders an epidemic curve showing annual measles cases for either
#   the selected county or statewide totals.
#
# Data Inputs
# -----------
# school_demo_joined
#   Spatial dataset containing school vaccination coverage and
#   enrollment data. Geometry is removed before table construction.
#
# daycare_joined
#   Spatial dataset containing child care vaccination coverage and
#   MMR-eligible enrollment counts.
#
# measles_cases
#   Dataset containing historical measles cases by county, year,
#   and age group.
#
# mn_counties
#   Used to generate the list of counties for the table dropdown.
#
# Reactive Inputs Used
# --------------------
# input$table_type
#   Determines which table to display:
#       - School Vaccine Coverage
#       - Child Care Vaccine Coverage
#       - Historical Measles Cases
#
# input$gt_selected_county
#   County selected for table filtering.
#
# input$gt_sort_by
#   Column used to sort the school vaccination coverage table.
#
# Outputs
# -------
# output$summary_table
#   Main `gt` table displaying vaccination coverage or measles
#   case counts depending on the selected table type.
#
# output$epi_curve
#   Bar chart showing measles cases by year for the selected
#   county or statewide.
#
# Reactive Flow
# -------------
# User selects table type
#        ↓
# County selector updates to match valid choices
#        ↓
# Data filtered to selected county
#        ↓
# GT table rendered
#
# If historical cases selected:
#        ↓
# Epidemic curve generated from filtered case data
#
# ============================================================
# Expects in parent env: input, output, session,
#   school_demo_joined (sf), daycare_joined (sf), measles_cases (df)
# District lookup, school and child care table builders, and coverage gt
#   rendering live in functions/table_vaccine_functions.R.
# Measles case table, case filtering, case gt table, and epicurve live in
#   functions/table_measles_functions.R.

gtServer <- function(input, output, session,
                     selected_school_id,
                     school_demo_joined,
                     daycare_joined,
                     mmr_grade,
                     format_vax_pct,
                     measles_cases,
                     mn_counties,
                     district_map_data = NULL) {
  # ---------- Build School Table (with demographics) ----------
  
  district_data <- build_district_lookup(district_map_data)
  
  school_table_county <- build_school_table(school_demo_joined, "county")
  school_table_district <- build_school_table(school_demo_joined, "district", district_data)
  
  # ---------- Build Daycare Table ----------
  daycare_table <- build_daycare_table(daycare_joined)
  
  # ---------- Build Cases Table ----------
  case_table <- build_case_table(measles_cases)
  
  # ---------- Keep the county dropdown in sync with selected table ----------
  
  observeEvent(input$table_type, {
    all_counties <- sort(unique(str_to_title(mn_counties$county_name)))
    
    current_selection <- input$gt_selected_county
    
    if (input$table_type == "Historical Measles Cases") {
      new_choices <- c("Statewide", all_counties)
      
      if (!is.null(current_selection) && current_selection %in% new_choices) {
        new_selected <- current_selection
      } else {
        new_selected <- "Statewide"
      }
      updateSelectInput(
        session,
        "gt_selected_county",
        choices = new_choices,
        selected = new_selected
      )
    } else {
      if (!is.null(current_selection) && current_selection %in% all_counties) {
        new_selected <- current_selection
      } else {
        new_selected <- all_counties[1]
      }
      updateSelectInput(
        session,
        "gt_selected_county",
        choices = all_counties,
        selected = new_selected
      )
    }
  })
  
  observeEvent(input$gt_boundary_type, {
    req(input$table_type == "School Vaccine Coverage")
    
    if (input$gt_boundary_type == "district") {
      all_districts <- sort(unique(district_data$PREFNAME))
      current_selection <- input$gt_selected_district
      
      if (!is.null(current_selection) && current_selection %in% all_districts) {
        new_selected <- current_selection
      } else {
        new_selected <- all_districts[1]
      }
      
      updateSelectInput(
        session,
        "gt_selected_district",
        choices = all_districts,
        selected = new_selected
      )
    } else if (input$gt_boundary_type == "county") {
      all_counties <- sort(unique(str_to_title(mn_counties$county_name)))
      
      current_selection <- input$gt_selected_county
      
      if (!is.null(current_selection) && current_selection %in% all_counties) {
        new_selected <- current_selection
      } else {
        new_selected <- all_counties[1]
      }
      
      updateSelectInput(
        session,
        "gt_selected_county",
        choices = all_counties,
        selected = new_selected
      )
    }
  })
  
  
  # ---------- Render GT Summary Table ----------
  output$summary_table <- render_gt({
    req(input$table_type, input$gt_selected_county)
    
    if (input$table_type == "School Vaccine Coverage" && input$gt_boundary_type == "district") {
      table_to_use <- school_table_district
    } else {
      table_to_use <- switch(input$table_type,
                             "School Vaccine Coverage" = school_table_county,
                             "Child Care Vaccine Coverage" = daycare_table,
                             "Historical Measles Cases" = case_table
      )
    }
    
    filtered_data <- if (input$table_type == "Historical Measles Cases") {
      filter_cases(table_to_use, input$gt_selected_county)
    } else if (input$table_type == "School Vaccine Coverage" && input$gt_boundary_type == "district") {
      table_to_use %>%
        filter(district == input$gt_selected_district)
    } else {
      table_to_use %>%
        filter(county == input$gt_selected_county)
    }
    
    if (input$table_type == "Historical Measles Cases") {
      if (nrow(filtered_data) == 0) {
        return(gt(data.frame(Message = "No historical cases for selected county")))
      }
    } else {
      if (nrow(filtered_data) == 0) {
        return(gt(data.frame(Message = "No data for selected location")))
      }
    }
    
    if (input$table_type == "Historical Measles Cases") {
      return(render_cases_gt(filtered_data, input$gt_selected_county))
    }
    
    sorted_data <- sort_coverage_table(
      filtered_data,
      input$table_type,
      input$gt_boundary_type,
      input$gt_sort_by
    )
    
    render_coverage_gt(
      sorted_data,
      input$table_type,
      input$gt_boundary_type,
      input$gt_selected_county,
      input$gt_selected_district
    )
  })
  
  # ---------- Epicurve (MADMC color theme) ----------
  output$epi_curve <- renderPlot({
    req(input$table_type == "Historical Measles Cases", input$gt_selected_county)
    plot_epicurve(case_table, input$gt_selected_county)
  })
  
  # --- GT Tab Download Summary ---
  
  output$download_summary_figures <- downloadHandler(
    filename = function() {
      paste0(
        "summary_figures", paste0(
          if (input$table_type == "School Vaccine Coverage") {
            if (input$gt_boundary_type == "county") {
              paste0(input$gt_selected_county)
            } else if (input$gt_boundary_type == "district") {
              paste0(input$gt_selected_district)
            }
          } else {
            paste0(input$gt_selected_county)
          }
        ),
        ".html"
      )
    },
    content = function(file) {
      # Create a temporary directory for the report
      temp_dir <- tempdir()
      temp_report <- file.path(temp_dir, "gt_summary_report.Rmd")
      
      # Copy the Rmd template to temp directory
      file.copy("gt_summary_report.Rmd", temp_report, overwrite = TRUE)
      
      # Set up parameters to pass to the Rmd
      params <- list(
        school_table_county = school_table_county,
        school_table_district = school_table_district,
        daycare_table = daycare_table,
        case_table = case_table,
        measles_cases = measles_cases,
        table_type = input$table_type,
        boundary_type = input$gt_boundary_type,
        county = input$gt_selected_county,
        district = input$gt_selected_district,
        gt_sort_by = input$gt_sort_by
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