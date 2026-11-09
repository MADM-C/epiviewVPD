# Server for the summary tables and epidemic curve.
gtServer <- function(input, output, session, selected_school_id, schools, facilities,
  format_vax_pct, cases, counties, districts = NULL, notes = default_settings()$notes,
  bands = coverage_bands(), age_groups = case_age_groups(NULL, cases$age_group),
  features = all_features(), settings = NULL) {
  case_county <- reactive({
    current <- input$gt_selected_county
    choices <- c("Statewide", case_county_universe(counties))
    # Falls back to Statewide when the selected group isn't in the choices.
    if (length(current) == 1L && !is.na(current) && current %in% choices) current else "Statewide"
  })
  observeEvent(input$table_type, {
    historical <- isTRUE(input$table_type == "Historical Measles Cases")
    all_counties <- sort(unique(if (historical) case_county_universe(counties) else counties$county_name))
    choices <- if (historical) c("Statewide", all_counties) else all_counties
    current <- input$gt_selected_county
    if (!length(current) || !current %in% choices) current <- choices[1]
    updateSelectInput(session, "gt_selected_county", choices = choices, selected = current)
  })
  observeEvent(input$gt_boundary_type, {
    if (isTRUE(input$gt_boundary_type == "district") && !is.null(districts) && nrow(districts) > 0) {
      choices <- sort(unique(districts$district_name))
      current <- input$gt_selected_district
      if (!length(current) || !current %in% choices) current <- choices[1]
      updateSelectInput(session, "gt_selected_district", choices = choices, selected = current)
    }
  })
  if (features$school_summary || features$childcare_summary || features$cases_summary) {
    output$summary_table <- gt::render_gt({
      req(input$table_type)
      if (isTRUE(input$table_type == "Historical Measles Cases")) {
        req(features$cases_summary)
        render_cases_gt(cases, case_county(),
          settings = settings, counties = case_county_universe(counties))
      } else {
        childcare <- isTRUE(input$table_type == "Child Care Vaccine Coverage")
        req(if (childcare) features$childcare_summary else features$school_summary)
        build_coverage_table(schools, facilities, districts,
          table_type = if (childcare) "childcare" else "school",
          boundary_type = if (isTRUE(input$gt_boundary_type == "district")) "district" else "county",
          selected_county = input$gt_selected_county, selected_district = input$gt_selected_district,
          sort_by = input$gt_sort_by, notes = notes, bands = bands)
      }
    })
  }
  if (features$epicurve) output$epi_curve <- renderPlot({
    req(input$table_type == "Historical Measles Cases")
    plot_epicurve(cases, case_county(), settings = settings,
      counties = case_county_universe(counties))
  })
  output$download_summary_figures <- downloadHandler(
    filename = function() "summary_figures.html",
    content = function(file) {
      temp_report <- tempfile(fileext = ".Rmd")
      on.exit(unlink(temp_report), add = TRUE)
      file.copy(system.file("reports", "gt_summary_report.Rmd", package = "epiviewVPD"), temp_report)
      rmarkdown::render(temp_report, output_file = file,
        params = list(schools = schools, facilities = facilities, districts = districts,
          cases = cases, counties = counties, table_type = input$table_type,
          boundary_type = input$gt_boundary_type,
          county = if (isTRUE(input$table_type == "Historical Measles Cases")) case_county() else input$gt_selected_county,
          district = input$gt_selected_district, gt_sort_by = input$gt_sort_by,
          notes = notes, coverage_bands = bands, case_age_groups = age_groups,
          settings = settings, features = features),
        envir = new.env(parent = asNamespace("epiviewVPD")), quiet = TRUE)
    })
}
