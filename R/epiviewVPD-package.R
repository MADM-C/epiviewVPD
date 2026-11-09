#' @keywords internal
"_PACKAGE"

# ==== Package imports ====
# Functions from these packages are used throughout R/ without the
# `package::` prefix. dataTableOutput() and renderDataTable() come
# from DT; shiny's functions with the same names are excluded.
#' @rawNamespace import(shiny, except = c(dataTableOutput, renderDataTable))
#' @importFrom DT dataTableOutput renderDataTable
#' @import leaflet
#' @import dplyr
#' @rawNamespace import(ggplot2, except = vars)
#' @import gt
#' @import sf
#' @import stringr
#' @importFrom rlang :=
#' @importFrom scales col_numeric label_number pretty_breaks
#' @importFrom stats setNames
#' @importFrom tidyr complete pivot_wider replace_na
NULL

# Column names used by dplyr, ggplot and gt, listed for R CMD check.
utils::globalVariables(c(
  ".env", "age_group", "angle", "area", "county", "county_name",
  "district_id", "district_name", "enroll", "enroll_eligible",
  "facility_name", "full_color", "full_label", "full_num",
  "full_vax_display", "full_vax_pct", "full_vax_pct_chr", "full_vax_pct_num",
  "geometry", "grade", "is_blurred", "lat", "lat_offset", "lon",
  "lon_offset", "medical_pct", "n_at_location", "n_cases", "name",
  "nonmedical_pct", "offset_distance", "partial_vax_display",
  "partial_vax_pct", "school_id", "school_name", "school_type",
  "total_enrollment", "type", "year"
))
