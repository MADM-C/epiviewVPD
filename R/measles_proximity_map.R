# Server for the proximity map: inputs and events. Drawing code is in standalone_maps.R.
proximityMapServer <- function(schools, facilities, counties, healthcare_center_data,
  districts = NULL, map_view = NULL, output, input, session, draw_map = TRUE, settings = NULL) {
  combined_facilities <- reactive(prepare_proximity_facilities(schools(), facilities()))
  healthcare_centers <- reactive(healthcare_center_data())
  view <- reactive(proximity_map_view(map_view, counties(), settings))
  values <- reactiveValues(clicked_point = NULL, result = NULL, popup_title = "Search Point")
  radius_miles <- reactive({ req(input$radius_miles); input$radius_miles })
  threshold <- reactive({ req(input$vaccine_threshold); input$vaccine_threshold })
  run_search <- function(lat, lng, title = "Search Point") {
    values$clicked_point <- list(lat = lat, lng = lng)
    values$popup_title <- title
    values$result <- analyze_facility_proximity(combined_facilities(), lat, lng,
      radius_miles(), threshold())
  }
  observe({
    data <- combined_facilities()
    choices <- if (!is.null(data) && nrow(data)) stats::setNames(seq_len(nrow(data)), trimws(data$facility_name)) else character()
    choices <- choices[!is.na(names(choices)) & nzchar(names(choices))]
    choices <- choices[order(tolower(names(choices)))]
    updateSelectizeInput(session, "selected_facility", choices = choices, selected = "",
      server = TRUE, options = list(placeholder = "Type a School/Child Care name...", maxOptions = max(1, length(choices))))
  })
  observeEvent(input$selected_facility, {
    req(input$selected_facility)
    data <- combined_facilities()
    index <- suppressWarnings(as.integer(input$selected_facility))
    req(length(index) == 1, !is.na(index), index >= 1, index <= nrow(data))
    selected <- data[index, , drop = FALSE]
    coordinates <- sf::st_coordinates(selected)
    req(nrow(coordinates) > 0)
    run_search(coordinates[1, 2], coordinates[1, 1], paste("Selected:", selected$facility_name))
  })
  observeEvent(input$search_address_btn, {
    req(input$address_input)
    notification <- showNotification("Searching address...", duration = NULL, closeButton = FALSE)
    on.exit(removeNotification(notification), add = TRUE)
    tryCatch({
      county_data <- counties()
      bounds <- if (inherits(county_data, "sf")) suppressWarnings(sf::st_bbox(county_data)) else rep(NA_real_, 4)
      query <- if (all(is.finite(bounds))) list(viewbox = search_area(county_data), bounded = 1) else list()
      found <- tidygeocoder::geo(address = input$address_input, method = "osm",
        full_results = FALSE, custom_query = query)
      if (!is.null(found) && nrow(found) && is.finite(found$lat[1]) && is.finite(found$long[1])) {
        run_search(found$lat[1], found$long[1], paste("Address:", input$address_input))
      } else showNotification("Address not found. Please add a city or ZIP code.", type = "error")
    }, error = function(error) showNotification(paste("Geocoding failed:", error$message), type = "error"))
  })
  observeEvent(input$search_coordinates_btn, {
    req(input$search_latitude, input$search_longitude)
    run_search(input$search_latitude, input$search_longitude, "Coordinate Search Point")
  })
  if (isTRUE(draw_map)) {
    output$proximity_map <- renderLeaflet({
      build_proximity_map(schools(), facilities(), counties(), districts,
        healthcare_centers = healthcare_centers(), map_view = view(), settings = settings)
    })
    observeEvent(input$proximity_map_click, {
      click <- input$proximity_map_click
      run_search(click$lat, map_geographic_longitude(click$lng), "Manual Search Point")
    })
    observeEvent(values$result, {
      req(!is.null(values$result))
      add_proximity_result(leafletProxy("proximity_map", session), values$result, values$popup_title, view())
    })
  }
  observeEvent(list(input$radius_miles, input$vaccine_threshold), {
    center <- values$clicked_point
    if (!is.null(center)) run_search(center$lat, center$lng, values$popup_title)
  }, ignoreInit = TRUE)
  list(clicked_point = reactive(values$clicked_point), radius_km = reactive(radius_miles() * 1.609344),
    low_vaccine_threshold = threshold,
    low_vaccine_facilities_data = reactive(if (is.null(values$result)) NULL else values$result$low_vaccine_facilities))
}
