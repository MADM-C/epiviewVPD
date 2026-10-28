# ====================================================
# Helper Functions for Grade Details Module
# ====================================================

# ============================================================
# HELPER: parse a vax percentage string to a numeric value.
# Handles ">95", ">98", ">99" blurred strings and plain numbers.
# Returns NA for redacted / unparseable values.
# ============================================================

parse_vax_num <- function(x) {
  case_when(
    grepl("^>\\s*95", x) ~ 95,
    grepl("^>\\s*98", x) ~ 98,
    grepl("^>\\s*99", x) ~ 99,
    grepl("^<", x) ~ suppressWarnings(as.numeric(gsub("[^0-9.]", "", x))),
    TRUE ~ suppressWarnings(as.numeric(x))
  )
}

# ============================================================
# HELPER: derive a bar fill color from a numeric coverage value.
# ============================================================
coverage_color <- function(value_raw, value_num) {
  case_when(
    is.na(value_raw) ~ "gray",
    grepl("^>", value_raw) ~ "darkgreen",
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
      dplyr::filter(!is.na(idsch), !is.na(daycare_name))
    
    lc <- stats::setNames(as.character(df$idsch), df$daycare_name) # need adaptable variable names
    lc[order(names(lc))]
    
  } else {
    # "All" or unselected mode
    c(
      dplyr::pull(school_data, school_name),
      dplyr::pull(childcare_data, daycare_name)
    ) %>%
      unique() %>%
      sort()
  }
}