# Server for the facility details section (overview, grade plot and table).
gradeDetailsServer <- function(input, output, session, selected_school_id, schools, facilities,
  grades, format_vax_pct, counties, districts = NULL, notes = default_settings()$notes,
  map_view = NULL, bands = coverage_bands(), features = all_features(), settings = NULL) {
  selected <- reactive(select_facility(selected_school_id(), schools, facilities))
  if (features$grade_table) output$grade_table <- gt::render_gt({
    facility <- selected()
    req(!is.null(facility), facility$type == "school")
    grade_level_table(grade_data = grades, school_id = facility$id)
  })
  if (features$grade_plot) output$grade_plot <- renderPlot({
    facility <- selected()
    req(!is.null(facility), facility$type == "school")
    grade_level_plot(grade_data = grades, school_id = facility$id, bands = bands)
  })
  output$grade_output <- renderUI({
    facility_overview_panel(selected(), schools, facilities, counties, districts, grades, notes, features)
  })
  output$facility_report_download <- renderUI({
    if (!is.null(selected())) downloadButton("download_dashboard_report", "Download Summary")
  })
  output$download_dashboard_report <- downloadHandler(
    filename = function() {
      facility <- selected()
      paste0(if (is.null(facility)) "facility" else gsub("[^[:alnum:]_-]", "_", facility$name), "_summary.html")
    },
    content = function(file) {
      facility <- selected()
      req(!is.null(facility))
      temp_report <- tempfile(fileext = ".Rmd")
      on.exit(unlink(temp_report), add = TRUE)
      file.copy(system.file("reports", "dashboard_report.Rmd", package = "epiviewVPD"), temp_report)
      rmarkdown::render(temp_report, output_file = file,
        params = list(boundary = input$boundary_type, school_data = schools,
          childcare_data = facilities, selected_district = input$selected_district,
          selected_county = input$selected_county, point_type = input$point_type,
          selected_location = facility$name, selected_school_id = paste0(facility$type, ":", facility$id),
          district_data = districts, county_data = counties, grade_data = grades,
          map_view = map_view, coverage_bands = bands, notes = notes, features = features, settings = settings),
        envir = new.env(parent = asNamespace("epiviewVPD")), quiet = TRUE)
    })
}
