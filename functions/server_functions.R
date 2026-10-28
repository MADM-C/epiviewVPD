# ============================================================
# APP SERVER FUNCTIONS
# ============================================================

# This script contains functions that were initially embedded within the
# server.R script.

# ============================================================
# HELPER: resolve school_id from either reactive or dropdown
# ============================================================
resolve_school_id <- function(school_id_reactive, selected_location, school_data = NULL) {
  school_id <- school_id_reactive()
  if (is.null(school_id) && !is.null(selected_location)) {
    school_id <- school_data |>
      filter(school_name == selected_location) |>
      pull(mde_school_id) |>
      _[1]
  }
  school_id
}

# ============================================================
# HELPER: Check for non-responding facilities
# ============================================================

is_nonresponder <- function(school_id, school_data = NULL) {
  school_data |>
    sf::st_drop_geometry() |>
    dplyr::filter(mde_school_id == school_id) |> # need adaptable variable names
    dplyr::mutate(non_responder = ifelse((full_vax_pct == 0 & !is.na(full_vax_pct)) &
                                           (partial_vax_pct == 0 & !is.na(partial_vax_pct)), TRUE, FALSE)) |>
    pull(non_responder)
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
    ) # strips non-numeric
  )
}

# ============================================================
# STATEWIDE K–12 MMR COVERAGE
# ============================================================
# This helper function calculates the statewide MMR vaccination
# rate across all schools. The calculation is enrollment-weighted,
# meaning total vaccinated students divided by total enrolled
# students across the entire dataset.
#
# This value is displayed above the county map to provide
# statewide context when users are viewing county-level coverage.
# ============================================================

calc_statewide_k12 <- function(df) {
  df <- df |>
    dplyr::filter(!is.na(full_vax), !is.na(total_enrollment))

  if (nrow(df) == 0) {
    return(NA)
  }

  vaccinated <- sum(df$full_vax, na.rm = TRUE)
  students <- sum(df$total_enrollment, na.rm = TRUE)

  if (students == 0) {
    return(NA)
  }

  round(100 * vaccinated / students, 1)
}

statewide_k12_rate <- reactive({
  calc_statewide_k12(school_demo_joined)
  # this needs to be updated to draw from the correct data, but it involves updating the data wrangling script
})

# ============================================================
# HELPER: Spatial-Based Filter
# ============================================================
# This function looks at the geometries of all facilities in
# the supplied spatial dataset and finds which facilities fall
# within the specified boundary (county or school district)

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
  # Clean sf geometry if present
  if (inherits(school_data, "sf")) {
    school_data <- sf::st_drop_geometry(school_data)
  }
  if (inherits(childcare_data, "sf")) {
    childcare_data <- sf::st_drop_geometry(childcare_data)
  }

  if (isTRUE(point_type == "Schools")) {
    school_data |>
      dplyr::pull(school_name) |>
      unique() |>
      sort()
  } else if (isTRUE(point_type == "Child Cares")) {
    df <- childcare_data |>
      dplyr::filter(!is.na(idsch), !is.na(daycare_name))

    lc <- stats::setNames(as.character(df$idsch), df$daycare_name) # need adaptable variable names
    lc[order(names(lc))]
  } else {
    # "All" or unselected mode
    c(
      dplyr::pull(school_data, school_name),
      dplyr::pull(childcare_data, daycare_name)
    ) |>
      unique() |>
      sort()
  }
}

# ============================================================
# HELPER: Combine Spatial & Id-Based Filtering
# ============================================================
# This function looks at the type of boundary view that the
# user selected (county or district), extracts the shape
# of that boundary and then use filter_spatial_safe to
# identify the facilities that fall within the boundary
# to provide a complete list of facility options

get_location_choices_data <- function(drop_sf,
                                      # drop_sf: should the geometry info be dropped (T/F)?
                                      # drop - if using to selectize drop-downs
                                      # retain - if using to construct maps
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
    req(selected_district, !is.null(district_data))

    # Extract & validate shape
    district_shape <- district_data |>
      dplyr::filter(join_key == selected_district)
    valid_shape <- tryCatch(sf::st_make_valid(district_shape), error = function(e) district_shape)

    # Filter spatial + ID matches
    spatial_schools <- filter_spatial_safe(school_data, valid_shape)
    id_schools <- dplyr::filter(school_data, mde_district_key == selected_district) # need adaptable variable names

    schools_filtered <- dplyr::bind_rows(spatial_schools, id_schools) |>
      dplyr::distinct(mde_school_id, .keep_all = TRUE)

    childcares_filtered <- filter_spatial_safe(childcare_data, valid_shape)

    boundary_choice <- district_shape
  } else {
    # County mode
    req(selected_county, !is.null(county_data))
    county_lower_selected <- tolower(selected_county)

    boundary_choice <- county_data |> dplyr::filter(county_lower == county_lower_selected)

    schools_filtered <- school_data |>
      dplyr::filter(tolower(COUNTYNAME) == county_lower_selected)

    childcares_filtered <- childcare_data |>
      dplyr::filter(tolower(COUNTYNAME) == county_lower_selected)
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
