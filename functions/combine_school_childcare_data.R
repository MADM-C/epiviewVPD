# Function to combine and standardize school and daycare data
# This function merges school and daycare datasets into a unified format
# Parameters:
#   school_data: sf dataframe containing school information
#   daycare_data: sf dataframe containing daycare information
#   school_name_col: column name for school names (default: "school_name")
#   daycare_name_col: column name for daycare names (default: "daycare_name")
# Returns: combined sf dataframe with standardized columns
combineSchoolDaycareData <- function(school_data, daycare_data,
                                     school_name_col = "school_name",
                                     daycare_name_col = "daycare_name") {
  # Initialize empty dataframes for cleaned data
  schools_clean <- NULL
  daycares_clean <- NULL

  # Process school data if available and valid
  if (!is.null(school_data) && nrow(school_data) > 0 && school_name_col %in% names(school_data)) {
    # Create standardized school dataframe with essential columns
    schools_clean <- data.frame(
      facility_name = school_data[[school_name_col]],
      facility_type = "School",
      full_vax_pct = if ("full_vax_pct" %in% names(school_data)) school_data$full_vax_pct else "N/A",
      partial_vax_pct = if ("partial_vax_pct" %in% names(school_data)) school_data$partial_vax_pct else "N/A",
      enrollment = if ("total_enrollment" %in% names(school_data)) school_data$total_enrollment else NA,
      contact_info = if ("contact_info" %in% names(school_data)) school_data$contact_info else "",
      stringsAsFactors = FALSE
    )

    # Preserve spatial geometry if it exists
    if ("geometry" %in% names(school_data)) {
      schools_clean$geometry <- school_data$geometry
    }

    # Remove rows with invalid facility names
    valid_names <- !is.na(schools_clean$facility_name) & schools_clean$facility_name != ""
    schools_clean <- schools_clean[valid_names, ]
  }

  # Process daycare data if available and valid
  if (!is.null(daycare_data) && nrow(daycare_data) > 0 && daycare_name_col %in% names(daycare_data)) {
    # Create standardized daycare dataframe with essential columns
    # Note: daycares don't have contact_info, so we'll add it as empty later
    daycares_clean <- data.frame(
      facility_name = daycare_data[[daycare_name_col]],
      facility_type = "Daycare",
      full_vax_pct = if ("full_vax_pct" %in% names(daycare_data)) daycare_data$full_vax_pct else "N/A",
      enrollment = if ("total_enroll" %in% names(daycare_data)) daycare_data$total_enroll else NA,
      stringsAsFactors = FALSE
    )

    # Preserve spatial geometry if it exists
    if ("geometry" %in% names(daycare_data)) {
      daycares_clean$geometry <- daycare_data$geometry
    }

    # Remove rows with invalid facility names
    valid_names <- !is.na(daycares_clean$facility_name) & daycares_clean$facility_name != ""
    daycares_clean <- daycares_clean[valid_names, ]
  }

  # Combine datasets based on what data is available
  if (!is.null(schools_clean) && nrow(schools_clean) > 0 && !is.null(daycares_clean) && nrow(daycares_clean) > 0) {
    # Both datasets exist - ensure they have matching columns before combining
    all_cols <- union(names(schools_clean), names(daycares_clean))

    # Add missing columns to schools dataframe
    for (col in setdiff(all_cols, names(schools_clean))) {
      schools_clean[[col]] <- if (col == "geometry") {
        sf::st_sfc(
          rep(sf::st_geometrycollection(), nrow(schools_clean)),
          crs = 4326
        )
      } else {
        ""
      } # Use empty string instead of NA for contact_info
    }

    # Add missing columns to daycares dataframe
    for (col in setdiff(all_cols, names(daycares_clean))) {
      daycares_clean[[col]] <- if (col == "geometry") {
        sf::st_sfc(
          rep(sf::st_geometrycollection(), nrow(daycares_clean)),
          crs = 4326
        )
      } else if (col == "contact_info") "" else NA # Explicitly handle contact_info as empty string
    }

    # Reorder columns to match and combine datasets
    schools_clean <- schools_clean[, all_cols]
    daycares_clean <- daycares_clean[, all_cols]
    return(rbind(schools_clean, daycares_clean))
  } else if (!is.null(schools_clean) && nrow(schools_clean) > 0) {
    # Only schools data available
    return(schools_clean)
  } else if (!is.null(daycares_clean) && nrow(daycares_clean) > 0) {
    # Only daycares data available - add empty contact_info column
    daycares_clean$contact_info <- ""
    return(daycares_clean)
  }

  # No valid data available
  return(NULL)
}
