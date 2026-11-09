widget_methods <- function(widget) vapply(widget$x$calls, function(call) call$method, "")
widget_calls <- function(widget, method) {
  Filter(function(call) identical(call$method, method), widget$x$calls)
}
full_example_data <- function() load_app_data(example_data_dir("full"))
no_basemap_settings <- function() prepare_dashboard_settings(list(map = list(basemap = NULL)))

test_that("every map type builds without a Shiny session and leaves the data unchanged", {
  data <- full_example_data()
  before <- serialize(data, NULL)
  settings <- no_basemap_settings()
  maps <- list(
    build_coverage_map(data$counties, settings, selected_id = tolower(data$counties$county_name[1])),
    build_coverage_map(data$districts, settings, "district", selected_id = data$districts$district_id[1]),
    build_facility_map(data$schools, data$facilities, data$counties, data$districts, settings,
                       point_type = "Schools", selected_id = data$schools$school_id[1]),
    build_facility_map(data$schools, data$facilities, data$counties, data$districts, settings,
                       point_type = "Child Cares", selected_id = data$facilities$facility_id[1]),
    build_facility_map(data$schools, data$facilities, data$counties, data$districts, settings,
                       boundary_type = "district"),
    build_cases_map(data$cases, data$counties, settings),
    build_proximity_map(data$schools, data$facilities, data$counties, data$districts,
                         data$healthcare_centers, settings)
  )
  for (map in maps) {
    expect_s3_class(map, "leaflet")
    expect_false(any(widget_methods(map) %in% c("addTiles", "addProviderTiles")))
  }
  expect_identical(serialize(data, NULL), before)
  expect_length(widget_calls(maps[[1]], "addPolygons"), 2L)
  expect_length(widget_calls(maps[[3]], "addCircleMarkers"), 2L)
})

test_that("a NULL basemap removes map tiles, even when settings are prepared twice", {
  data <- full_example_data()
  settings <- no_basemap_settings()
  expect_identical(prepare_dashboard_settings(settings), settings)
  expect_false("addProviderTiles" %in% widget_methods(build_coverage_map(data$counties, settings)))
  expect_true("addProviderTiles" %in% widget_methods(build_coverage_map(data$counties)))
})

test_that("proximity search treats only measured values as low coverage", {
  points <- sf::st_as_sf(data.frame(
    facility_id = c("zero", "withheld", "not_reported", "outside"),
    facility_name = c("Measured Zero", "Withheld", "No report", "Far away"),
    full_vax_pct = c("0", NA, "0", "0"),
    reporting_status = c("reported", "reported", "not_reported", "reported"),
    longitude = c(-75, -75, -75, -80), latitude = c(38, 38, 38, 38)
  ), coords = c("longitude", "latitude"), crs = 4326)
  before <- serialize(points, NULL)
  result <- analyze_facility_proximity(points, 38, -75, 1, 90)
  expect_equal(result$nearby_facilities$facility_id, c("zero", "withheld", "not_reported"))
  expect_equal(result$low_vaccine_facilities$facility_id, "zero")
  expect_equal(result$nearby_facilities$distance_mi, rep(0, 3))
  expect_identical(serialize(points, NULL), before)
  expect_match(as.character(facility_labels(points[1, ])), "0%")
  expect_match(as.character(facility_labels(points[3, ])), "Data Not Available")
  expect_error(analyze_facility_proximity(points, 100, -75, 1, 90), "coordinates")
  expect_error(analyze_facility_proximity(points, 38, -75, -1, 90), "radius_miles")
  expect_error(analyze_facility_proximity(points, 38, -75, 1, 101), "threshold")
})

test_that("a proximity search map shows the radius and the results, however it is built", {
  data <- full_example_data()
  center <- sf::st_coordinates(data$facilities)[1, ]
  result <- analyze_facility_proximity(data$facilities, center[["Y"]], center[["X"]], 5, 100)
  widget <- build_proximity_map(facilities = data$facilities, counties = data$counties,
    settings = no_basemap_settings(), result = result)
  expect_length(widget_calls(widget, "addCircles"), 1L)
  expect_true(length(widget_calls(widget, "addCircleMarkers")) >= 2L)
  expect_equal(widget_calls(widget, "addCircles")[[1]]$args[[3]], 5 * 1609.344)
  direct <- build_proximity_map(facilities = data$facilities, counties = data$counties,
    settings = no_basemap_settings(), search_center = c(lng = center[["X"]], lat = center[["Y"]]),
    radius_miles = 5, threshold = 100)
  expect_equal(widget_methods(direct), widget_methods(widget))
  combined <- analyze_facility_proximity(data, center[["Y"]], center[["X"]], 10000, 100)
  expect_true(all(c("School", "Daycare") %in% combined$nearby_facilities$facility_type))
})

test_that("named coordinates from sf become plain numbers on the map", {
  data <- full_example_data()
  location <- sf::st_coordinates(data$schools)[1, ]
  result <- analyze_facility_proximity(data, lat = location[2], lng = location[1],
    radius_miles = c(radius = 10), threshold = c(threshold = 95))
  expect_identical(result$center$lat, unname(location[2]))
  expect_identical(result$center$lng, unname(location[1]))
  expect_identical(result$radius_miles, 10)
  expect_identical(result$threshold, 95)
  # results whose coordinates still have sf names
  result$center <- list(lat = location[2], lng = location[1])
  result$radius_miles <- c(radius = 10)
  map <- build_proximity_map(data$schools, data$facilities, data$counties,
    settings = no_basemap_settings(), result = result)
  expect_identical(map$x$setView[[1]], unname(location[2:1]))
  expect_null(names(map$x$setView[[1]]))
  center <- Filter(function(call) identical(call$method, "addCircleMarkers") &&
    identical(call$args[[4]], "search_center"), map$x$calls)[[1]]
  expect_identical(center$args[[1]], unname(location[2]))
  expect_identical(center$args[[2]], unname(location[1]))
  expect_warning(htmlwidgets::saveWidget(map, tempfile(fileext = ".html"),
    selfcontained = FALSE), NA)
})

test_that("a proximity map with no points has no layer control", {
  data <- full_example_data()
  widget <- build_proximity_map(counties = data$counties, settings = no_basemap_settings())
  expect_false("addLayersControl" %in% widget_methods(widget))
  expect_false("addCircleMarkers" %in% widget_methods(widget))
  expect_s3_class(build_facility_map(counties = data$counties, settings = no_basemap_settings()), "leaflet")
  expect_equal(nrow(analyze_facility_proximity(NULL, 38, -75, 1, 90)$low_vaccine_facilities), 0L)
})

test_that("case map circles scale with the number of cases", {
  data <- full_example_data()
  cases <- data.frame(county_name = data$counties$county_name, year = 2024,
                       age_group = "All", n_cases = seq_len(nrow(data$counties)))
  expect_warning(widget <- build_cases_map(cases, data$counties, no_basemap_settings(), c(2024, 2024)), NA)
  circles <- widget_calls(widget, "addCircleMarkers")
  expect_length(circles, 1L)
  expect_equal(circles[[1]]$args[[3]], pmin(10, sqrt(cases$n_cases) * 2))
})

test_that("case maps tell zero, missing and withheld counts apart", {
  data <- full_example_data()
  cases <- data.frame(county_name = data$counties$county_name[1], year = 2024,
                       age_group = "All", n_cases = 0)
  unknown_settings <- prepare_dashboard_settings(list(map = list(basemap = NULL),
                                                      case_data = list(missing_records = "unknown")))
  unknown <- build_cases_map(cases, data$counties, unknown_settings, c(2024, 2024))
  labels <- widget_calls(unknown, "addPolygons")[[1]]$args
  text <- paste(unlist(labels), collapse = " ")
  expect_match(text, "0 cases", fixed = TRUE)
  expect_match(text, "Unknown/withheld", fixed = TRUE)
  attr(cases, "missing_records") <- "zero"
  sparse <- build_cases_map(cases, data$counties, list(map = list(basemap = NULL)), c(2024, 2024))
  text <- paste(unlist(widget_calls(sparse, "addPolygons")[[1]]$args), collapse = " ")
  expect_false(grepl("Unknown/withheld", text, fixed = TRUE))
  cases$n_cases <- NA_real_
  withheld <- build_cases_map(cases, data$counties, list(map = list(basemap = NULL)), c(2024, 2024))
  text <- paste(unlist(widget_calls(withheld, "addPolygons")[[1]]$args), collapse = " ")
  expect_match(text, "Unknown/withheld", fixed = TRUE)
})
