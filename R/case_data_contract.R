# Case counts used by maps, tables, figures and reports.
# A county/year/age combination with no row counts as zero unless the settings
# choose "unknown". A row with a blank or withheld count stays unknown either way.
case_sum <- function(x) {
  if (!length(x) || anyNA(x)) return(NA_real_)
  sum(x)
}

case_missing_records <- function(settings = NULL, cases = NULL) {
  policy <- settings$case_data$missing_records
  if (is.null(policy)) policy <- attr(cases, "missing_records", exact = TRUE)
  if (is.null(policy)) policy <- "zero"
  if (!is.character(policy) || length(policy) != 1L || is.na(policy) ||
      !policy %in% c("unknown", "zero")) {
    stop("case_data$missing_records must be 'unknown' or 'zero'.", call. = FALSE)
  }
  policy
}

normalize_case_data <- function(cases, settings = NULL) {
  if (!is.data.frame(cases)) stop("cases must be a data frame.", call. = FALSE)
  if (inherits(cases, "sf")) cases <- sf::st_drop_geometry(cases)
  if (!"county_name" %in% names(cases) && "county" %in% names(cases)) {
    cases$county_name <- cases$county
  }
  required <- c("county_name", "year", "n_cases")
  missing <- setdiff(required, names(cases))
  if (length(missing)) stop("cases is missing required columns: ", paste(missing, collapse = ", "), ".", call. = FALSE)
  county <- trimws(as.character(cases$county_name))
  if (anyNA(county) || any(county == "")) stop("cases$county_name must name a county for every record.", call. = FALSE)
  year <- suppressWarnings(as.numeric(as.character(cases$year)))
  if (anyNA(year) || any(!is.finite(year) | year != floor(year))) {
    stop("cases$year must contain whole, non-missing years.", call. = FALSE)
  }
  raw_count <- trimws(as.character(cases$n_cases))
  codes <- c("", "NA", "*", "S", "suppressed", "withheld", "redacted", settings$suppression$redacted_codes)
  unknown <- is.na(raw_count) | tolower(raw_count) %in% tolower(codes)
  count <- suppressWarnings(as.numeric(raw_count))
  count[unknown] <- NA_real_
  if (any(!unknown & (is.na(count) | !is.finite(count) | count < 0 | count != floor(count)))) {
    stop("cases$n_cases must contain nonnegative whole counts or unknown/withheld values.", call. = FALSE)
  }
  age <- if ("age_group" %in% names(cases)) trimws(as.character(cases$age_group)) else rep(NA_character_, nrow(cases))
  age[!is.na(age) & age == ""] <- NA_character_
  normalized <- data.frame(county_name = county, year = year, age_group = age, n_cases = count,
                            stringsAsFactors = FALSE)
  attr(normalized, "missing_records") <- attr(cases, "missing_records", exact = TRUE)
  normalized
}

# Years for the historical cases map slider.
# Input:  the case_years setting (NULL, or list(min, max, selected)); the
#         cases table, or NULL when there is none
# Output: list(min, max, selected). A setting is returned as given. With no
#         setting: the first and last year in the cases, all of them selected,
#         or the current year when the cases hold no years.
# Used by app_ui()
slider_case_years <- function(setting, cases) {
  if (!is.null(setting)) return(setting)
  years <- suppressWarnings(as.numeric(as.character(cases$year)))
  years <- years[is.finite(years)]
  if (!length(years)) years <- as.numeric(format(Sys.Date(), "%Y"))
  list(min = min(years), max = max(years), selected = range(years))
}

case_year_universe <- function(cases, years = NULL, settings = NULL) {
  if (is.null(years)) {
    # With no `years` given, uses every year from first to last in the cases.
    if (nrow(cases)) {
      years <- seq.int(min(cases$year), max(cases$year))
    } else {
      years <- numeric(0)
    }
  }
  if (!is.numeric(years) || anyNA(years) || any(!is.finite(years) | years != floor(years))) {
    stop("years must be a numeric vector of whole years (e.g. 2020:2025).", call. = FALSE)
  }
  sort(unique(years))
}

case_age_universe <- function(cases, age_groups = NULL, settings = NULL) {
  inferred <- is.null(age_groups)
  if (inferred) age_groups <- case_age_groups(settings$case_age_groups, cases$age_group)
  age_groups <- trimws(as.character(age_groups))
  age_groups[!is.na(age_groups) & age_groups == ""] <- NA_character_
  # Adds an unclassified group (NA) when the data has no age groups, or when
  # some cases have none and no age groups were selected.
  if (!length(age_groups) || (inferred && anyNA(cases$age_group))) age_groups <- c(age_groups, NA_character_)
  unique(age_groups)
}

case_selected_counties <- function(cases, selected_county, counties = NULL) {
  if (!is.character(selected_county) || length(selected_county) != 1L ||
      is.na(selected_county) || !nzchar(trimws(selected_county))) {
    stop("selected_county must be one county name or 'Statewide'.", call. = FALSE)
  }
  if (is.null(counties)) counties <- unique(cases$county_name)
  counties <- case_county_universe(counties)
  if (!is.character(counties) || anyNA(counties) || any(trimws(counties) == "")) {
    stop("counties must name the eligible counties.", call. = FALSE)
  }
  counties <- unique(trimws(counties))
  if (selected_county == "Statewide") return(counties)
  if (length(counties) && !selected_county %in% counties) {
    stop("selected_county is not in the supplied county universe: ", selected_county, ".", call. = FALSE)
  }
  selected_county
}

case_county_scope_known <- function(counties) {
  !is.null(counties) && !identical(attr(counties, "universe_complete", exact = TRUE), FALSE)
}

# Case totals by any of county_name, year and age_group (`by`).
# `counties`, `years` and `age_groups` set the combinations to include, whether
# or not a row exists for each. With boundaries, give all eligible county names.
case_totals <- function(cases, counties = NULL, years = NULL, age_groups = NULL,
                        by = "county_name", settings = NULL) {
  cases <- normalize_case_data(cases, settings)
  policy <- case_missing_records(settings, cases)
  if (is.null(counties)) counties <- unique(cases$county_name)
  counties <- case_county_universe(counties)
  if (!is.character(counties) || anyNA(counties) || any(trimws(counties) == "")) {
    stop("counties must be a character vector of county names.", call. = FALSE)
  }
  counties <- unique(trimws(counties))
  years <- case_year_universe(cases, years, settings)
  age_groups <- case_age_universe(cases, age_groups, settings)
  dimensions <- c("county_name", "year", "age_group")
  if (!is.character(by) || anyNA(by) || anyDuplicated(by) || any(!by %in% dimensions)) {
    stop("by must be a subset of county_name, year and age_group.", call. = FALSE)
  }
  cells <- expand.grid(county_name = counties, year = years, age_group = age_groups,
                       KEEP.OUT.ATTRS = FALSE, stringsAsFactors = FALSE)
  observed <- cases |>
    dplyr::group_by(dplyr::across(dplyr::all_of(dimensions))) |>
    dplyr::summarise(n_cases = case_sum(n_cases), .groups = "drop")
  observed$.case_record_present <- TRUE
  cells <- dplyr::left_join(cells, observed, by = dimensions)
  if (policy == "zero") cells$n_cases[is.na(cells$.case_record_present)] <- 0
  if (!length(by)) return(data.frame(n_cases = case_sum(cells$n_cases)))
  totals <- cells |>
    dplyr::group_by(dplyr::across(dplyr::all_of(by))) |>
    dplyr::summarise(n_cases = case_sum(n_cases), .groups = "drop")
  as.data.frame(totals)
}

empty_figure <- function(message, data = NULL) {
  ggplot2::ggplot(data) +
    ggplot2::annotate("text", x = 0, y = 0, label = message, size = 4.5, colour = "grey30") +
    ggplot2::theme_void()
}
