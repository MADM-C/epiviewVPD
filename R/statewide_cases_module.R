# Server for the historical cases map.
StatewideCasesServer <- function(input, output, session, cases, counties,
                                  map_view = map_view_from_counties(counties), settings = NULL) {
  output$statewide_map <- renderLeaflet({
    build_cases_map(cases, counties, settings = settings, year_range = input$year_range,
      age_group = input$case_age_group, map_view = map_view)
  })
}