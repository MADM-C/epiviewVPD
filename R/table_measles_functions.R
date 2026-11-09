# Case tables and annual case figures. Counts come from case_totals().

build_case_table <- function(cases, settings = NULL) {
  cases <- normalize_case_data(cases, settings)
  dplyr::rename(cases, county = county_name) |>
    dplyr::arrange(county, year, age_group)
}

filter_cases <- function(case_table, selected_county, settings = NULL,
                         years = NULL, age_groups = NULL, counties = NULL) {
  cases <- normalize_case_data(case_table, settings)
  county_names <- case_selected_counties(cases, selected_county, counties)
  totals <- case_totals(cases, counties = county_names, years = years,
                        age_groups = age_groups, by = c("year", "age_group"), settings = settings)
  totals$county <- rep(selected_county, nrow(totals))
  totals[c("county", "year", "age_group", "n_cases")]
}

#' Build a case-count summary table
#'
#' A county/year/age combination with no record counts as zero by default.
#' Set `settings$case_data$missing_records = "unknown"` when the source may
#' leave out combinations that were not reported. Blank or withheld counts
#' stay unknown either way, including in statewide totals.
#'
#' @param filtered_data Case data with `county_name`, `year`, `n_cases` and
#'   optional `age_group`. A column named `county` is also accepted. Use the
#'   complete case data, not statewide totals.
#' @param selected_county One county name, or `"Statewide"`.
#' @param age_groups Age groups to include, in column order. `NULL` uses the
#'   groups in the settings or the data. Cases with no age group get their own
#'   column.
#' @param settings Optional dashboard settings list.
#' @param years Whole years to include (for example, `2020:2025`). `NULL` uses
#'   every year from first to last in the data.
#' @param counties County names, or a data frame/sf object with `county_name`.
#'   Give all counties in the state so counties with no records count in
#'   statewide totals. `NULL` uses the counties in the data and labels the
#'   summary as covering those counties only.
#' @return A `gt_tbl` table. Unknown values are displayed as `"Unknown"`.
#' @export
#' @examples
#' cases <- data.frame(county_name = "A", year = c(2020, 2021),
#'                     n_cases = c(0, NA_real_))
#' render_cases_gt(cases, "A")
render_cases_gt <- function(filtered_data, selected_county = "Statewide",
                            age_groups = NULL, settings = NULL, years = NULL,
                            counties = NULL) {
  cases <- normalize_case_data(filtered_data, settings)
  groups <- case_age_universe(cases, age_groups, settings)
  if (anyNA(cases$age_group) && !anyNA(groups)) groups <- c(groups, NA_character_)
  county_names <- case_selected_counties(cases, selected_county, counties)
  totals <- case_totals(cases, counties = county_names, years = years,
                        age_groups = groups, by = c("year", "age_group"), settings = settings)
  no_age <- ".no_age_group"
  while (no_age %in% groups[!is.na(groups)]) no_age <- paste0(no_age, "_")
  keys <- groups
  keys[is.na(keys)] <- no_age
  headings <- age_group_labels(groups)
  headings[is.na(groups)] <- if (all(is.na(groups))) "Cases" else "Age not given"
  totals$age_group[is.na(totals$age_group)] <- no_age
  complete_counties <- case_county_scope_known(counties)
  scope <- if (selected_county == "Statewide" && !complete_counties) "Supplied counties" else selected_county
  totals$county <- rep(scope, nrow(totals))
  if (nrow(totals)) {
    wide_cases <- totals |>
      tidyr::pivot_wider(id_cols = c(county, year), names_from = age_group,
                         values_from = n_cases) |>
      dplyr::arrange(year)
  } else {
    wide_cases <- data.frame(county = character(), year = numeric())
  }
  for (key in setdiff(keys, names(wide_cases))) wide_cases[[key]] <- rep(NA_real_, nrow(wide_cases))
  wide_cases <- wide_cases[c("county", "year", keys)]
  known <- unlist(wide_cases[keys], use.names = FALSE)
  known <- known[is.finite(known)]
  color_max <- if (length(known)) max(1, known) else 1
  table <- gt::gt(wide_cases) |>
    gt::tab_header(title = if (selected_county == "Statewide") {
      paste0("Measles Cases by Year and Age Group", if (!complete_counties) ": Supplied counties" else "")
    } else paste("Measles Cases by Year and Age Group: County of", selected_county)) |>
    gt::tab_style(style = gt::cell_text(color = "#1E3A66", weight = "bold", size = "large"),
                   locations = gt::cells_title(groups = "title")) |>
    gt::cols_label(.list = stats::setNames(as.list(c("County", "Year", headings)),
                                          c("county", "year", keys))) |>
    gt::fmt_number(columns = dplyr::all_of(keys), decimals = 0) |>
    gt::sub_missing(columns = dplyr::all_of(keys), missing_text = "Unknown") |>
    gt::cols_align(align = "center", columns = -county) |>
    gt::data_color(columns = dplyr::all_of(keys),
                    fn = scales::col_numeric(c("#FFF9E6", "#F9C941", "#1E3A66"),
                                             domain = c(0, color_max), na.color = "#E8E8E8")) |>
    gt::tab_style(style = gt::cell_text(weight = "bold", color = "#1E3A66"),
                   locations = gt::cells_column_labels(dplyr::everything())) |>
    gt::tab_options(table.width = gt::px(850), heading.align = "left",
                     column_labels.background.color = "#F4E2A1",
                     column_labels.font.weight = "bold", table.border.top.color = "#1E3A66",
                     table.border.bottom.color = "#1E3A66", row.striping.background_color = "#FAFAFA",
                     data_row.padding = gt::px(3), row_group.padding = gt::px(2))
  if (!complete_counties && selected_county == "Statewide") {
    table <- gt::tab_source_note(table, "Totals cover supplied counties only; complete statewide coverage has not been established.")
  }
  table
}

#' Build an annual case-count plot
#'
#' An unknown count makes that total unknown. Combinations with no record count
#' as zero unless `settings$case_data$missing_records = "unknown"`.
#'
#' @param case_table Case data with `county_name`, `year`, `n_cases` and
#'   optional `age_group`. A column named `county` is also accepted.
#' @param selected_county One county name, or `"Statewide"`.
#' @param settings Optional dashboard settings list, used for
#'   `labels$epicurve_title` and `case_data$missing_records`.
#' @param years Whole years to plot. `NULL` uses every year from first to last
#'   in the data.
#' @param age_groups Age groups to include. `NULL` uses the groups in the
#'   settings or the data. Cases with no age group are kept as their own group.
#' @param counties County names, or a data frame/sf object with `county_name`.
#'   Give all counties in the state for statewide totals. Without it, the plot
#'   is labeled as covering only the counties in the data.
#' @return A `ggplot` object. Empty or entirely unknown data give a plot with a
#'   message.
#' @export
#' @examples
#' cases <- data.frame(county_name = "A", year = c(2020, 2021),
#'                     n_cases = c(0, NA_real_))
#' plot_epicurve(cases, "A")
plot_epicurve <- function(case_table, selected_county = "Statewide", settings = NULL,
                          years = NULL, age_groups = NULL, counties = NULL) {
  cases <- normalize_case_data(case_table, settings)
  county_names <- case_selected_counties(cases, selected_county, counties)
  county_cases <- case_totals(cases, counties = county_names, years = years,
                              age_groups = age_groups, by = "year", settings = settings)
  names(county_cases)[names(county_cases) == "n_cases"] <- "cases"
  title <- settings$labels$epicurve_title
  if (is.null(title)) title <- "Measles Cases by Year"
  scope <- if (selected_county == "Statewide" && !case_county_scope_known(counties)) "Supplied counties" else selected_county
  title <- paste0(title, ": ", if (selected_county == "Statewide") "" else "County of ", scope)
  if (!nrow(county_cases) || all(is.na(county_cases$cases))) {
    return(empty_figure("Case totals are unknown or unavailable for this selection.", county_cases) +
             ggplot2::labs(title = title))
  }
  unknown <- county_cases[is.na(county_cases$cases), , drop = FALSE]
  ggplot2::ggplot(county_cases, ggplot2::aes(x = year, y = cases)) +
    ggplot2::geom_col(width = 0.75, fill = "#1E3A66", na.rm = TRUE) +
    ggplot2::geom_text(ggplot2::aes(label = ifelse(!is.na(cases) & cases > 0, cases, "")),
                        vjust = -0.5, size = 4.5, color = "black", fontface = "bold", na.rm = TRUE) +
    ggplot2::geom_text(data = unknown, ggplot2::aes(x = year, y = 0), label = "Unknown",
                        inherit.aes = FALSE, vjust = -0.5, size = 3, colour = "grey35") +
    ggplot2::labs(x = "Year", y = "Number of Cases", title = title,
                   caption = if (nrow(unknown)) "Unknown totals include missing or withheld records." else NULL) +
    ggplot2::scale_x_continuous(breaks = county_cases$year, expand = ggplot2::expansion(add = 0.3)) +
    ggplot2::scale_y_continuous(breaks = scales::pretty_breaks(n = 8),
                                labels = scales::label_number(accuracy = 1),
                                expand = ggplot2::expansion(mult = c(0, 0.15))) +
    ggplot2::theme_minimal(base_size = 14) +
    ggplot2::theme(plot.background = ggplot2::element_rect(fill = "white", color = NA),
                    panel.background = ggplot2::element_rect(fill = "white", color = NA),
                    plot.title = ggplot2::element_text(hjust = 0.5, face = "bold", color = "#1E3A66"),
                    axis.title.x = ggplot2::element_text(face = "bold", color = "#1E3A66"),
                    axis.title.y = ggplot2::element_text(face = "bold", color = "#1E3A66"),
                    axis.text = ggplot2::element_text(color = "#1E3A66"),
                    panel.grid.minor = ggplot2::element_blank(),
                    panel.grid.major.x = ggplot2::element_blank())
}
