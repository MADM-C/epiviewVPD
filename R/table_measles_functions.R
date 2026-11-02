# ==== MEASLES CASE HELPERS: case table, case filtering, case gt table, epicurve ===
# NOTE: There are multiple points in this code that will need to be edited
# in the future so that it's better able to handle being adapted to different
# diseases

build_case_table <- function(measles_cases) {
  measles_cases %>%
    mutate(county = str_to_title(county)) %>%
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

render_cases_gt <- function(filtered_data, selected_county) {
  all_age_groups <- c("0–4", "5–11", "12–19", "20–49", "50+", "Unknown")
  
  wide_cases <- filtered_data %>%
    mutate(
      county = as.character(county), 
      age_group = gsub("-", "–", age_group),
      age_group = factor(age_group, levels = all_age_groups, ordered = TRUE)
    ) %>%
    # Every age group appears for every county-year, even with zero cases.
    complete(
      county,
      year,
      age_group = all_age_groups,
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
    select(
      county,
      year,
      all_of(all_age_groups[all_age_groups %in% names(.)])
    )
  
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
    cols_label(
      county = "County",
      year = "Year",
      `0–4` = "0–4 Years",
      `5–11` = "5–11 Years",
      `12–19` = "12–19 Years",
      `20–49` = "20–49 Years",
      `50+` = "50+ Years",
      Unknown = "Unknown"
    ) %>%
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