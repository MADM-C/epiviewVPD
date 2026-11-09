# Server for the facility map.
subMapServer <- function(input, output, session, schools, facilities,
                         counties, selected_school_id, format_vax_pct,
                         districts = NULL, bands = coverage_bands(), settings = NULL) {
  observeEvent(selected_school_id(), {
    if (is.null(selected_school_id())) {
      leaflet::clearGroup(leafletProxy("sub_map", session), "highlight")
      return()
    }
    area <- get_location_choices_data(FALSE, input$boundary_type, input$point_type,
      input$selected_district, input$selected_county, districts, counties, schools, facilities)
    if (inherits(area$schools, "sf")) {
      valid <- !sf::st_is_empty(area$schools)
      area$schools <- add_micro_offset(area$schools[valid, , drop = FALSE])
    }
    selected <- select_facility(selected_school_id(),
      if (!isTRUE(input$point_type == "Child Cares")) area$schools else NULL,
      if (!isTRUE(input$point_type == "Schools")) area$childcares else NULL)
    if (!is.null(selected)) {
      view <- dashboard_map_view(map_settings(settings)$map, area$boundary)
      add_facility_highlight(leafletProxy("sub_map", session), selected$data, input$point_type, view)
    }
  }, ignoreNULL = FALSE)
  output$sub_map <- renderLeaflet({
    req(if (isTRUE(input$boundary_type == "district")) input$selected_district else input$selected_county)
    build_facility_map(schools, facilities, counties, districts, settings = settings,
      boundary_type = if (is.null(input$boundary_type)) "county" else input$boundary_type,
      selected_county = input$selected_county, selected_district = input$selected_district,
      point_type = if (is.null(input$point_type)) "Schools and Child Cares" else input$point_type, bands = bands)
  })
  output$submap_title <- renderUI({
    submap_title_vax(input$boundary_type, input$selected_district, districts,
      input$selected_county, counties, has_childcares = !is.null(facilities) && nrow(facilities) > 0)
  })
}
