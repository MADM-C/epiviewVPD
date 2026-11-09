# Facility search and selection for the maps and detail outputs.
facilitySelectionServer <- function(input, output, session, selected_school_id,
                                   schools, facilities, counties, districts = NULL,
                                   map_enabled = FALSE) {
  scope <- reactive({
    boundary <- if (is.null(input$boundary_type)) "county" else input$boundary_type
    list(
      mode = if (is.null(input$map_mode)) "county" else input$map_mode,
      boundary = boundary,
      area = if (isTRUE(boundary == "district")) input$selected_district else input$selected_county,
      points = input$point_type
    )
  })
  choices <- reactive({
    current <- scope()
    if (!isTRUE(current$mode == "county")) return(character())
    get_location_choices_data(TRUE, current$boundary, current$points,
      if (isTRUE(current$boundary == "district")) current$area else NULL,
      if (!isTRUE(current$boundary == "district")) current$area else NULL,
      districts, counties, schools, facilities)
  })
  output$school_daycare_selector <- renderUI({
    has_childcares <- !is.null(facilities) && nrow(facilities) > 0
    selectizeInput("selected_location", if (has_childcares) "School/Child Care:" else "School:",
      choices = c("", choices()), selected = "",
      options = list(placeholder = if (has_childcares) "Search school or child care..." else "Search school...",
                     maxOptions = 1000))
  })

  # When the county or district changes, clears the selection and ignores the
  # old dropdown value until a new facility is picked.
  blocked_location <- NULL
  observeEvent(scope(), {
    blocked_location <<- selected_school_id()
    if (is.null(blocked_location)) blocked_location <<- input$selected_location
    selected_school_id(NULL)
    updateSelectizeInput(session, "selected_location", selected = "")
  }, ignoreInit = TRUE, priority = 100)

  observeEvent(input$selected_location, {
    id <- input$selected_location
    if (!length(id) || is.na(id[1]) || !nzchar(id[1])) {
      blocked_location <<- NULL
      selected_school_id(NULL)
    } else if (!identical(id, blocked_location) && id %in% unname(choices())) {
      blocked_location <<- NULL
      selected_school_id(id)
    } else {
      selected_school_id(NULL)
    }
  }, ignoreNULL = FALSE)

  if (isTRUE(map_enabled)) observeEvent(input$sub_map_marker_click, {
    id <- input$sub_map_marker_click$id
    if (length(id) == 1L && !is.na(id) && id %in% unname(choices())) {
      blocked_location <<- NULL
      selected_school_id(id)
      updateSelectizeInput(session, "selected_location", selected = id)
    }
  })
}
