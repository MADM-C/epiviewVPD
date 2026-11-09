# Table building used by the dashboard, reports and R code.
case_county_universe <- function(counties) {
  if (is.null(counties)) return(NULL)
  # Uses the loader's list of counties that count for cases, when present.
  scope <- attr(counties, "case_counties", exact = TRUE)
  if (is.data.frame(counties)) {
    field <- if ("county_name" %in% names(counties)) "county_name" else "county"
    names <- counties[[field]]
    scope <- if (is.null(scope)) names else scope[scope %in% names]
  } else if (is.null(scope)) scope <- counties
  attr(scope, "universe_complete") <- attr(counties, "universe_complete", exact = TRUE)
  scope
}

coverage_map_title <- function(counties) {
  rate <- calc_statewide_k12(counties)
  htmltools::tagList(htmltools::tags$h4("MMR Vaccine Coverage by County (K-12 Schools Only)",
    style = "font-weight:600;"),
    if (!all(is.na(counties$full_vax))) htmltools::tags$div(if (is.na(rate)) "Coverage across supplied county records: Unknown" else
      paste0("MMR coverage across supplied county records: ", rate, "%"),
      style = "font-size:14px; color:#555; margin-bottom:8px;"))
}

table_columns <- function(data, defaults) {
  if (is.null(data)) data <- data.frame()
  if (inherits(data, "sf")) data <- sf::st_drop_geometry(data)
  for (name in names(defaults)) {
    if (!name %in% names(data)) data[[name]] <- rep(defaults[[name]], nrow(data))
  }
  data
}

coverage_display <- function(x) {
  missing <- is.na(x) | trimws(as.character(x)) %in% c("", "NA", "NaN")
  out <- format_vax_pct(x)
  out[missing] <- "Unknown / withheld"
  out
}

#' Build a vaccination coverage summary table
#' @param schools,facilities,districts Standardized dashboard data layers.
#' @param table_type Either `school` or `childcare`.
#' @param boundary_type Either `county` or `district` (schools only).
#' @param selected_county,selected_district Location to display; NULL includes all.
#' @param sort_by Column used to sort the table.
#' @param notes Configured source notes.
#' @param bands Coverage color bands.
#' @return A gt table.
#' @export
build_coverage_table <- function(schools = NULL, facilities = NULL, districts = NULL,
                                 table_type = c("school", "childcare"),
                                 boundary_type = c("county", "district"),
                                 selected_county = NULL, selected_district = NULL,
                                 sort_by = "full_vax_pct", notes = default_settings()$notes,
                                 bands = coverage_bands()) {
  table_type <- match.arg(table_type)
  boundary_type <- match.arg(boundary_type)
  if (table_type == "childcare") boundary_type <- "county"
  label <- if (table_type == "school") "School Vaccine Coverage" else "Child Care Vaccine Coverage"
  data <- if (table_type == "school") {
    build_school_table(schools, boundary_type, build_district_lookup(districts))
  } else build_daycare_table(facilities)
  selected <- if (boundary_type == "district") selected_district else selected_county
  if (length(selected) && nzchar(selected[1])) {
    data <- data[!is.na(data[[boundary_type]]) & data[[boundary_type]] == selected[1], , drop = FALSE]
  }
  if (!nrow(data)) return(gt::gt(data.frame(Message = "No facilities for selected location")))
  data <- sort_coverage_table(data, label, boundary_type, sort_by)
  render_coverage_gt(data, label, boundary_type,
    if (is.null(selected_county)) "All supplied counties" else selected_county,
    if (is.null(selected_district)) "All supplied districts" else selected_district,
    nonreporting_note = notes$nonreporting_table,
    redacted_childcares_note = notes$redacted_childcares, bands = bands)
}

proximity_table_data <- function(facilities_data = NULL, searched = FALSE) {
  data <- table_columns(facilities_data, list(facility_name = NA_character_,
    facility_type = NA_character_, full_vax_pct = NA_character_,
    distance_mi = NA_real_, enrollment = NA_real_))
  data <- mask_not_reported(data)
  # Keeps facilities with known coverage.
  known_coverage <- !is.na(pct_number(data$full_vax_pct, offset = 0))
  data <- data[known_coverage & data$facility_type %in% c("School", "Daycare", "Child Care"), , drop = FALSE]
  if (!nrow(data)) {
    return(data.frame(`School/Child Care Name` = if (isTRUE(searched)) {
      "No reported facilities below threshold found in selected area"
    } else "Choose a search point to find low-vaccine facilities",
      Type = "", `Vaccine Rate` = "", `Distance from Point` = "", Enrollment = "",
      check.names = FALSE))
  }
  data.frame(`School/Child Care Name` = data$facility_name,
    Type = ifelse(data$facility_type == "Daycare", "Child Care", data$facility_type),
    `Vaccine Rate` = coverage_display(data$full_vax_pct),
    `Distance from Point` = ifelse(is.na(data$distance_mi), "Unknown", paste(data$distance_mi, "mi")),
    Enrollment = ifelse(is.na(data$enrollment), "Unknown", format(data$enrollment, big.mark = ",")),
    check.names = FALSE)
}

#' Build a proximity search results table
#' @param facilities_data An analyzed low-vaccine facilities layer.
#' @param searched Whether a search has been performed.
#' @param interactive `TRUE` returns a DT widget; `FALSE` a static gt table.
#' @return A gt table, or DT widget when interactive is TRUE.
#' @export
build_proximity_table <- function(facilities_data = NULL, searched = FALSE, interactive = FALSE) {
  data <- proximity_table_data(facilities_data, searched)
  if (!isTRUE(interactive)) return(gt::gt(data))
  DT::datatable(data, extensions = "Buttons", rownames = FALSE,
    options = list(pageLength = 10, scrollY = "400px", scrollCollapse = TRUE,
      searching = TRUE, ordering = TRUE, order = list(list(2, "asc")), dom = "Bfrtip",
      buttons = list(list(extend = "csv", filename = "low_vaccine_facilities"),
        list(extend = "excel", filename = "low_vaccine_facilities"),
        list(extend = "pdf", filename = "low_vaccine_facilities"))))
}

#' Build a facility overview table
#' @param school_id Selected school or facility identifier.
#' @param schools,facilities,counties,districts Standardized data layers.
#' @return A gt table with available facility metrics.
#' @export
build_facility_overview_table <- function(school_id, schools = NULL, facilities = NULL,
                                          counties = NULL, districts = NULL) {
  selected <- select_facility(school_id, schools, facilities)
  if (is.null(selected)) return(gt::gt(data.frame(Message = "No facility selected")))
  data <- sf::st_drop_geometry(selected$data)
  if ("reporting_status" %in% names(data) && isTRUE(data$reporting_status[1] == "not_reported")) {
    for (name in intersect(c("full_vax_pct", "partial_vax_pct", "medical_pct", "nonmedical_pct"), names(data))) data[[name]] <- NA_character_
  }
  columns <- c("enroll", "enroll_eligible", "full_vax_pct", "partial_vax_pct",
    "medical_pct", "nonmedical_pct", "school_type", "home_languages")
  columns <- intersect(columns, names(data))
  columns <- columns[vapply(columns, function(name) name %in% c("full_vax_pct", "enroll", "enroll_eligible") || any(!is.na(data[[name]])), logical(1))]
  labels <- c(enroll = "Total Enrollment", enroll_eligible = "MMR Eligible",
    full_vax_pct = "MMR Coverage", partial_vax_pct = "Partially Vaccinated / No Doses",
    medical_pct = "Medical Exemption", nonmedical_pct = "Non-Medical Exemption",
    school_type = "School Type", home_languages = "Home Languages")
  values <- vapply(columns, function(name) {
    if (grepl("_pct$", name)) coverage_display(data[[name]][1]) else if (is.na(data[[name]][1])) "Unknown" else as.character(data[[name]][1])
  }, character(1))
  metrics <- get_facility_metrics(selected$type == "school", selected$type != "school",
    selected$id, selected$data, counties, districts)
  extra_labels <- character()
  extra_values <- character()
  county_name <- if (selected$type == "school") metrics$county_name_school else metrics$county_name_daycare
  if (!is.null(county_name) && !is.null(metrics$county_vax)) {
    extra_labels <- c(extra_labels, paste(county_name, "County MMR Coverage"))
    extra_values <- c(extra_values, coverage_display(metrics$county_vax))
  }
  if (!is.null(metrics$district_name) && !is.null(metrics$district_vax)) {
    extra_labels <- c(extra_labels, paste(metrics$district_name, "MMR Coverage"))
    extra_values <- c(extra_values, coverage_display(metrics$district_vax))
  }
  gt::gt(data.frame(Metric = c(unname(labels[columns]), extra_labels), Value = c(values, extra_values))) |>
    gt::tab_header(title = selected$name)
}

# Finds a facility by ID or displayed name.
select_facility <- function(id, schools = NULL, facilities = NULL) {
  if (!length(id) || is.na(id[1]) || !nzchar(id[1])) return(NULL)
  id <- as.character(id[1])
  for (kind in c("school", "facility")) {
    data <- if (kind == "school") schools else facilities
    key <- paste0(kind, "_id")
    name <- paste0(kind, "_name")
    if (is.null(data) || !all(c(key, name) %in% names(data))) next
    prefix <- paste0(kind, ":")
    lookup <- sub("^(school|facility):", "", id)
    if (grepl("^(school|facility):", id) && !startsWith(id, prefix)) next
    rows <- which(as.character(data[[key]]) == lookup | as.character(data[[name]]) == lookup)
    if (length(rows)) return(list(id = as.character(data[[key]][rows[1]]),
      name = data[[name]][rows[1]], type = kind, data = data[rows[1], , drop = FALSE]))
  }
  NULL
}
