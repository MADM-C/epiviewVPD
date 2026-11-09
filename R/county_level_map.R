# Server for the county/district coverage map. Drawing code is in standalone_maps.R.
countyMapServer <- function(input, output, session, counties, bands, districts = NULL,
                            map_view = map_view_from_counties(counties), settings = NULL) {
  output$county_map <- renderLeaflet({
    district_mode <- isTRUE(input$boundary_type == "district") && !is.null(districts) && nrow(districts) > 0
    build_coverage_map(if (district_mode) districts else counties,
      boundary = if (district_mode) "district" else "county", bands = bands, map_view = map_view,
      settings = settings)
  })
  observeEvent(input$county_map_shape_click, {
    clicked <- input$county_map_shape_click$id
    if (isTRUE(input$boundary_type == "district")) {
      updateSelectInput(session, "selected_district", selected = clicked)
    } else {
      matched <- counties$county_name[map_layer_ids(counties, "county") == clicked]
      if (length(matched) == 1) updateSelectInput(session, "selected_county", selected = matched)
    }
  })
  observeEvent(input$selected_county, {
    req(input$selected_county)
    if (!isTRUE(input$boundary_type == "district"))
      add_coverage_highlight(leafletProxy("county_map", session), counties,
        tolower(input$selected_county), "county", map_view)
  })
  observeEvent(input$selected_district, {
    req(input$selected_district)
    if (isTRUE(input$boundary_type == "district") && !is.null(districts))
      add_coverage_highlight(leafletProxy("county_map", session), districts,
        input$selected_district, "district", map_view)
  })
  output$county_map_title <- renderUI(coverage_map_title(counties))
}
