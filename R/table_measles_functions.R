# ==== MEASLES CASE HELPERS: case table, case filtering, case gt table, epicurve ===
# TODO(#20): parts of this file are specific to measles (labels,
# object names)

# Input:  cases from the standard app data
# Output: display table with a `county` column
build_case_table <- function(cases) {
  cases %>%
    rename(county = county_name) %>%
    arrange(county, year, age_group)
}

# "Statewide" returns totals by year and age group across all counties.
filter_cases <- function(case_table, selected_county) {
  if (selected_county == "Statewide") {
    case_table %>%
      group_by(year, age_group) %>%
      summarise(n_cases = sum(n_cases, na.rm = TRUE), .groups = "drop") %>%
      mutate(county = "Statewide")
  } else {
    case_table %>%
      filter(county == selected_county)
  }
}

# Input:  filtered_data from filter_cases(); selected_county;
#         age_groups = the case age groups in display order
#         (case_age_groups.R, from settings case_age_groups)
# Output: gt table with one column per age group and a row per year;
#         cases with no age group get their own column ("Cases" when the
#         data have no age groups at all)
# Used by gtServer() and inst/reports/gt_summary_report.Rmd.
render_cases_gt <- function(filtered_data, selected_county,
                            age_groups = case_age_groups(NULL, filtered_data$age_group)) {
  # Cases without an age group get their own column, under a key that
  # can't clash with a group's name
  no_age <- ".no_age_group"
  no_age_label <- if (length(age_groups) == 0) "Cases" else "Age not given"
  age <- trimws(as.character(filtered_data$age_group))
  age[is.na(age) | age == ""] <- no_age
  groups <- c(age_groups, if (no_age %in% age) no_age)

  wide_cases <- filtered_data %>%
    mutate(
      county = as.character(county),
      age_group = factor(age, levels = groups)
    ) %>%
    # Every age group appears for every county-year, even with zero cases.
    complete(
      county,
      year,
      age_group = factor(groups, levels = groups),
      fill = list(n_cases = 0)
    ) %>%
    group_by(county, year, age_group) %>%
    summarise(total_cases = sum(n_cases, na.rm = TRUE), .groups = "drop") %>%
    pivot_wider(
      names_from  = age_group,
      values_from = total_cases,
      values_fill = 0
    ) %>%
    arrange(year) %>%
    select(county, year, all_of(groups))

  wide_cases %>%
    gt() %>%
    tab_header(
      title = if (selected_county == "Statewide") {
        "Measles Cases by Year and Age Group"
      } else {
        paste("Measles Cases by Year and Age Group: County of", selected_county)
      }
    ) %>%
    tab_style(
      style = cell_text(
        color = "#1E3A66",
        weight = "bold",
        size = "large"
      ),
      locations = cells_title(groups = "title")
    ) %>%
    # all headings in .list: cols_label() ignores named arguments given with it
    cols_label(.list = stats::setNames(
      as.list(c("County", "Year", age_group_labels(age_groups), if (no_age %in% groups) no_age_label)),
      c("county", "year", groups)
    )) %>%
    fmt_number(columns = -c(county, year), decimals = 0) %>%
    cols_align(
      align = "center",
      columns = -c(county)
    ) %>%
    data_color(
      columns = -c(county, year),
      fn = col_numeric(
        palette = c("#FFF9E6", "#F9C941", "#1E3A66"),
        domain = c(0, max(wide_cases[, -c(1, 2)], na.rm = TRUE))
      )
    ) %>%
    tab_style(
      style = cell_text(weight = "bold", color = "#1E3A66"),
      locations = cells_column_labels(everything())
    ) %>%
    tab_options(
      table.width = px(850),
      heading.align = "left",
      column_labels.background.color = "#F4E2A1",
      column_labels.font.weight = "bold",
      table.border.top.color = "#1E3A66",
      table.border.bottom.color = "#1E3A66",
      row.striping.background_color = "#FAFAFA",
      data_row.padding = px(3),
      row_group.padding = px(2)
    )
}

plot_epicurve <- function(case_table, selected_county) {
  all_years <- sort(unique(case_table$year))
  min_year <- min(all_years, na.rm = TRUE)
  max_year <- max(all_years, na.rm = TRUE)

  # Years with no cases still get a zero-height bar.
  county_years <- data.frame(year = seq(min_year, max_year, by = 1))

  county_cases <- filter_cases(case_table, selected_county) %>%
    group_by(year) %>%
    summarise(cases = sum(n_cases, na.rm = TRUE), .groups = "drop") %>%
    right_join(county_years, by = "year") %>%
    mutate(cases = replace_na(cases, 0L))

  ggplot(county_cases, aes(x = year, y = cases)) +
    geom_col(width = 0.75, fill = "#1E3A66") +
    geom_text(
      aes(label = ifelse(cases > 0, cases, "")),
      vjust = -0.5, size = 4.5, color = "black", fontface = "bold"
    ) +
    labs(
      x = "Year",
      y = "Number of Cases",
      title = paste0(
        "Measles Cases by Year: ",
        ifelse(selected_county == "Statewide", "", "County of "),
        selected_county
      )
    ) +
    scale_x_continuous(
      breaks = seq(min_year, max_year, 1),
      expand = expansion(add = 0.3)
    ) +
    scale_y_continuous(
      breaks = pretty_breaks(n = 8),
      labels = label_number(accuracy = 1),
      expand = expansion(mult = c(0, 0.15))
    ) +
    theme_minimal(base_size = 14) +
    theme(
      plot.background = element_rect(fill = "white", color = NA),
      panel.background = element_rect(fill = "white", color = NA),
      plot.title = element_text(hjust = 0.5, face = "bold", color = "#1E3A66"),
      axis.title.x = element_text(face = "bold", color = "#1E3A66"),
      axis.title.y = element_text(face = "bold", color = "#1E3A66"),
      axis.text = element_text(color = "#1E3A66"),
      panel.grid.minor = element_blank(),
      panel.grid.major.x = element_blank()
    )
}
