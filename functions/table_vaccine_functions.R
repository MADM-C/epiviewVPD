# ==== GT TABLE HELPERS: vaccination coverage tables ==== 
# NOTE: There are multiple points in this code that will need to be edited
# in the future so that it's better able to handle being adapted to different
# diseases

build_district_lookup <- function(district_map_data) {
  district_map_data %>%
    select(PREFNAME, join_key) %>%
    st_drop_geometry()
}

# `district_data` is only used when boundary = "district".
build_school_table <- function(school_demo_joined, boundary = "county", district_data = NULL) {
  school_df <- school_demo_joined %>%
    st_drop_geometry()
  
  school_df <- if (boundary == "district") {
    school_df %>%
      left_join(district_data, by = c("mde_district_key" = "join_key")) %>%
      mutate(area = PREFNAME)
  } else {
    school_df %>%
      mutate(area = str_to_title(COUNTYNAME))
  }
  
  school_df %>%
    mutate(
      area,
      name = school_name,
      type = sch_type,
      full_vax_pct_chr = full_vax_pct, # retain the original string (e.g. ">95")
      full_vax_pct_num = suppressWarnings(
        as.numeric(str_extract(full_vax_pct, "[0-9.]+"))
      ),
      partial_vax_pct_chr = partial_vax_pct,
      partial_vax_pct_num = suppressWarnings(
        as.numeric(str_extract(partial_vax_pct, "[0-9]+"))
      ),
      total_enrollment,
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

build_daycare_table <- function(daycare_joined) {
  daycare_joined %>%
    st_drop_geometry() %>%
    mutate(
      county = str_to_title(COUNTYNAME),
      name = daycare_name,
      # numeric helper from strings like "94.2", ">95", "95%"
      full_vax_pct_chr = full_vax_pct,
      is_blurred = grepl("^>", full_vax_pct),
      full_vax_pct = suppressWarnings(as.numeric(str_extract(full_vax_pct, "[0-9.]+"))),
      total_enrollment = enroll_mmreligible,
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

# `chr` is the original coverage string; values starting with ">" are blurred.
mmr_colors <- function(x, chr) {
  out <- rep("gray", length(x))
  
  out[grepl("^>", chr)] <- "darkgreen"
  out[!grepl("^>", chr) & !is.na(x) & x < 85] <- "red"
  out[!grepl("^>", chr) & !is.na(x) & x >= 85 & x < 90] <- "orange"
  out[!grepl("^>", chr) & !is.na(x) & x >= 90 & x < 95] <- "gold"
  out[!grepl("^>", chr) & !is.na(x) & x >= 95] <- "darkgreen"
  out
}

render_coverage_gt <- function(sorted_data,
                               table_type,
                               boundary_type,
                               selected_county,
                               selected_district) {
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
      fn = function(x) mmr_colors(x, sorted_data$full_vax_pct_chr)
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
        ) %>%
        tab_source_note(
          source_note = "Schools that did not report MMR vaccination coverage to MDH are not displayed."
        )
    } else {
      table_gt <- table_gt %>%
        cols_label(
          district         = "School District",
          name             = "School Name",
          type             = "School Type",
          full_vax_pct     = "MMR %",
          total_enrollment = "Enrollment"
        ) %>%
        tab_source_note(
          source_note = "Schools that did not report MMR vaccination coverage to MDH are not displayed."
        )
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
      ) %>%
      tab_source_note(
        source_note = "MMR coverage is not displayed for facilities with fewer than 10 enrolled children."
      )
  }
  
  table_gt
}