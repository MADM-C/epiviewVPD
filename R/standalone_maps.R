# Builds the Leaflet maps used by the dashboard, reports and R code. The Shiny
# modules pass inputs to these functions.
map_settings <- function(settings) {
  if (inherits(settings, "epiview_settings")) return(settings)
  if (is.null(settings)) default_settings() else prepare_dashboard_settings(settings)
}

map_bands <- function(settings, bands = NULL) {
  if (!is.null(bands)) return(coverage_bands(bands))
  offset <- settings$suppression$blurred_offset
  if (is.null(offset)) offset <- 0
  coverage_bands(settings$coverage_bins, offset)
}

map_sf <- function(x, name, allow_empty = TRUE) {
  if (is.null(x)) return(NULL)
  if (!inherits(x, "sf") && !"geometry" %in% names(x)) {
    stop(name, " must be spatial data with a geometry column.", call. = FALSE)
  }
  x <- sf::st_as_sf(x)
  if (!allow_empty && nrow(x) == 0) stop(name, " must contain at least one feature.", call. = FALSE)
  if (is.na(sf::st_crs(x))) stop(name, " must declare its coordinate reference system.", call. = FALSE)
  sf::st_transform(x, 4326)
}

map_points <- function(x, name = "Points") {
  x <- map_sf(x, name)
  if (is.null(x) || nrow(x) == 0) return(x)
  x <- x[!sf::st_is_empty(x), , drop = FALSE]
  if (nrow(x) && any(as.character(sf::st_geometry_type(x)) != "POINT")) {
    stop(name, " must contain POINT geometries.", call. = FALSE)
  }
  x
}

map_coverage_data <- function(x, bands) {
  if (is.null(x)) return(NULL)
  if (!"full_vax_pct" %in% names(x)) x$full_vax_pct <- rep(NA_character_, nrow(x))
  if (!"full_vax_pct_num" %in% names(x)) {
    x$full_vax_pct_num <- pct_number(x$full_vax_pct, bands$blurred_offset)
  }
  mask_not_reported(x)
}

map_text <- function(x) as.character(htmltools::htmlEscape(as.character(x)))

map_coverage_label <- function(x) {
  missing <- is.na(x) | trimws(as.character(x)) == ""
  ifelse(missing, "Data Not Available", format_vax_pct(x))
}

#' Build a county or school district coverage map
#'
#' @param map_data County or district sf data returned by [load_app_data()].
#' @param settings Dashboard settings, or a partial list. Use
#'   `list(map = list(basemap = NULL))` to omit network basemap tiles.
#' @param boundary Either `"county"` or `"district"`.
#' @param selected_id Optional polygon ID to highlight. County IDs are
#'   lower-case county names; district IDs are `district_id` values.
#' @param bands Optional coverage bands overriding settings.
#' @param map_view Optional prepared map view overriding settings.
#' @return A Leaflet htmlwidget.
#' @export
#' @examples
#' data <- load_app_data(example_data_dir())
#' map <- build_coverage_map(data$counties, list(map = list(basemap = NULL)))
build_coverage_map <- function(map_data, settings = NULL,
                               boundary = c("county", "district"), selected_id = NULL,
                               bands = NULL, map_view = NULL) {
  boundary <- match.arg(boundary)
  settings <- map_settings(settings)
  bands <- map_bands(settings, bands)
  map_data <- map_coverage_data(map_sf(map_data, "map_data", FALSE), bands)
  name_col <- if (boundary == "county") "county_name" else "district_name"
  if (!name_col %in% names(map_data) || (boundary == "district" && !"district_id" %in% names(map_data))) {
    stop("map_data is missing the boundary name or ID column.", call. = FALSE)
  }
  map_data$layer_id <- map_layer_ids(map_data, boundary)
  if (!"enroll" %in% names(map_data)) map_data$enroll <- rep(NA_real_, nrow(map_data))
  map_data$map_label <- lapply(seq_len(nrow(map_data)), function(i) {
    label <- paste0(map_text(map_data[[name_col]][i]), if (boundary == "county") " County" else "",
                    "<br>2-dose MMR Coverage (K\u201312): ",
                    map_text(map_coverage_label(map_data$full_vax_pct[i])),
                    "<br>Enrollment (K\u201312): ",
                    if (is.na(map_data$enroll[i])) "Data Not Available" else scales::comma(map_data$enroll[i]))
    for (col in intersect(c("students_of_color_pct", "frl_eligible_pct"), names(map_data))) {
      title <- if (col == "students_of_color_pct") "Students of Color" else "Free/Reduced Lunch Eligible"
      value <- map_data[[col]][i]
      label <- paste0(label, "<br>", title, " (K\u201312): ",
                      if (is.na(value)) "Data Not Available" else paste0(round(value, 1), "%"))
    }
    htmltools::HTML(label)
  })
  if (is.null(map_view)) map_view <- dashboard_map_view(settings$map, map_data)
  map_data <- map_display_data(map_data, map_view)
  map <- leaflet::leaflet(map_data, options = leaflet::leafletOptions(minZoom = 5, maxZoom = 9))
  map <- apply_map_view(map, map_view)
  map <- add_map_basemap(map, map_view)
  map <- leaflet::addPolygons(map, fillColor = coverage_band_color(map_data$full_vax_pct_num, bands),
                              fillOpacity = 0.7, color = "white", weight = 1,
                              layerId = map_data$layer_id, label = map_data$map_label)
  map <- add_coverage_legend(map, bands, paste0(if (boundary == "county") "County" else "District", " MMR (%)"),
                             missing_label = if (anyNA(map_data$full_vax_pct_num)) "Missing/Unknown", opacity = 0.7)
  if (!is.null(selected_id)) map <- add_coverage_highlight(map, map_data, selected_id, boundary, map_view)
  map
}

add_coverage_highlight <- function(map, map_data, selected_id, boundary = c("county", "district"), map_view = NULL) {
  boundary <- match.arg(boundary)
  map <- leaflet::clearGroup(map, "highlight")
  selected <- map_data[map_layer_ids(map_data, boundary) %in% selected_id, , drop = FALSE]
  if (!nrow(selected)) return(map)
  if (is.null(map_view)) map_view <- map_view_from_counties(map_data)
  selected <- map_display_data(selected, map_view)
  leaflet::addPolygons(map, data = selected, fill = FALSE, color = "orange", weight = 4,
                       opacity = 1, group = "highlight")
}

#' Build a facility coverage map for a selected county or district
#'
#' @param schools,facilities School and child care sf layers, optionally NULL.
#' @param counties County sf boundaries.
#' @param districts Optional school district sf boundaries.
#' @param settings,bands See [build_coverage_map()].
#' @param boundary_type Either `"county"` or `"district"`.
#' @param selected_county County name; NULL selects the first county.
#' @param selected_district District ID; NULL selects the first district.
#' @param point_type `"Schools"`, `"Child Cares"`, or `"Schools and Child Cares"`.
#' @param selected_id Optional school or facility ID to highlight. Prefix an
#'   ambiguous ID with `school:` or `facility:` to choose its type.
#' @return A Leaflet htmlwidget.
#' @export
build_facility_map <- function(schools = NULL, facilities = NULL, counties, districts = NULL,
                               settings = NULL, boundary_type = "county", selected_county = NULL,
                               selected_district = NULL, point_type = "Schools and Child Cares",
                               selected_id = NULL, bands = NULL) {
  boundary_type <- match.arg(boundary_type, c("county", "district"))
  point_type <- match.arg(point_type, c("Schools", "Child Cares", "Schools and Child Cares"))
  settings <- map_settings(settings)
  bands <- map_bands(settings, bands)
  counties <- map_sf(counties, "counties", FALSE)
  districts <- map_sf(districts, "districts")
  schools <- map_coverage_data(map_points(schools, "schools"), bands)
  facilities <- map_coverage_data(map_points(facilities, "facilities"), bands)
  if (boundary_type == "district") {
    if (is.null(districts) || !nrow(districts)) stop("District mode requires district boundaries.", call. = FALSE)
    if (is.null(selected_district)) selected_district <- districts$district_id[1]
    shape <- districts[districts$district_id %in% selected_district, , drop = FALSE]
  } else {
    if (is.null(selected_county)) selected_county <- counties$county_name[1]
    shape <- counties[tolower(counties$county_name) %in% tolower(selected_county), , drop = FALSE]
  }
  if (!nrow(shape)) stop("The selected boundary was not found.", call. = FALSE)
  in_area <- function(x, is_school = FALSE) {
    if (is.null(x) || !nrow(x)) return(x)
    if (boundary_type == "county" && "county_name" %in% names(x)) {
      keep <- tolower(x$county_name) %in% tolower(selected_county)
    } else {
      keep <- lengths(sf::st_intersects(x, sf::st_make_valid(shape))) > 0
      if (is_school && "district_id" %in% names(x)) keep <- keep | x$district_id %in% selected_district
    }
    x[keep, , drop = FALSE]
  }
  schools <- in_area(schools, TRUE)
  facilities <- in_area(facilities)
  if (!is.null(schools) && nrow(schools)) schools <- add_micro_offset(schools)
  view <- dashboard_map_view(settings$map, shape)
  schools <- map_display_data(schools, view)
  facilities <- map_display_data(facilities, view)
  map <- base_submap(map_display_data(shape, view), view)
  map <- add_point_layers(map, point_type, schools, facilities, bands)
  groups <- character(0)
  if (point_type == "Schools and Child Cares") {
    if (!is.null(schools) && nrow(schools)) groups <- c(groups, "Schools")
    if (!is.null(facilities) && nrow(facilities)) groups <- c(groups, "Child Cares")
    if (length(groups) == 2L) map <- leaflet::addControl(map, legend_html, position = "topleft", layerId = "type_legend")
  }
  if (boundary_type == "county" && !is.null(districts) && nrow(districts)) {
    overlay <- districts[lengths(sf::st_intersects(sf::st_make_valid(districts), sf::st_make_valid(shape))) > 0, , drop = FALSE]
    if (nrow(overlay)) {
      map <- county_district_overlay(map, map_display_data(overlay, view))
      groups <- c(groups, "School Districts")
    }
  }
  if (length(groups)) {
    map <- leaflet::addLayersControl(map, overlayGroups = groups,
                                     options = leaflet::layersControlOptions(collapsed = FALSE))
    if ("School Districts" %in% groups) map <- leaflet::hideGroup(map, "School Districts")
  }
  legend_title <- if (is.null(facilities) || !nrow(facilities)) "School MMR (%)" else "School/Child Care MMR (%)"
  map <- add_coverage_legend(map, bands, legend_title, "Missing/Unknown")
  if (!is.null(selected_id)) {
    selected_id <- as.character(selected_id)[1]
    id <- sub("^(school|facility):", "", selected_id)
    school <- if (point_type != "Child Cares" && !startsWith(selected_id, "facility:") &&
                  !is.null(schools) && "school_id" %in% names(schools)) {
      schools[schools$school_id %in% id, , drop = FALSE]
    } else NULL
    facility <- if (point_type != "Schools" && !startsWith(selected_id, "school:") &&
                    !is.null(facilities) && "facility_id" %in% names(facilities)) {
      facilities[facilities$facility_id %in% id, , drop = FALSE]
    } else NULL
    selected <- if (!is.null(school) && nrow(school)) school else facility
    if (!is.null(selected) && nrow(selected)) {
      map <- add_facility_highlight(map, selected[1, , drop = FALSE], point_type, view)
    }
  }
  map
}

add_facility_highlight <- function(map, selected, point_type = "Schools and Child Cares", map_view = NULL) {
  map <- leaflet::clearGroup(map, "highlight")
  selected <- map_points(selected)
  if (is.null(selected) || !nrow(selected)) return(map)
  selected <- map_display_data(selected, map_view)
  selected <- map_coverage_data(selected, coverage_bands())
  school <- "school_name" %in% names(selected)
  name <- if (school) selected$school_name else selected$facility_name
  coords <- sf::st_coordinates(selected)
  if (all(c("final_lon", "final_lat") %in% names(selected))) coords <- cbind(selected$final_lon, selected$final_lat)
  leaflet::addCircleMarkers(map, lng = coords[, 1], lat = coords[, 2],
    radius = if (point_type == "Schools and Child Cares") if (school) 12 else 9 else 9,
    color = "black", weight = 3, fillColor = if (school && point_type == "Schools and Child Cares") "gold" else "black",
    fillOpacity = 1, group = "highlight", popup = paste0("<b>", map_text(name), "</b><br>MMR: ",
                                                         map_text(map_coverage_label(selected$full_vax_pct))))
}

#' Build a map of historical case totals
#'
#' @param cases Standard case table from [load_app_data()]. Blank or withheld
#'   counts remain unknown; absent records count as zero unless settings choose
#'   `case_data$missing_records = "unknown"`.
#' @param counties County sf data from [load_app_data()].
#' @param settings,map_view See [build_coverage_map()].
#' @param year_range Optional inclusive pair of years; NULL uses all supplied years.
#' @param age_group Optional age group selection; NULL or `"All Ages"` uses all groups.
#' @return A Leaflet htmlwidget.
#' @export
build_cases_map <- function(cases, counties, settings = NULL, year_range = NULL,
                            age_group = NULL, map_view = NULL) {
  policy <- case_missing_records(settings, cases)
  settings <- map_settings(settings)
  settings$case_data$missing_records <- policy
  counties <- map_sf(counties, "counties", FALSE)
  if (!is.null(year_range) && (!is.numeric(year_range) || length(year_range) != 2 || anyNA(year_range) || any(!is.finite(year_range) | year_range != floor(year_range)) || year_range[1] > year_range[2])) {
    stop("year_range must be an increasing pair of whole, finite years.", call. = FALSE)
  }
  years <- if (is.null(year_range)) NULL else seq.int(year_range[1], year_range[2])
  if (identical(age_group, "All Ages")) age_group <- NULL
  totals <- case_totals(cases, counties = counties, years = years, age_groups = age_group,
                         by = "county_name", settings = settings)
  shapes <- dplyr::left_join(counties[, "county_name", drop = FALSE], totals, by = "county_name")
  shapes$case_label <- paste0(map_text(shapes$county_name), " County: ",
                              ifelse(is.na(shapes$n_cases), "Unknown/withheld", paste0(shapes$n_cases, " cases")))
  if (is.null(map_view)) map_view <- dashboard_map_view(settings$map, counties)
  circles <- shapes[!is.na(shapes$n_cases) & shapes$n_cases > 0, , drop = FALSE]
  if (nrow(circles)) sf::st_geometry(circles) <- case_map_locations(circles)
  shapes <- map_display_data(shapes, map_view)
  map <- leaflet::leaflet(shapes, options = leaflet::leafletOptions(minZoom = 5, maxZoom = 9))
  map <- add_map_basemap(apply_map_view(map, map_view), map_view)
  map <- leaflet::addPolygons(map, fillColor = ifelse(is.na(shapes$n_cases), "gray", "#f5f5f5"),
                              fillOpacity = 0.3, color = "#bdbdbd", weight = 1,
                              layerId = tolower(shapes$county_name), label = shapes$case_label)
  if (nrow(circles)) {
    circles <- map_display_data(circles, map_view)
    map <- leaflet::addCircleMarkers(map, data = circles, radius = pmin(10, sqrt(circles$n_cases) * 2),
      fillColor = "purple", color = "black", stroke = TRUE, fillOpacity = 0.85,
      layerId = paste0("case_", tolower(circles$county_name)),
      popup = circles$case_label, label = circles$case_label)
  }
  leaflet::addControl(map, htmltools::HTML(paste0("<div style='background:white;padding:6px'>",
    "<b>Measles Cases</b><br>Circle radius scales with square root of count; capped at 25 cases.",
    "<br>Gray counties: unknown/withheld<br>No circle: zero or unknown (see county label)</div>")), position = "topright")
}

# Marker location for each county's case total: a point inside the county,
# found in a local equal-area projection.
case_map_locations <- function(counties) {
  locations <- lapply(seq_len(nrow(counties)), function(i) {
    geometry <- sf::st_geometry(counties)[i]
    bounds <- map_view_from_counties(counties[i, , drop = FALSE])$bounds
    longitude <- map_geographic_longitude(mean(bounds[c(1, 3)]))
    latitude <- mean(bounds[c(2, 4)])
    projection <- paste0("+proj=laea +lat_0=", latitude, " +lon_0=", longitude,
                         " +datum=WGS84 +units=m +no_defs")
    location <- sf::st_point_on_surface(sf::st_transform(geometry, projection))
    sf::st_transform(location, 4326)[[1]]
  })
  sf::st_sfc(locations, crs = 4326)
}

prepare_proximity_facilities <- function(schools = NULL, facilities = NULL, bands = coverage_bands()) {
  part <- function(x, school) {
    x <- map_points(x)
    if (is.null(x) || !nrow(x)) return(NULL)
    x <- map_coverage_data(x, bands)
    name_col <- if (school) "school_name" else "facility_name"
    id_col <- if (school) "school_id" else "facility_id"
    if (!name_col %in% names(x)) stop("Facility data is missing ", name_col, ".", call. = FALSE)
    value <- function(col, default) if (col %in% names(x)) x[[col]] else rep(default, nrow(x))
    sf::st_sf(facility_name = as.character(x[[name_col]]),
      facility_id = as.character(value(id_col, NA_character_)),
      facility_type = if (school) "School" else "Daycare",
      full_vax_pct = as.character(x$full_vax_pct), full_vax_pct_num = x$full_vax_pct_num,
      partial_vax_pct = as.character(value("partial_vax_pct", NA_character_)),
      contact_info = as.character(value("contact_info", "")),
      reporting_status = as.character(value("reporting_status", NA_character_)),
      enrollment = as.numeric(value("enroll", NA_real_)), geometry = sf::st_geometry(x))
  }
  parts <- Filter(Negate(is.null), list(part(schools, TRUE), part(facilities, FALSE)))
  if (!length(parts)) return(sf::st_sf(facility_name = character(), facility_id = character(),
    facility_type = character(), full_vax_pct = character(), full_vax_pct_num = numeric(),
    partial_vax_pct = character(), contact_info = character(), reporting_status = character(),
    enrollment = numeric(), geometry = sf::st_sfc(crs = 4326)))
  do.call(rbind, parts)
}

#' Analyze nearby facilities
#'
#' @param facilities Spatial points with `facility_name` and `full_vax_pct`;
#'   optional `full_vax_pct_num` carries suppression-adjusted coverage. A full
#'   [load_app_data()] result combines its school and child care layers.
#' @param lat,lng Search latitude and longitude in degrees.
#' @param radius_miles Nonnegative search radius in miles.
#' @param threshold Coverage percentage threshold, between 0 and 100.
#' @return A list containing `center`, `radius_miles`, `threshold`,
#'   `nearby_facilities` and `low_vaccine_facilities`. Both tables retain geometry
#'   and include `distance_mi`; unknown coverage is excluded from low coverage.
#' @export
analyze_facility_proximity <- function(facilities, lat, lng, radius_miles, threshold) {
  scalar <- function(x, low, high) is.numeric(x) && length(x) == 1 && !is.na(x) && is.finite(x) && x >= low && x <= high
  if (!scalar(lat, -90, 90) || !scalar(lng, -180, 180)) stop("Search coordinates must be finite longitude/latitude values.", call. = FALSE)
  if (!scalar(radius_miles, 0, Inf)) stop("radius_miles must be one nonnegative number.", call. = FALSE)
  if (!scalar(threshold, 0, 100)) stop("threshold must be between 0 and 100.", call. = FALSE)
  # Removes names from the coordinates (sf returns named X/Y).
  lat <- as.numeric(lat)
  lng <- as.numeric(lng)
  radius_miles <- as.numeric(radius_miles)
  threshold <- as.numeric(threshold)
  if (is.list(facilities) && !is.data.frame(facilities) && any(c("schools", "facilities") %in% names(facilities))) {
    facilities <- prepare_proximity_facilities(facilities$schools, facilities$facilities)
  }
  facilities <- map_coverage_data(map_points(facilities, "facilities"), coverage_bands())
  if (is.null(facilities)) facilities <- prepare_proximity_facilities()
  if (!"facility_name" %in% names(facilities) && "school_name" %in% names(facilities)) facilities$facility_name <- facilities$school_name
  if (!"facility_name" %in% names(facilities)) {
    if (nrow(facilities)) stop("facilities must contain facility_name or school_name.", call. = FALSE)
    facilities$facility_name <- character(0)
  }
  if (!"facility_type" %in% names(facilities)) facilities$facility_type <- rep(if ("school_name" %in% names(facilities)) "School" else "Daycare", nrow(facilities))
  if (!"enrollment" %in% names(facilities) && "enroll" %in% names(facilities)) facilities$enrollment <- facilities$enroll
  distances <- numeric(0)
  if (nrow(facilities)) {
    coords <- sf::st_coordinates(facilities)
    lat2 <- coords[, 2] * pi / 180
    dlng <- (coords[, 1] - lng) * pi / 180
    dlat <- lat2 - lat * pi / 180
    a <- sin(dlat / 2)^2 + cos(lat * pi / 180) * cos(lat2) * sin(dlng / 2)^2
    a <- pmax(0, pmin(1, a))
    distances <- 6371 * 2 * atan2(sqrt(a), sqrt(1 - a)) / 1.609344
  }
  facilities$distance_mi <- round(distances, 1)
  nearby <- facilities[is.finite(distances) & distances <= radius_miles, , drop = FALSE]
  low <- nearby[!is.na(nearby$full_vax_pct_num) & nearby$full_vax_pct_num < threshold, , drop = FALSE]
  list(center = list(lat = lat, lng = lng), radius_miles = radius_miles,
       threshold = threshold, nearby_facilities = nearby, low_vaccine_facilities = low)
}

add_proximity_result <- function(map, result, popup_title = "Search Point", map_view = NULL) {
  # Coordinates of the search point, as plain numbers.
  lat <- as.numeric(result$center$lat)
  lng <- map_display_longitude(as.numeric(result$center$lng), map_view)
  radius_miles <- as.numeric(result$radius_miles)
  radius_km <- radius_miles * 1.609344
  zoom <- if (radius_km <= .1) 19 else if (radius_km <= .2) 17 else if (radius_km <= .5) 16 else if (radius_km <= 1) 15 else if (radius_km <= 2) 14 else if (radius_km <= 5) 13 else if (radius_km <= 10) 12 else 10
  map <- leaflet::clearGroup(map, "highlighted_facilities")
  map <- leaflet::removeMarker(map, "search_center")
  map <- leaflet::removeShape(map, "search_radius")
  map <- leaflet::removeControl(map, "search_view_notice")
  limits <- map_view$max_bounds
  if (!is.null(limits) && (lng < limits[1] || lng > limits[3] || lat < limits[2] || lat > limits[4])) {
    map <- leaflet::addControl(map, htmltools::HTML(paste0(
      "<div style='background:white;padding:6px;max-width:260px'>",
      "Search point is outside the map's viewing limits. Results use the entered coordinates.</div>")),
      position = "topright", layerId = "search_view_notice")
  }
  map <- leaflet::setView(map, lng = lng, lat = lat, zoom = zoom)
  map <- leaflet::addCircleMarkers(map, lng = lng, lat = lat, radius = 6,
    color = "#003865", fillOpacity = 1, layerId = "search_center",
    popup = paste0(map_text(popup_title), "<br>Low-vaccine facilities: ", nrow(result$low_vaccine_facilities)))
  map <- leaflet::addCircles(map, lng = lng, lat = lat,
    radius = radius_miles * 1609.344, layerId = "search_radius", color = "red", fillOpacity = 0.1)
  add_facility_markers(map, map_display_data(result$low_vaccine_facilities, map_view), radius = 5, color = "red", fill_opacity = 0.9,
                        group = "highlighted_facilities", low_vaccine = TRUE)
}

#' Build a proximity search map
#'
#' @param schools,facilities,counties,districts,settings See [build_facility_map()].
#' @param healthcare_centers Optional healthcare sf layer with `name` or `healthcare_name`.
#' @param search_center Optional named `c(lng = ..., lat = ...)` or list with these names.
#' @param radius_miles,threshold Optional search parameters; the radius defaults
#'   to 10 miles and the threshold comes from settings.
#' @param result Optional result from [analyze_facility_proximity()], overriding search arguments.
#' @param map_view See [build_coverage_map()].
#' @return A Leaflet htmlwidget, including the supplied search result if any.
#' @export
build_proximity_map <- function(schools = NULL, facilities = NULL, counties, districts = NULL,
                                healthcare_centers = NULL, settings = NULL, search_center = NULL,
                                radius_miles = NULL, threshold = NULL, result = NULL, map_view = NULL) {
  settings <- map_settings(settings)
  counties <- map_sf(counties, "counties", FALSE)
  districts <- map_sf(districts, "districts")
  healthcare <- map_points(healthcare_centers, "healthcare_centers")
  combined <- prepare_proximity_facilities(schools, facilities, map_bands(settings))
  map_view <- proximity_map_view(map_view, counties, settings)
  map <- leaflet::leaflet(options = leaflet::leafletOptions(minZoom = 0, maxZoom = 20, maxBoundsViscosity = 1))
  map <- add_map_basemap(apply_map_view(map, map_view), map_view)
  map <- limit_proximity_zoom(map, map_view)
  map <- leaflet::addPolygons(map, data = map_display_data(counties, map_view), color = "black", weight = 1)
  groups <- character(0)
  if (nrow(combined)) {
    map <- add_facility_markers(map, map_display_data(combined, map_view))
    groups <- c(groups, "School/Child Care Markers")
  }
  if (!is.null(healthcare) && nrow(healthcare)) {
    if (!"healthcare_name" %in% names(healthcare)) healthcare$healthcare_name <- healthcare$name
    map <- add_healthcare_markers(map, map_display_data(healthcare, map_view))
    groups <- c(groups, "Healthcare Centers")
  }
  if (!is.null(districts) && nrow(districts)) {
    map <- county_district_overlay(map, map_display_data(districts, map_view))
    groups <- c(groups, "School Districts")
  }
  if (length(groups)) {
    map <- leaflet::addLayersControl(map, overlayGroups = groups, options = leaflet::layersControlOptions(collapsed = FALSE))
    for (group in intersect(groups, c("Healthcare Centers", "School Districts"))) map <- leaflet::hideGroup(map, group)
  }
  if (is.null(result) && !is.null(search_center)) {
    if (is.null(radius_miles)) radius_miles <- 10
    if (is.null(threshold)) threshold <- settings$proximity$default_threshold
    if (is.null(names(search_center)) || !all(c("lng", "lat") %in% names(search_center))) stop("search_center needs named lng and lat values.", call. = FALSE)
    result <- analyze_facility_proximity(combined, as.numeric(search_center[["lat"]]),
      as.numeric(search_center[["lng"]]), radius_miles, threshold)
  }
  if (!is.null(result)) map <- add_proximity_result(map, result, map_view = map_view)
  map
}
