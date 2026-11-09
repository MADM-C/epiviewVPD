# ============================================================
# APP SERVER FUNCTIONS
# ============================================================

# Helpers used by the server modules.

# ============================================================
# HELPER: resolve school_id from either reactive or dropdown
# ============================================================
resolve_school_id <- function(school_id_reactive, selected_location, school_data = NULL) {
  school_id <- school_id_reactive()
  if (is.null(school_id) && !is.null(selected_location)) {
    school_id <- school_data |>
      filter(school_name == selected_location) |>
      pull(school_id) |>
      _[1]
  }
  school_id
}

# ============================================================
# HELPER: Check for non-responding facilities
# ============================================================

is_nonresponder <- function(school_id, school_data = NULL) {
  if (is.null(school_data) || !"reporting_status" %in% names(school_data)) return(FALSE)
  rows <- which(as.character(school_data$school_id) == as.character(school_id))
  length(rows) > 0 && any(school_data$reporting_status[rows] == "not_reported", na.rm = TRUE)
}

# ============================================================
# HELPER: Format percentages cleanly
# ============================================================
format_vax_pct <- function(x) {
  ifelse(
    is.na(x),
    "NA",
    ifelse(grepl("^[<>]", x),
           paste0(x, ifelse(grepl("%$", x), "", "%")), # if already has %, don't add
           paste0(suppressWarnings(as.numeric(gsub("[^0-9.]", "", x))), "%")
    )
  )
}

# ============================================================
# STATEWIDE K–12 MMR COVERAGE
# ============================================================
# Statewide MMR rate: total vaccinated students divided by total enrolled
# students across all schools. Shown above the county map.
# ============================================================

calc_statewide_k12 <- function(df) {
  if (is.null(df) || nrow(df) == 0 || !all(c("full_vax", "enroll") %in% names(df))) {
    return(NA)
  }
  # NA when any school has unknown counts or is not reporting.
  if (any(is.na(df$full_vax) | is.na(df$enroll)) ||
      ("reporting_status" %in% names(df) && any(df$reporting_status == "not_reported", na.rm = TRUE))) return(NA_real_)
  vaccinated <- sum(df$full_vax)
  students <- sum(df$enroll)

  if (students == 0) {
    return(NA)
  }

  round(100 * vaccinated / students, 1)
}

# ============================================================
# HELPER: Spatial-Based Filter
# ============================================================
# Finds the facilities in sf_data that fall within the boundary (county or
# school district).

# sf_data = spatial dataset
# shape = boundary shape (i.e. county or district)

filter_spatial_safe <- function(sf_data, shape) {
  tryCatch(
    sf::st_filter(sf::st_make_valid(sf_data), shape),
    error = function(e) sf_data[0, ]
  )
}

# ============================================================
# HELPER: Create list of facility choices to use in selectize
# dropdown, not including geometry data
# ============================================================

extract_facility_choices <- function(school_data = NULL, childcare_data = NULL, point_type) {
  choices <- character()
  for (kind in c("school", "facility")) {
    if (kind == "school" && isTRUE(point_type == "Child Cares")) next
    if (kind == "facility" && isTRUE(point_type == "Schools")) next
    data <- if (kind == "school") school_data else childcare_data
    id <- paste0(kind, "_id")
    label <- paste0(kind, "_name")
    if (is.null(data) || !all(c(id, label) %in% names(data))) next
    valid <- !is.na(data[[id]]) & !is.na(data[[label]]) & nzchar(data[[label]])
    labels <- as.character(data[[label]][valid])
    choices <- c(choices, stats::setNames(paste0(kind, ":", data[[id]][valid]), labels))
  }
  choices[order(tolower(names(choices)))]
}
# ============================================================
# HELPER: Combine Spatial & Id-Based Filtering
# ============================================================
# Finds the facilities in the selected county or district, by boundary shape
# and by ID, for the facility dropdown and maps.

get_location_choices_data <- function(drop_sf,
                                      # drop_sf: TRUE to drop geometry (for dropdowns), FALSE to keep it (for maps)
                                      boundary_type,
                                      point_type,
                                      selected_district,
                                      selected_county,
                                      district_data = NULL,
                                      county_data = NULL,
                                      school_data = NULL,
                                      childcare_data = NULL) {
  is_district_mode <- !is.null(boundary_type) && boundary_type == "district"

  if (is_district_mode) {
    if (!length(selected_district) || is.null(district_data)) {
      if (isTRUE(drop_sf)) return(character())
      return(list(boundary = county_data[0, ], schools = school_data[0, ], childcares = childcare_data[0, ]))
    }

    # Extract & validate shape
    district_shape <- district_data |>
      dplyr::filter(district_id == selected_district)
    valid_shape <- tryCatch(sf::st_make_valid(district_shape), error = function(e) district_shape)

    # Filter spatial + ID matches
    spatial_schools <- filter_spatial_safe(school_data, valid_shape)
    id_schools <- dplyr::filter(school_data, district_id == selected_district)

    schools_filtered <- dplyr::bind_rows(spatial_schools, id_schools) |>
      dplyr::distinct(school_id, .keep_all = TRUE)

    childcares_filtered <- filter_spatial_safe(childcare_data, valid_shape)

    boundary_choice <- district_shape
  } else {
    # County mode
    if (!length(selected_county) || is.null(county_data)) {
      if (isTRUE(drop_sf)) return(character())
      return(list(boundary = county_data[0, ], schools = school_data[0, ], childcares = childcare_data[0, ]))
    }
    county_lower_selected <- tolower(selected_county)

    boundary_choice <- county_data |> dplyr::filter(tolower(county_name) == county_lower_selected)

    schools_filtered <- school_data |>
      dplyr::filter(tolower(county_name) == county_lower_selected)

    childcares_filtered <- childcare_data |>
      dplyr::filter(tolower(county_name) == county_lower_selected)
  }

  if (isTRUE(drop_sf)) {
    # create facility choices for drop-down
    extract_facility_choices(school_data = schools_filtered,
                             childcare_data = childcares_filtered,
                             point_type = point_type)
  } else {
    # retain geometry info to construct maps
    list(boundary = boundary_choice, schools = schools_filtered, childcares = childcares_filtered)
  }
}
