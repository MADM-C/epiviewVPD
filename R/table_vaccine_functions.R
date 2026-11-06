# ==== GT TABLE HELPERS: vaccination coverage tables ====
# TODO(#20): parts of this file are specific to measles and MMR
# (labels such as "MMR Eligible", column names)

# Inputs below are the standard app data (load_app_data.R).

# District names by district_id (districts without boundaries)
build_district_lookup <- function(districts) {
  districts %>%
    select(district_name, district_id) %>%
    st_drop_geometry()
}

# `district_data` (from build_district_lookup()) is only used when
# boundary = "district".
build_school_table <- function(schools, boundary = "county", district_data = NULL) {
  school_df <- schools %>%
    st_drop_geometry()

  school_df <- if (boundary == "district") {
    school_df %>%
      left_join(district_data, by = "district_id") %>%
      mutate(area = district_name)
  } else {
    school_df %>%
      mutate(area = county_name)
  }

  school_df %>%
    mutate(
      area,
      name = school_name,
      type = school_type,
      full_vax_pct_chr = full_vax_pct, # retain the original string (e.g. ">95")
      full_vax_pct_num = suppressWarnings(
        as.numeric(str_extract(full_vax_pct, "[0-9.]+"))
      ),
      partial_vax_pct_chr = partial_vax_pct,
      partial_vax_pct_num = suppressWarnings(
        as.numeric(str_extract(partial_vax_pct, "[0-9]+"))
      ),
      # display column for the Enrollment column and sort option
      total_enrollment = enroll,
      .keep = "none"
    ) %>%
    filter(
      !is.na(total_enrollment),
      total_enrollment > 0,
      !is.na(full_vax_pct_num),
      # remove schools that did not report data (full & partial vax > 0)
      (full_vax_pct_num > 0 |
         partial_vax_pct_num > 0)
    ) %>%
    group_by(area, name, type, full_vax_pct_chr) %>%
    summarise(
      full_vax_pct = round(mean(full_vax_pct_num, na.rm = TRUE), 1),
      total_enrollment = sum(total_enrollment, na.rm = TRUE),
      .groups = "drop"
    ) %>%
    select(
      area,
      name,
      type,
      full_vax_pct,
      full_vax_pct_chr,
      total_enrollment
    ) %>%
    # Downstream filtering, sorting, and labels expect a `county` or `district` column.
    rename(!!boundary := area)
}

build_daycare_table <- function(facilities) {
  facilities %>%
    st_drop_geometry() %>%
    mutate(
      county = county_name,
      name = facility_name,
      # numeric helper from strings like "94.2", ">95", "95%"
      full_vax_pct_chr = full_vax_pct,
      is_blurred = grepl("^>", full_vax_pct),
      full_vax_pct = suppressWarnings(as.numeric(str_extract(full_vax_pct, "[0-9.]+"))),
      total_enrollment = enroll_eligible,
      .keep = "none"
    ) %>%
    filter(!is.na(total_enrollment)) %>%
    mutate(
      full_vax_pct = if_else(full_vax_pct > 100, 100, full_vax_pct, full_vax_pct)
    ) %>%
    select(
      county,
      name,
      full_vax_pct,
      full_vax_pct_chr,
      total_enrollment,
      is_blurred
    )
}

sort_coverage_table <- function(filtered_data, table_type, boundary_type, sort_by) {
  sort_col <- if (is.null(sort_by)) "full_vax_pct" else sort_by
  if (!sort_col %in% names(filtered_data)) sort_col <- "full_vax_pct"

  area_col <- if (table_type == "School Vaccine Coverage" && boundary_type == "district") {
    "district"
  } else {
    "county"
  }

  if (sort_col %in% c("name", area_col)) {
    filtered_data %>%
      arrange(tolower(.data[[sort_col]]))
  } else {
    filtered_data %>%
      arrange(desc(.data[[sort_col]]))
  }
}

# Cell colors for the coverage column. x = coverage numbers, chr = the
# coverage as published; blurred values (">95", "<5") are colored by the
# number they count as (pct_number(), load_app_data.R). Also used by
# inst/reports/gt_summary_report.Rmd.
# bands = coverage color bands (coverage_bands.R).
mmr_colors <- function(x, chr, bands = coverage_bands()) {
  x <- ifelse(grepl("^\\s*[<>]", chr), pct_number(chr, bands$blurred_offset), x)
  coverage_band_color(x, bands)
}

# nonreporting_note: source note under the school tables (settings
# notes$nonreporting_table, dashboard_settings.R); NULL leaves it out.
# redacted_childcares_note: the same for the child care table
# (notes$redacted_childcares).
# bands: coverage color bands (coverage_bands.R).
render_coverage_gt <- function(sorted_data,
                               table_type,
                               boundary_type,
                               selected_county,
                               selected_district,
                               nonreporting_note = default_settings()$notes$nonreporting_table,
                               redacted_childcares_note = default_settings()$notes$redacted_childcares,
                               bands = coverage_bands()) {
  area_name <- if (table_type == "School Vaccine Coverage" && boundary_type == "district") {
    selected_district
  } else {
    selected_county
  }

  table_gt <- sorted_data %>%
    gt() %>%
    tab_header(
      title = paste(table_type, "Vaccination Summary:", area_name)
    ) %>%
    # Display the original strings so blurred values keep their ">" sign.
    fmt(
      columns = full_vax_pct,
      fns = function(x) sorted_data$full_vax_pct_chr
    ) %>%
    data_color(
      columns = full_vax_pct,
      fn = function(x) mmr_colors(x, sorted_data$full_vax_pct_chr, bands)
    ) %>%
    cols_hide(columns = full_vax_pct_chr)

  if (table_type == "School Vaccine Coverage") {
    if (boundary_type == "county") {
      table_gt <- table_gt %>%
        cols_label(
          county           = "County",
          name             = "School Name",
          type             = "School Type",
          full_vax_pct     = "MMR %",
          total_enrollment = "Enrollment"
        )
    } else {
      table_gt <- table_gt %>%
        cols_label(
          district         = "School District",
          name             = "School Name",
          type             = "School Type",
          full_vax_pct     = "MMR %",
          total_enrollment = "Enrollment"
        )
    }
    if (!is.null(nonreporting_note)) {
      table_gt <- table_gt %>%
        tab_source_note(source_note = nonreporting_note)
    }
  } else if (table_type == "Child Care Vaccine Coverage") {
    table_gt <- table_gt %>%
      fmt(
        columns = full_vax_pct,
        fns = function(x) {
          ifelse(is.na(sorted_data$full_vax_pct_chr),
                 "Data redacted",
                 sorted_data$full_vax_pct_chr
          )
        }
      ) %>%
      cols_hide(columns = c(is_blurred)) %>%
      cols_label(
        county           = "County",
        name             = "Child Care Name",
        full_vax_pct     = "MMR %",
        total_enrollment = "MMR Eligible"
      )
    if (!is.null(redacted_childcares_note)) {
      table_gt <- table_gt %>%
        tab_source_note(source_note = redacted_childcares_note)
    }
  }

  table_gt
}
