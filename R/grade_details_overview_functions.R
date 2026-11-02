# ============================================================
# Create Overview with District/County and Demographic Details
# ============================================================

# ============================================================
# Pull metrics needed to create high-level facility overview
# ============================================================

get_facility_metrics <- function(is_school, is_childcare,
                                 school_id, facility_data = NULL,
                                 county_data = NULL,
                                 district_data = NULL, grade_data = NULL) {
  if (isTRUE(is_school)) {
    # --- check if the school was a non-responder, did not report data to MDH ---
    nonresponder_status <- is_nonresponder(school_id, school_data = facility_data)

    # --- basic vaccination coverage information needed for dashboard ---

    # school enrollment (MDE = total_enrollment; MDH = enroll)

    total_enrollment <- facility_data |>
      filter(mde_school_id == school_id) |>
      mutate(eff_enrollment = coalesce(total_enrollment, enroll)) |>
      pull(eff_enrollment) |>
      _[1]

    # school overall coverage

    overall_cov <- facility_data |>
      filter(mde_school_id == school_id) |>
      pull(full_vax_pct) |>
      _[1]

    # identify school type (private/public/charter)

    school_type <- facility_data |>
      filter(mde_school_id == school_id) |>
      pull(sch_type) |>
      _[1]

    # pull county name/ID

    county_name_school <- facility_data |>
      dplyr::filter(mde_school_id == school_id) |>
      pull(COUNTYNAME) |>
      _[1]

    # pull county vaccination coverage

    county_vax <- county_data |>
      dplyr::filter(county_name == county_name_school) |>
      pull(full_vax_pct) |>
      _[1]

    # --- check what additional levels of data are available ---

    # additional school-level details ---
    has_gradelevel <- !is.null(grade_data)
    has_partial <- "partial_vax_pct" %in% colnames(facility_data)
    has_exemptions <- "medical_pct" %in% colnames(facility_data) && "nonmedical_pct" %in% colnames(facility_data)

    if (has_gradelevel) {
      # identify how many grades are in the school
      grade_rows <- grade_data |>
        filter(mde_school_id == school_id)
      # check if all grade-level data is redacted
      all_grades_redacted <-
        nrow(grade_rows) > 0 &&
          all(is.na(grade_rows$full_vax_pct))
    } else {
      grade_rows <- NULL
      all_grades_redacted <- NULL
    }

    # school partial vaccination coverage
    if (has_partial) {
      partial_vax <- facility_data |>
        filter(mde_school_id == school_id) |>
        pull(partial_vax_pct) |>
        _[1]
    } else {
      partial_vax <- NULL
    }

    # school vaccination exemptions
    if (has_exemptions) {
      # medical exemption
      med_exempt <- facility_data |>
        filter(mde_school_id == school_id) |>
        pull(medical_pct) |>
        _[1]
      # non medical exemption
      nonmed_exempt <- facility_data |>
        filter(mde_school_id == school_id) |>
        pull(nonmedical_pct) |>
        _[1]
    } else {
      med_exempt <- NULL
      nonmed_exempt <- NULL
    }

    # district-level data ---
    has_anydistrict <- !is.null(district_data)
    has_languages <- "languages_display" %in% colnames(facility_data) # add this to district data instead of school/facility data?
    has_districtvax <- "full_vax_pct_num" %in% colnames(district_data)

    # pull district name/ID
    if (has_anydistrict) {
      district_key <- facility_data |>
        dplyr::filter(mde_school_id == school_id) |>
        pull(mde_district_key) |>
        _[1]

      district_name <- district_data |>
        dplyr::filter(join_key == district_key) |>
        pull(PREFNAME) |>
        _[1]
    } else {
      district_name <- NULL
    }

    # most common languages spoken across the district
    if (has_languages) {
      languages <- facility_data |>
        filter(mde_school_id == school_id) |>
        pull(languages_display) |>
        _[1]
    } else {
      languages <- NULL
    }

    # pull district vaccination coverage
    if (has_districtvax) {
      district_vax <- district_data |>
        dplyr::filter(join_key == district_key) |>
        pull(full_vax_pct_num) |>
        _[1]
    } else {
      district_vax <- NULL
    }

    # --- Return all values in a named list

    list(
      school_type = school_type,
      total_enrollment = total_enrollment,
      languages = languages,
      district_name = district_name,
      district_vax = district_vax,
      county_name_school = county_name_school,
      county_vax = county_vax,
      overall_cov = overall_cov,
      grade_rows = grade_rows,
      all_grades_redacted = all_grades_redacted,
      nonresponder_status = nonresponder_status,
      med_exempt = med_exempt,
      nonmed_exempt = nonmed_exempt,
      partial_vax = partial_vax
    )
  } else if (is_childcare) {
    overall_cov <- facility_data |>
      filter(idsch == school_id) |>
      pull(full_vax_pct) |>
      _[1]
    total <- facility_data |>
      filter(idsch == school_id) |>
      pull(total_enroll) |>
      _[1]
    total_elig <- facility_data |>
      filter(idsch == school_id) |>
      pull(enroll_mmreligible) |>
      _[1]
    county_name_daycare <- facility_data |>
      filter(idsch == school_id) |>
      pull(COUNTYNAME) |>
      _[1]
    county_vax <- county_data |>
      dplyr::filter(county_name == county_name_daycare) |>
      pull(full_vax_pct) |>
      _[1]

    list(
      overall_cov = overall_cov,
      total = total,
      total_elig = total_elig,
      county_name_daycare = county_name_daycare,
      county_vax = county_vax
    )
  }
}

# ============================================================
# School-specific function to render high-level overview
# using the inputs from get_facility_metrics()
# ===========================================================

render_school_overview <- function(
  school_id,
  selected_location,
  school_type,
  total_enrollment,
  languages,
  district_name,
  district_vax,
  county_name_school,
  county_vax,
  overall_cov,
  grade_rows,
  all_grades_redacted,
  nonresponder_status,
  med_exempt,
  nonmed_exempt,
  partial_vax
) {
  # base level overview with only school-wide and county-wide data
  tagList(
    tags$h4("MMR Coverage in Schools by Grade-Level", class = "grade-details-heading"),
    tags$div(stringr::str_wrap(selected_location, width = 65), class = "grade-details-facility"),
    tags$p(tags$strong("School Type: "), school_type, class = "grade-details-details"),
    tags$p(tags$strong("Total Enrollment*: "), ifelse(is.na(total_enrollment), "N/A", total_enrollment), class = "grade-details-details"),
    tags$p(tags$strong("Schoolwide MMR Coverage: "),
      ifelse(isTRUE(nonresponder_status), "Data Unavailable", format_vax_pct(overall_cov)),
      class = "grade-details-details"
    ),
    # additional vaccination data
    if (!is.null(partial_vax)) {
      tagList(
        tags$li(tags$strong("- Partially Vaccinated / No Doses: "), format_vax_pct(partial_vax), class = "grade-details-bullet")
      )
    },
    if (!is.null(med_exempt) && !is.null(nonmed_exempt)) {
      tagList(
        tags$li(tags$strong("- Medical Exemption: "), format_vax_pct(med_exempt), class = "grade-details-bullet"),
        tags$li(tags$strong("- Non-Medical Exemption: "), format_vax_pct(nonmed_exempt), class = "grade-details-bullet")
      )
    },
    # county-level data (always include)
    tags$p(tags$strong(paste0(county_name_school, " County MMR Coverage: ")), format_vax_pct(county_vax), class = "grade-details-details"),
    # district-level data
    if (!is.null(district_name) && !is.null(district_vax)) {
      if (!is.na(school_type) && school_type == "Charter") {
        tagList(
          tags$p(tags$strong("District MMR Coverage: "), "Not available for charter schools.", class = "grade-details-details")
        )
      } else {
        tagList(
          tags$p(tags$strong(paste0(district_name, " MMR Coverage: ")), format_vax_pct(district_vax), class = "grade-details-details")
        )
      }
    },
    # district language data
    if (!is.null(languages)) {
      if (!is.na(school_type) && school_type == "Charter") {
        tagList(
          tags$p(tags$strong("School Home Languages: "), languages, class = "grade-details-details")
        )
      } else {
        tags$p(tags$strong("District Home Languages: "), languages, class = "grade-details-details")
      }
    },
    # based on data available, render footnote + table + plot

    if (!is.na(overall_cov) && isTRUE(all_grades_redacted)) {
      tagList(
        tags$p("Grade-level vaccination data are redacted because fewer than 10 students were enrolled in each grade.",
          tags$br(),
          "The overall coverage reflects total reported students across all grades.",
          tags$br(),
          "*Enrollment counts may differ between MDH and MDE records.",
          class = "grade-details-footnote"
        )
      )
    } else if (isTRUE(nonresponder_status)) {
      tagList(
        tags$p("MMR vaccination coverage is unavailable for schools that did not report data to MDH.",
          tags$br(),
          "*Enrollment counts may differ between MDH and MDE records.",
          class = "grade-details-footnote"
        )
      )
    } else {
      tagList(
        tags$div(
          style = "display: flex; flex-direction: row; gap: 20px;",
          tags$div(plotOutput("grade_plot", height = "250px", width = "350px")),
          tags$div(tableOutput("grade_table"))
        ),
        tags$p(
          HTML(
            paste0(
              "<em>",
              "Redacted indicates the number of eligible students was fewer than 10. Blurred values (e.g., '>95%') are intentionally rounded up for privacy.<br><br>",
              "*Enrollment counts may differ between MDH and MDE records.",
              "</em>"
            )
          ),
          class = "grade-details-footnote"
        )
      )
    }
  )
}

# ============================================================
# Childcare-specific function to render high-level overview
# using the inputs from get_facility_metrics()
# ===========================================================

render_childcare_overview <- function(
  school_id,
  facility_data = NULL,
  overall_cov,
  total,
  total_elig,
  county_name_daycare,
  county_vax
) {
  tagList(
    tags$h4("MMR Coverage in Child Cares", class = "grade-details-heading"),
    tags$div(stringr::str_wrap(facility_data[facility_data$idsch == school_id, ]$daycare_name, width = 65), class = "grade-details-facility"),
    tags$p(tags$strong("Total Enrollment*:"), ifelse(is.na(total), "N/A", total), class = "grade-details-details"),
    tags$p(tags$strong("Total Eligible: "), ifelse(is.na(total_elig), "N/A", total_elig), class = "grade-details-details"),
    tags$p(tags$strong("Child Care MMR Coverage: "), format_vax_pct(overall_cov), class = "grade-details-details"),
    tags$p(tags$strong(paste0(county_name_daycare, " MMR Coverage")), format_vax_pct(county_vax), class = "grade-details-details"),
    tags$p(
      HTML(
        paste0(
          "<em>",
          "Redacted indicates the number of eligible students was fewer than 10. Blurred values (e.g., '>95%') are intentionally rounded up for privacy.<br><br>",
          "*Enrollment counts may differ between MDH and MDE records.",
          "</em>"
        )
      ),
      class = "grade-details-footer"
    )
  )
}
