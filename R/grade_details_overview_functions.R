# Facility metrics used by the dashboard and reports.
get_facility_metrics <- function(is_school, is_childcare, school_id, facility_data = NULL,
                                 county_data = NULL, district_data = NULL, grade_data = NULL) {
  key <- if (isTRUE(is_school)) "school_id" else "facility_id"
  rows <- if (key %in% names(facility_data)) which(as.character(facility_data[[key]]) == as.character(school_id)) else integer()
  row <- if (length(rows)) facility_data[rows[1], , drop = FALSE] else data.frame()
  value <- function(data, name, default = NULL) {
    if (is.null(data) || !nrow(data) || !name %in% names(data)) return(default)
    result <- data[[name]][1]
    if (length(result) && !is.na(result)) result else default
  }
  county <- value(row, "county_name")
  county_row <- if (!is.null(county) && "county_name" %in% names(county_data)) {
    county_data[which(county_data$county_name == county), , drop = FALSE]
  } else NULL
  county_vax <- value(county_row, "full_vax_pct")
  if (isTRUE(value(county_row, "reporting_status") == "not_reported")) county_vax <- NA_character_
  nonreported <- isTRUE(value(row, "reporting_status") == "not_reported")
  coverage <- function(name) if (nonreported) NA_character_ else value(row, name, NA_character_)
  if (!isTRUE(is_school)) return(list(overall_cov = coverage("full_vax_pct"),
    total = value(row, "enroll", NA_real_), total_elig = value(row, "enroll_eligible", NA_real_),
    county_name_daycare = county, county_vax = county_vax))
  district <- value(row, "district_id")
  district_row <- if (!is.null(district) && "district_id" %in% names(district_data)) {
    district_data[which(district_data$district_id == district), , drop = FALSE]
  } else NULL
  grades <- if (!is.null(grade_data) && "school_id" %in% names(grade_data)) {
    grade_data[which(as.character(grade_data$school_id) == as.character(school_id)), , drop = FALSE]
  } else NULL
  list(school_type = value(row, "school_type"), total_enrollment = value(row, "enroll", NA_real_),
    languages = value(row, "home_languages"), district_name = value(district_row, "district_name"),
    district_vax = if (isTRUE(value(district_row, "reporting_status") == "not_reported")) NA_character_ else value(district_row, "full_vax_pct"), county_name_school = county,
    county_vax = county_vax, overall_cov = coverage("full_vax_pct"), grade_rows = grades,
    all_grades_redacted = !is.null(grades) && nrow(grades) > 0 && all(is.na(grades$full_vax_pct)),
    nonresponder_status = nonreported,
    med_exempt = if (nonreported) NULL else value(row, "medical_pct"),
    nonmed_exempt = if (nonreported) NULL else value(row, "nonmedical_pct"),
    partial_vax = if (nonreported) NULL else value(row, "partial_vax_pct"))
}

enrollment_label <- function(notes, label = "Total Enrollment") {
  if (is.null(notes$enrollment)) label else paste0(label, "*")
}
enrollment_footnote <- function(notes) {
  if (!is.null(notes$enrollment)) list(tags$br(), notes$enrollment)
}
privacy_footnote_html <- function(notes) {
  parts <- c(notes$redacted, notes$blurred, notes$enrollment)
  parts <- parts[!is.na(parts) & nzchar(parts)]
  if (length(parts)) paste0("<em>", paste(parts, collapse = "<br><br>"), "</em>")
}

overview_metric <- function(label, value, percent = FALSE) {
  if (is.null(value) || !length(value)) return(NULL)
  tags$p(tags$strong(paste0(label, ": ")),
    if (percent) coverage_display(value) else ifelse(is.na(value), "Unknown", value),
    class = "grade-details-details")
}

render_school_overview <- function(school_id, selected_location, school_type, total_enrollment,
  languages, district_name, district_vax, county_name_school, county_vax, overall_cov,
  grade_rows, all_grades_redacted, nonresponder_status, med_exempt, nonmed_exempt,
  partial_vax, notes = default_settings()$notes, show_overview = TRUE,
  show_grade_plot = TRUE, show_grade_table = TRUE) {
  has_grades <- !is.null(grade_rows) && nrow(grade_rows) > 0
  tagList(
    tags$h4(if (show_grade_plot || show_grade_table) "MMR Coverage in Schools by Grade-Level" else
      "MMR Coverage in Schools", class = "grade-details-heading"),
    tags$div(stringr::str_wrap(selected_location, width = 65), class = "grade-details-facility"),
    if (isTRUE(show_overview)) tagList(
      overview_metric("School Type", school_type),
      overview_metric(enrollment_label(notes), total_enrollment),
      overview_metric("Schoolwide MMR Coverage", overall_cov, TRUE),
      overview_metric("Partially Vaccinated / No Doses", partial_vax, TRUE),
      overview_metric("Medical Exemption", med_exempt, TRUE),
      overview_metric("Non-Medical Exemption", nonmed_exempt, TRUE),
      if (!is.null(county_name_school)) overview_metric(paste(county_name_school, "County MMR Coverage"), county_vax, TRUE),
      if (!is.null(district_name)) overview_metric(paste(district_name, "MMR Coverage"), district_vax, TRUE),
      overview_metric(if (isTRUE(school_type == "Charter") || is.null(district_name)) "School Home Languages" else "District Home Languages", languages)
    ),
    if (isTRUE(nonresponder_status)) tags$p(notes$nonreporting_school, class = "grade-details-footnote"),
    if (has_grades && (show_grade_plot || show_grade_table)) tags$div(
      style = "display:flex;flex-direction:row;gap:20px;",
      if (show_grade_plot) tags$div(plotOutput("grade_plot", height = "250px", width = "350px")),
      if (show_grade_table) tags$div(gt::gt_output("grade_table"))),
    if ((show_overview || has_grades) && !is.null(privacy_footnote_html(notes)))
      tags$p(HTML(privacy_footnote_html(notes)), class = "grade-details-footnote")
  )
}

render_childcare_overview <- function(school_id, facility_data = NULL, overall_cov, total,
  total_elig, county_name_daycare, county_vax, notes = default_settings()$notes) {
  selected <- select_facility(paste0("facility:", school_id), facilities = facility_data)
  tagList(tags$h4("MMR Coverage in Child Cares", class = "grade-details-heading"),
    if (!is.null(selected)) tags$div(stringr::str_wrap(selected$name, 65), class = "grade-details-facility"),
    overview_metric(enrollment_label(notes), total), overview_metric("Total Eligible", total_elig),
    overview_metric("Child Care MMR Coverage", overall_cov, TRUE),
    if (!is.null(county_name_daycare)) overview_metric(paste(county_name_daycare, "County MMR Coverage"), county_vax, TRUE),
    if (!is.null(privacy_footnote_html(notes))) tags$p(HTML(privacy_footnote_html(notes)), class = "grade-details-footer"))
}

facility_overview_panel <- function(selected, schools, facilities, counties, districts, grades,
                                     notes, features) {
  if (is.null(selected)) return(NULL)
  school <- selected$type == "school"
  metrics <- get_facility_metrics(school, !school, selected$id, selected$data, counties, districts, grades)
  if (school) {
    do.call(render_school_overview, c(list(school_id = selected$id, selected_location = selected$name), metrics,
      list(notes = notes, show_overview = features$facility_overview,
        show_grade_plot = features$grade_plot, show_grade_table = features$grade_table)))
  } else if (features$facility_overview) {
    do.call(render_childcare_overview, c(list(school_id = selected$id, facility_data = facilities), metrics, list(notes = notes)))
  }
}
