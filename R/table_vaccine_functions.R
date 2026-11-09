# ==== GT TABLE HELPERS: vaccination coverage tables ====
# Parts of this file are specific to measles and MMR (labels such as
# "MMR Eligible", column names).

# Inputs below are the standard app data (load_app_data.R).

# District names by district_id (districts without boundaries)
build_district_lookup <- function(districts) {
  if (is.null(districts) || !all(c("district_name", "district_id") %in% names(districts))) {
    return(data.frame(district_name = character(), district_id = character()))
  }
  districts %>%
    select(district_name, district_id) %>%
    st_drop_geometry()
}

# `district_data` (from build_district_lookup()) is only used when
# boundary = "district".
build_school_table <- function(schools, boundary = "county", district_data = NULL) {
  school_df <- table_columns(schools, list(school_name = NA_character_,
    school_type = NA_character_, county_name = NA_character_, district_id = NA_character_,
    full_vax_pct = NA_character_, partial_vax_pct = NA_character_, enroll = NA_real_))
  # Blanks the vaccination values of schools marked not reporting.
  school_df <- mask_not_reported(school_df)

  school_df <- if (boundary == "district") {
    school_df %>%
      left_join(district_data, by = "district_id") %>%
      mutate(area = dplyr::coalesce(district_name, "No linked district"))
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
    mutate(full_vax_pct = full_vax_pct_num) %>%
    select(
      area,
      name,
      type,
      full_vax_pct,
      full_vax_pct_chr,
      total_enrollment
    ) %>%
    # Names the column `county` or `district`.
    rename(!!boundary := area)
}

build_daycare_table <- function(facilities) {
  table_columns(facilities, list(county_name = NA_character_, facility_name = NA_character_,
    full_vax_pct = NA_character_, enroll_eligible = NA_real_)) %>%
    mask_not_reported() %>%
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
    # Shows the original strings, with the ">" sign on blurred values.
    fmt(
      columns = full_vax_pct,
      fns = function(x) coverage_display(sorted_data$full_vax_pct_chr)
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
    if (all(is.na(sorted_data$type))) {
      table_gt <- table_gt %>% cols_hide(columns = type)
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
          coverage_display(sorted_data$full_vax_pct_chr)
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
