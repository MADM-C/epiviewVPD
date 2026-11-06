# ====================================================
# Helper Functions for Grade Details Module
# ====================================================

# ============================================================
# HELPER: parse a vax percentage string to a numeric value, for bar
# lengths. A blurred value (">95", "<5") is drawn at its number; "87.3"
# and "87.3%" give 87.3. Returns NA for redacted / unparseable values.
# ============================================================

parse_vax_num <- function(x) {
  suppressWarnings(as.numeric(sub("%$", "", trimws(sub("^\\s*[<>]", "", x)))))
}

# ============================================================
# HELPER: derive a bar fill color from a coverage value. Blurred values
# are colored by the number they count as (pct_number(), load_app_data.R),
# so ">95" counts as 96 (green) and ">80" as 81 (red), not always green.
# ============================================================
coverage_color <- function(value_raw, value_num) {
  value_num <- ifelse(grepl("^\\s*[<>]", value_raw), pct_number(value_raw), value_num)
  case_when(
    is.na(value_raw) ~ "gray",
    value_num < 85 ~ "red",
    value_num < 90 ~ "orange",
    value_num < 95 ~ "gold",
    value_num >= 95 ~ "darkgreen",
    TRUE ~ "gray"
  )
}

# ============================================================
# HELPER: Standardize extracting named or unnamed vectors for selectize choices
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

    school_data %>%
      dplyr::pull(school_name) %>%
      unique() %>%
      sort()

  } else if (isTRUE(point_type == "Child Cares")) {

    df <- childcare_data %>%
      dplyr::filter(!is.na(facility_id), !is.na(facility_name))

    lc <- stats::setNames(as.character(df$facility_id), df$facility_name)
    lc[order(names(lc))]

  } else {
    # "All" or unselected mode
    c(
      dplyr::pull(school_data, school_name),
      dplyr::pull(childcare_data, facility_name)
    ) %>%
      unique() %>%
      sort()
  }
}
