# ============================================================
# LOAD THE DASHBOARD'S DATA
# ============================================================
# load_app_data() reads the data folder (CSV files, see DATA_FILES
# below), gets the county and school district boundaries, and returns the
# app data, one object per layer, with the same column names for the same
# thing in every layer:
#
#   counties            sf, one row per county (polygons + coverage)
#   schools             sf, one row per school (points)
#   facilities          sf, one row per child care (points; empty point
#                       when it has no location)
#   grades              one row per school and grade
#   districts           sf, one row per school district (polygons + coverage)
#   cases               one row per county, year and age group
#   healthcare_centers  sf, one row per healthcare center (points)
#
# Called by run_dashboard(); the result goes to app_server().
#
# Boundaries are downloaded from the U.S. Census Bureau (tigris) for the
# state in the settings, unless the data folder has its own
# county_boundaries.geojson / district_boundaries.geojson.
#
# Values are read as given. The loader builds geometry, finds each row's
# county in the boundaries (by county_fips, else county_name, else the
# coordinates), and adds full_vax_pct_num (the coverage as a number, for
# colors and sorting). It checks the files and stops with one message
# listing every problem found. Values worth checking (a school's
# district_id with no boundary) give one warning (report_notes() below).
# reporting_status = "not_reported" blanks a row's vaccination values and
# keeps its enrollment.
# The selected features set which files are required. Outputs with no map
# use the county columns in the data and do not download boundaries.
# ============================================================

# Files in the data folder, and the columns each must have. Optional
# columns may be left out; the loader adds them with blank values.
# county = TRUE: each row needs a county, by county_fips or county_name
# (for points, the coordinates do if both are blank).
# boundaries = TRUE: optional file; downloaded from the Census if missing.
DATA_FILES <- list(
  counties = list(
    file = "counties.csv",
    required = c("enroll", "full_vax_pct"),
    optional = c("county_fips", "county_name", "full_vax", "students_of_color_pct", "frl_eligible_pct", "reporting_status"),
    numbers = c("enroll", "full_vax", "students_of_color_pct", "frl_eligible_pct"),
    county = TRUE
  ),
  county_boundaries = list(
    file = "county_boundaries.geojson",
    required = "county_name",
    optional = "county_fips",
    boundaries = TRUE
  ),
  schools = list(
    file = "schools.csv",
    required = c("school_id", "school_name", "latitude", "longitude", "enroll", "full_vax_pct"),
    optional = c("full_vax", "partial_vax", "partial_vax_pct", "medical_pct", "nonmedical_pct",
                 "school_type", "grade_range", "address", "county_fips", "county_name", "district_id",
                 "contact_info", "home_languages", "reporting_status"),
    numbers = c("enroll", "full_vax", "partial_vax"),
    county = TRUE
  ),
  facilities = list(
    file = "facilities.csv",
    required = c("facility_id", "facility_name", "latitude", "longitude", "enroll", "full_vax_pct"),
    optional = c("full_vax", "enroll_eligible", "county_fips", "county_name", "reporting_status"),
    numbers = c("enroll", "full_vax", "enroll_eligible"),
    county = TRUE
  ),
  grades = list(
    file = "grades.csv",
    required = c("school_id", "grade", "enroll", "full_vax_pct"),
    optional = c("full_vax", "partial_vax_pct", "medical_pct", "nonmedical_pct", "reporting_status"),
    numbers = c("enroll", "full_vax")
  ),
  districts = list(
    file = "districts.csv",
    required = c("district_id", "district_name", "enroll", "full_vax_pct"),
    optional = c("full_vax", "reporting_status"),
    numbers = c("enroll", "full_vax")
  ),
  district_boundaries = list(
    file = "district_boundaries.geojson",
    required = "district_id",
    boundaries = TRUE
  ),
  cases = list(
    file = "cases.csv",
    required = c("year", "n_cases"),
    optional = c("county_fips", "county_name", "age_group"),
    numbers = c("year", "n_cases"),
    county = TRUE
  ),
  healthcare_centers = list(
    file = "healthcare_centers.csv",
    required = c("name", "latitude", "longitude")
  )
)

# Input:  data_dir = folder with the files in DATA_FILES;
#         suppressed_offset = how far past its number a suppressed
#         percentage (">95", "<5") is counted in full_vax_pct_num;
#         redacted_codes = values that mean "withheld" (e.g. "*"), read as
#         blank in the count and percentage columns
#         (both from the settings' suppression entry, dashboard_settings.R);
#         geography = the settings' geography entry: state (for the Census
#         boundaries), district_type, year;
#         case_age_groups = the settings' case age groups; cases.csv may
#         only use these (NULL: any, see case_age_groups.R)
# Output: named list of app data objects (see top of file)
#' Data layers required by selected features
#' @param features A partial named list of logical feature switches.
#' @return Names of required input layers. Facility/proximity outputs additionally
#'   need at least one of schools or facilities. Districts and healthcare centers
#'   are optional. Boundary layers can be downloaded for geography$state.
#' @export
required_data_layers <- function(features = default_features()) {
  f <- normalize_features(features)
  needed <- character()
  if (f$coverage_map) needed <- c(needed, "counties")
  if (any(unlist(f[c("coverage_map", "cases_map", "facility_map", "proximity_map")]))) needed <- c(needed, "county_boundaries")
  if (any(unlist(f[c("school_summary", "grade_plot", "grade_table")]))) needed <- c(needed, "schools")
  if (f$childcare_summary) needed <- c(needed, "facilities")
  if (f$grade_plot || f$grade_table) needed <- c(needed, "grades")
  if (any(unlist(f[c("cases_map", "cases_summary", "epicurve")]))) needed <- c(needed, "cases")
  unique(needed)
}

# Input:  path to a data folder
# Output: feature switches with every feature on whose data files are in the
#         folder. Used when load_app_data() is called without features.
features_for_files <- function(data_dir) {
  has_file <- function(layer) file.exists(file.path(data_dir, DATA_FILES[[layer]]$file))
  features <- all_features()
  for (name in names(features)) {
    only <- lapply(features, function(x) FALSE)
    only[[name]] <- TRUE
    needed <- setdiff(required_data_layers(only), "county_boundaries")
    points <- name %in% c("facility_map", "facility_overview", "proximity_map", "proximity_table")
    features[[name]] <- all(vapply(needed, has_file, TRUE)) &&
      (!points || has_file("schools") || has_file("facilities"))
  }
  features
}

empty_data_layer <- function(layer, spatial = FALSE) {
  spec <- DATA_FILES[[layer]]
  columns <- unique(c(spec$required, spec$optional))
  x <- as.data.frame(stats::setNames(lapply(columns, function(col) {
    if (col %in% c(spec$numbers, "latitude", "longitude")) numeric() else character()
  }), columns), stringsAsFactors = FALSE)
  if (spatial) {
    x$latitude <- x$longitude <- NULL
    x <- sf::st_sf(x, geometry = sf::st_sfc(crs = 4326))
  }
  x
}

# Blanks the vaccination values of rows marked reporting_status = "not_reported".
mask_not_reported <- function(x) {
  if (!"reporting_status" %in% names(x)) x$reporting_status <- rep(NA_character_, nrow(x))
  rows <- !is.na(x$reporting_status) & x$reporting_status == "not_reported"
  measurements <- intersect(names(x), c("full_vax", "partial_vax", "full_vax_pct",
                                        "partial_vax_pct", "medical_pct", "nonmedical_pct",
                                        "full_vax_pct_num"))
  for (col in measurements) x[[col]][rows] <- NA
  x
}

#' Load data for selected dashboard visualizations
#' @param data_dir Folder containing CSV and optional GeoJSON files.
#' @param suppressed_offset Numeric offset for bounded percentages.
#' @param redacted_codes Text codes indicating withheld measurements.
#' @param geography State, district type, and optional boundary year.
#' @param case_age_groups Optional allowed case age groups.
#' @param features A partial named list of logical feature switches. `NULL`
#'   (the default) uses every feature whose data files are in the folder.
#' @param case_data Case count settings; missing_records is "zero" by
#'   default, so a county/year/age combination with no row counts as zero, or
#'   "unknown" when the source may leave out unreported combinations. A row with
#'   a blank or withheld count stays unknown under either setting.
#' @return A named list of typed data objects, including empty objects for unused
#'   layers. The cases table has the missing_records setting attached.
#' @export
load_app_data <- function(data_dir, suppressed_offset = 1, redacted_codes = character(0),
                          geography = list(state = NULL, district_type = "unified", year = NULL),
                          case_age_groups = NULL, features = NULL,
                          case_data = list(missing_records = "zero")) {
  if (is.null(features)) {
    if (!dir.exists(data_dir)) stop("The data folder \"", data_dir, "\" doesn't exist.", call. = FALSE)
    features <- features_for_files(data_dir)
  }
  features <- normalize_features(features)
  policy <- case_data$missing_records
  if (!is.character(policy) || length(policy) != 1L || is.na(policy) || !policy %in% c("unknown", "zero")) {
    stop("case_data$missing_records has to be 'unknown' or 'zero'", call. = FALSE)
  }
  data_features <- setdiff(names(features), c("about", "resources"))
  if (any(unlist(features[data_features])) && !dir.exists(data_dir)) {
    stop("The data folder \"", data_dir, "\" doesn't exist.", call. = FALSE)
  }
  files <- vapply(DATA_FILES, `[[`, "", "file")
  available <- file.exists(file.path(data_dir, files))
  names(available) <- names(DATA_FILES)
  required <- required_data_layers(features)
  missing <- setdiff(required[!available[required]], c("county_boundaries", "district_boundaries"))
  points_needed <- any(unlist(features[c("facility_map", "facility_overview", "proximity_map", "proximity_table")]))
  coordinates_needed <- any(unlist(features[c("facility_map", "proximity_map", "proximity_table")]))
  if (points_needed && !any(available[c("schools", "facilities")])) missing <- c(missing, "schools or facilities")
  if (length(missing)) {
    missing_files <- vapply(missing, function(x) if (x %in% names(files)) files[[x]] else "schools.csv or facilities.csv", "")
    stop("The data folder \"", data_dir, "\" is missing files required by enabled features: ",
         paste(missing_files, collapse = ", "),
         ". Supply these files in that folder, or disable every feature that uses them.", call. = FALSE)
  }

  # Optional layers for tables and plots.
  relevant <- required
  if (points_needed) relevant <- c(relevant, "schools", "facilities")
  if (features$facility_overview) relevant <- c(relevant, "counties")
  district_spatial_use <- any(unlist(features[c("coverage_map", "facility_map", "proximity_map")]))
  district_use <- district_spatial_use || any(unlist(features[c("facility_overview", "school_summary")]))
  if (district_use) relevant <- c(relevant, "districts")
  if (features$proximity_map) relevant <- c(relevant, "healthcare_centers")
  if (district_spatial_use && (available[["district_boundaries"]] ||
      (available[["districts"]] && !is.null(geography$state)))) relevant <- c(relevant, "district_boundaries")
  relevant <- unique(relevant)
  load <- relevant[available[relevant] | relevant %in% c(intersect(required, "county_boundaries"), "district_boundaries")]
  problems <- new_problem_list()
  raw <- stats::setNames(lapply(names(DATA_FILES), empty_data_layer), names(DATA_FILES))
  for (layer in load) {
    raw[[layer]] <- if (!available[[layer]] && isTRUE(DATA_FILES[[layer]]$boundaries)) {
      download_boundaries(layer, geography, problems)
    } else read_data_file(data_dir, layer, problems, redacted_codes,
                          require_coordinates = !layer %in% c("schools", "facilities") || coordinates_needed)
  }
  if (problems$blocking()) report_problems(problems, data_dir)
  for (layer in intersect(load, c("counties", "cases"))) {
    if (nrow(raw[[layer]]) && all(is.na(raw[[layer]]$county_fips)) && all(is.na(raw[[layer]]$county_name))) {
      problems$add_blocking(DATA_FILES[[layer]]$file, ": needs a county_fips or county_name column",
        " containing nonblank county identifiers; both identifiers are blank", input_row_details(seq_len(nrow(raw[[layer]]))),
        ". Supply at least one county identifier for every observation, preserving leading zeros in FIPS codes.")
    }
  }
  if (problems$blocking()) report_problems(problems, data_dir)

  # TRUE if a point has coordinates but no county_fips or county_name.
  needs_local_county_lookup <- function(x) {
    if (!nrow(x)) return(FALSE)
    latitude <- suppressWarnings(as.numeric(x$latitude))
    longitude <- suppressWarnings(as.numeric(x$longitude))
    missing_county <- is.na(x$county_fips) & is.na(x$county_name)
    any(missing_county & is.finite(latitude) & abs(latitude) <= 90 &
          is.finite(longitude) & abs(longitude) <= 180)
  }
  if (!"county_boundaries" %in% load && available[["county_boundaries"]] &&
      any(vapply(raw[c("schools", "facilities")], needs_local_county_lookup, TRUE))) {
    raw$county_boundaries <- read_data_file(data_dir, "county_boundaries", problems)
    if (problems$blocking()) report_problems(problems, data_dir)
  }
  validate_input_references(raw, load, problems)

  county_bounds <- raw$county_boundaries
  has_bounds <- inherits(county_bounds, "sf") && nrow(county_bounds) > 0
  if (has_bounds) {
    check_unique(county_bounds$county_name, boundary_source(county_bounds), "county_name", problems, ignore_case = TRUE)
    if (!all(is.na(county_bounds$county_fips))) check_unique(county_bounds$county_fips, boundary_source(county_bounds), "county_fips", problems)
  } else {
    county_layers <- c("counties", "schools", "facilities", "cases")
    raw[county_layers] <- reconcile_county_aliases(raw[county_layers], problems)
    if (problems$blocking()) report_problems(problems, data_dir)
    check_unique(raw$counties$county_name, "counties.csv", "county_name/county_fips", problems)
  }
  # Uses the boundaries if available, otherwise the county columns in the file.
  resolve_county_metadata <- function(x, file, allow_missing = TRUE) {
    if (has_bounds) return(add_counties(x, county_bounds, file, problems))
    missing_name <- is.na(x$county_name) | !nzchar(x$county_name)
    x$county_name[missing_name] <- x$county_fips[missing_name]
    if (!allow_missing && any(is.na(x$county_name))) problems$add(file,
      ": needs county_name or county_fips for each row", input_row_details(which(is.na(x$county_name))),
      ". Supply at least one nonblank county identifier for each observation.")
    x
  }
  point_data <- function(layer, allow_empty) {
    x <- as_points(raw[[layer]], files[[layer]], problems, allow_empty)
    resolve_county_metadata(x, files[[layer]])
  }
  schools <- point_data("schools", allow_empty = !coordinates_needed)
  facilities <- point_data("facilities", allow_empty = TRUE)
  known_point_counties <- c(schools$county_name, facilities$county_name)
  if (!has_bounds) {
    schools$county_name[is.na(schools$county_name)] <- "Unknown county"
    facilities$county_name[is.na(facilities$county_name)] <- "Unknown county"
  }
  healthcare_centers <- as_points(raw$healthcare_centers, "healthcare_centers.csv", problems, allow_empty = FALSE)
  if (has_bounds) {
    counties <- join_counties(county_bounds, raw$counties, problems)
    case_counties <- counties$county_name
  } else {
    counties <- resolve_county_metadata(raw$counties, "counties.csv", allow_missing = FALSE)
    case_counties <- c(counties$county_name, known_point_counties)
    metadata <- unique(rbind(
      counties[c("county_name", "county_fips")], schools[c("county_name", "county_fips")] |> sf::st_drop_geometry(),
      facilities[c("county_name", "county_fips")] |> sf::st_drop_geometry(), raw$cases[c("county_name", "county_fips")]
    ))
    metadata$county_name[is.na(metadata$county_name)] <- metadata$county_fips[is.na(metadata$county_name)]
    # Gives a row with no county_fips the ID of the county with the same name.
    named_ids <- metadata[!is.na(metadata$county_fips), , drop = FALSE]
    missing_ids <- is.na(metadata$county_fips)
    metadata$county_fips[missing_ids] <- named_ids$county_fips[
      match(metadata$county_name[missing_ids], named_ids$county_name)]
    metadata <- metadata[!is.na(metadata$county_name) & !duplicated(metadata$county_name), , drop = FALSE]
    idx <- match(metadata$county_name, counties$county_name)
    expanded <- counties[idx, , drop = FALSE]
    expanded$county_name <- metadata$county_name
    expanded$county_fips <- metadata$county_fips
    rownames(expanded) <- NULL
    counties <- sf::st_sf(expanded, geometry = sf::st_sfc(lapply(seq_len(nrow(expanded)), function(i) sf::st_polygon()), crs = 4326))
  }
  if (inherits(raw$district_boundaries, "sf") && nrow(raw$district_boundaries)) {
    districts <- join_districts(raw$district_boundaries, raw$districts, problems)
    districts$district_name[is.na(districts$district_name)] <- districts$district_id[is.na(districts$district_name)]
  } else {
    check_unique(raw$districts$district_id, "districts.csv", "district_id", problems)
    districts <- sf::st_sf(raw$districts, geometry = sf::st_sfc(lapply(seq_len(nrow(raw$districts)), function(i) sf::st_polygon()), crs = 4326))
  }
  raw$cases$age_group <- trimws(raw$cases$age_group)
  check_age_groups(raw$cases, case_age_groups, problems)
  cases <- resolve_county_metadata(raw$cases, "cases.csv", allow_missing = FALSE)
  if (!has_bounds) case_counties <- c(case_counties, cases$county_name)
  if (nrow(cases) && anyDuplicated(cases[c("county_name", "year", "age_group")])) {
    keys <- cases[c("county_name", "year", "age_group")]
    duplicate <- which(duplicated(keys) | duplicated(keys, fromLast = TRUE))
    problems$add("cases.csv: county/year/age_group records must be unique; found ",
      input_value_details(paste0("county=", cases$county_name[duplicate], ", year=", cases$year[duplicate],
                                ", age_group=", ifelse(is.na(cases$age_group[duplicate]), "<blank>", cases$age_group[duplicate]))),
      input_row_details(duplicate), ". Keep one non-overlapping observation per county, year, and age group.")
  }
  cases$year <- suppressWarnings(as.integer(cases$year))
  cases$n_cases <- suppressWarnings(as.integer(cases$n_cases))
  attr(cases, "missing_records") <- policy
  grades <- raw$grades
  check_unique(schools$school_id, "schools.csv", "school_id", problems)
  check_unique(facilities$facility_id, "facilities.csv", "facility_id", problems)
  for (layer in c("counties", "schools", "facilities", "districts", "grades")) {
    x <- get(layer)
    x <- mask_not_reported(x)
    x$full_vax_pct_num <- pct_number(x$full_vax_pct, suppressed_offset)
    assign(layer, x)
  }
  attr(counties, "universe_complete") <- has_bounds
  # County names that count as case reporting units; fallback labels are left out.
  attr(counties, "case_counties") <- unique(case_counties[!is.na(case_counties) & nzchar(case_counties)])
  report_problems(problems, data_dir)
  report_notes(problems, data_dir)
  out <- list(counties = counties, schools = schools, facilities = facilities,
              grades = grades, districts = districts, cases = cases,
              healthcare_centers = healthcare_centers)
  attr(out, "features") <- features
  attr(out, "case_missing_records") <- policy
  out
}

# ---- Reading ---------------------------------------------------------------

# Input:  problems = the loader's problem list; file = the CSV's name;
#         reason = why it can't be read
# Output: none; adds a blocking problem. Used by read_data_file() and
#         csv_path_as_utf8().
add_csv_read_problem <- function(problems, file, reason) {
  problems$add_blocking(file, ": can't be read as CSV (", reason,
    "). Save comma-separated UTF-8 text with a header row; quote text containing commas or newlines and close every quoted field.")
}

# Input:  path = a CSV file; file = its name for messages; problems = the
#         loader's problem list
# Output: the path read_data_file() should read as UTF-8: `path` for a UTF-8
#         file or one that can't be opened (read.csv reports that), or a
#         temporary UTF-8 copy of a Windows-1252 file, with a note. The caller
#         deletes the copy. NULL, with a blocking problem, for any other bytes.
csv_path_as_utf8 <- function(path, file, problems) {
  bytes <- tryCatch(suppressWarnings(readBin(path, "raw", n = file.size(path))),
                    error = function(e) NULL)
  if (is.null(bytes)) return(path)
  if (any(bytes == as.raw(0x00L))) {
    add_csv_read_problem(problems, file, "it contains null bytes, so it is not plain text")
    return(NULL)
  }
  text <- rawToChar(bytes)
  if (validUTF8(text)) return(path)

  control <- bytes < as.raw(0x20L) & !bytes %in% as.raw(c(0x09L, 0x0AL, 0x0DL))
  if (any(control)) {
    add_csv_read_problem(problems, file, "it contains control characters, so it is not plain text")
    return(NULL)
  }
  # Treats a file with mostly good UTF-8 accented lines as damaged UTF-8.
  lines <- split(bytes, cumsum(bytes == as.raw(0x0AL)))
  accented <- vapply(lines, function(line) any(line > as.raw(0x7FL)), TRUE)
  line_is_utf8 <- vapply(lines, function(line) validUTF8(rawToChar(line)), TRUE)
  if (sum(accented & line_is_utf8) > sum(!line_is_utf8)) {
    add_csv_read_problem(problems, file, "it is UTF-8 text with damaged characters")
    return(NULL)
  }
  converted <- iconv(text, "CP1252", "UTF-8")
  if (is.na(converted)) {
    add_csv_read_problem(problems, file, "it is neither UTF-8 nor Windows-1252 text")
    return(NULL)
  }
  copy <- tempfile("csv-utf8-", fileext = ".csv")
  writeBin(charToRaw(converted), copy)
  problems$note(file, ": isn't saved as UTF-8, so it was read as a Windows-1252 file; check its ",
                "accented names (in Excel, save as \"CSV UTF-8\").")
  copy
}

# Reads one file of DATA_FILES: CSV as text (IDs keep leading zeros, blank
# cells are NA), GeoJSON as sf in EPSG:4326. Checks the required columns
# and turns the `numbers` columns into numbers.
read_data_file <- function(data_dir, layer, problems, redacted_codes = character(0), require_coordinates = TRUE) {
  spec <- DATA_FILES[[layer]]
  if (!require_coordinates) {
    spec$required <- setdiff(spec$required, c("latitude", "longitude"))
    spec$optional <- unique(c(spec$optional, "latitude", "longitude"))
  }
  path <- file.path(data_dir, spec$file)
  if (grepl("\\.geojson$", spec$file)) {
    x <- tryCatch(sf::st_read(path, quiet = TRUE), error = function(e) {
      problems$add_blocking(spec$file, ": can't be read as GeoJSON (", conditionMessage(e),
        "). Export a valid UTF-8 GeoJSON feature collection with the documented boundary properties.")
      NULL
    })
    if (is.null(x)) return(NULL)
    x <- tryCatch({
      if (is.na(sf::st_crs(x))) sf::st_crs(x) <- 4326
      if (!isTRUE(sf::st_crs(x) == sf::st_crs(4326))) x <- sf::st_transform(x, 4326)
      sf::st_geometry(x) <- "geometry"
      x
    }, error = function(e) {
      problems$add_blocking(spec$file, ": geometry cannot be transformed to WGS84 (EPSG:4326) (",
        conditionMessage(e), "). Supply the correct boundary CRS and export valid Polygon or MultiPolygon geometry.")
      NULL
    })
    if (is.null(x)) return(NULL)
    attr(x, "source") <- spec$file
    validate_boundary_geometry(x, spec$file, problems)
  } else {
    csv_path <- csv_path_as_utf8(path, spec$file, problems)
    if (is.null(csv_path)) return(NULL)
    if (csv_path != path) on.exit(unlink(csv_path), add = TRUE)
    if (!validate_csv_structure(csv_path, spec$file, problems)) return(NULL)
    x <- tryCatch(
      withCallingHandlers(
        utils::read.csv(csv_path, colClasses = "character", na.strings = "", check.names = FALSE,
                       strip.white = TRUE, encoding = "UTF-8", fileEncoding = "UTF-8"),
        warning = function(w) {
          if (grepl("EOF within quoted string|embedded nul|invalid input", conditionMessage(w), ignore.case = TRUE)) {
            stop(conditionMessage(w), call. = FALSE)
          }
        }
      ),
      error = function(e) {
        add_csv_read_problem(problems, spec$file, conditionMessage(e))
        NULL
      }
    )
    if (is.null(x)) return(NULL)
    if (!validate_input_headers(x, spec$file, problems)) return(NULL)
    # Whitespace-only cells become blank.
    for (col in intersect(c(spec$required, spec$optional), names(x))) {
      x[[col]][!is.na(x[[col]]) & !nzchar(trimws(x[[col]]))] <- NA_character_
    }
    # Codes that mean "withheld" (settings suppression$redacted_codes, e.g.
    # "*") count as blank in the count and percentage columns
    if (length(redacted_codes) > 0) {
      value_cols <- intersect(names(x), c(spec$numbers, grep("_pct$", names(x), value = TRUE)))
      for (col in value_cols) x[[col]][trimws(x[[col]]) %in% redacted_codes] <- NA
    }
  }
  missing <- setdiff(spec$required, names(x))
  if (length(missing) > 0) {
    problems$add_blocking(spec$file, ": missing required column", if (length(missing) > 1) "s", " ",
                          paste(missing, collapse = ", "),
                          ". Add these exact, case-sensitive headers; leave unknown measurements blank rather than removing a column.")
  }
  for (col in c(spec$required, spec$optional)) {
    if (col %in% names(x) && !col %in% c("latitude", "longitude") && !col %in% spec$numbers) {
      x[[col]] <- as.character(x[[col]])
      x[[col]][!is.na(x[[col]]) & !nzchar(trimws(x[[col]]))] <- NA_character_
    }
  }
  # Left-out optional columns become blank columns
  for (col in setdiff(spec$optional, names(x))) {
    x[[col]] <- if (col %in% spec$numbers) rep(NA_real_, nrow(x)) else rep(NA_character_, nrow(x))
  }
  if ("reporting_status" %in% names(x)) {
    x$reporting_status <- trimws(x$reporting_status)
    x$reporting_status[x$reporting_status == ""] <- NA_character_
    bad <- !is.na(x$reporting_status) & !x$reporting_status %in% c("reported", "not_reported")
    if (any(bad)) problems$add(spec$file, ": reporting_status must be 'reported', 'not_reported', or blank; found ",
      input_value_details(x$reporting_status[bad]), input_row_details(which(bad)),
      ". Correct the status label; a measured zero does not mean not_reported.")
    x <- mask_not_reported(x)
  }
  for (col in intersect(spec$numbers, names(x))) {
    x[[col]] <- as_number(x[[col]], spec$file, col, problems)
  }
  coverage <- setdiff(grep("_pct$", c(spec$required, spec$optional), value = TRUE), spec$numbers)
  for (col in intersect(coverage, names(x))) x[[col]] <- trimws(x[[col]])
  if (layer == "grades" && "grade" %in% names(x)) x$grade <- trimws(x$grade)
  validate_input_values(x, layer, spec, problems)
  x
}

# Text to numbers; cells that aren't numbers are reported
as_number <- function(x, file, col, problems) {
  num <- suppressWarnings(as.numeric(x))
  bad_rows <- which(!is.na(x) & is.na(num))
  bad <- unique(x[bad_rows])
  if (length(bad) > 0) {
    problems$add(file, ": column ", col, " should hold numbers but has ",
                 input_value_details(utils::head(bad, 3)),
                 if (length(bad) > 3) paste0(" and ", length(bad) - 3, " more"),
                 input_row_details(bad_rows),
                 " (if a value marks withheld data, list it in the settings' suppression$redacted_codes). ",
                 "Use unformatted numbers such as 1250, or leave unknown measurements blank.")
  }
  num
}

# latitude/longitude columns to an sf of points (EPSG:4326). With
# allow_empty, rows with both coordinates blank get an empty point.
as_points <- function(x, file, problems, allow_empty) {
  lat <- as_number(x$latitude, file, "latitude", problems)
  lon <- as_number(x$longitude, file, "longitude", problems)
  blank <- is.na(lat) & is.na(lon)
  half <- xor(is.na(lat), is.na(lon))
  if (any(half)) problems$add(file, ": ", sum(half), " row(s) have only one of latitude and longitude",
    input_row_details(which(half)), ". Supply both WGS84 coordinates, or leave both blank when this layer permits missing locations.")
  if (!allow_empty && any(blank)) problems$add(file, ": ", sum(blank), " row(s) have no latitude/longitude",
    input_row_details(which(blank)), ". Supply both WGS84 latitude and longitude for this spatial feature.")
  out_of_range <- (!is.na(lat) & (!is.finite(lat) | abs(lat) > 90)) |
    (!is.na(lon) & (!is.finite(lon) | abs(lon) > 180))
  if (any(out_of_range)) {
    problems$add(file, ": ", sum(out_of_range), " row(s) have coordinates outside -90..90 / -180..180",
      " (latitude and longitude swapped?); found ",
      input_value_details(paste0("latitude=", x$latitude[out_of_range], ", longitude=", x$longitude[out_of_range])),
      input_row_details(which(out_of_range)),
      ". Use finite WGS84 decimal degrees: latitude -90 to 90 and longitude -180 to 180.")
  }
  unsafe <- !is.finite(lat) | !is.finite(lon) | abs(lat) > 90 | abs(lon) > 180
  geometry <- sf::st_sfc(
    lapply(seq_along(lat), function(i) {
      if (unsafe[i]) sf::st_point() else sf::st_point(c(lon[i], lat[i]))
    }),
    crs = 4326
  )
  x$latitude <- NULL
  x$longitude <- NULL
  sf::st_sf(x, geometry = geometry)
}

# ---- Boundaries ------------------------------------------------------------

# Census boundaries for the state in the settings (tigris, cached), as
# the sf a boundary file would give: counties with county_fips (5-digit
# GEOID) and county_name; school districts with district_id (7-digit
# GEOID) of the settings' district_type ("unified", "elementary" or
# "secondary").
download_boundaries <- function(layer, geography, problems) {
  file <- DATA_FILES[[layer]]$file
  state <- geography$state
  if (is.null(state) || !nzchar(state)) {
    problems$add_blocking(file, " isn't in the data folder, and the settings don't name a state ",
                          "(geography$state) to download the Census boundaries for")
    return(NULL)
  }
  old <- options(tigris_use_cache = TRUE)
  on.exit(options(old))
  district_type <- if (is.null(geography$district_type)) "unified" else geography$district_type
  what <- if (layer == "county_boundaries") "county" else paste(district_type, "school district")
  x <- tryCatch(
    suppressMessages(
      if (layer == "county_boundaries") {
        tigris::counties(state, cb = TRUE, year = geography$year, progress_bar = FALSE)
      } else {
        tigris::school_districts(state, type = district_type, cb = TRUE, year = geography$year,
                                 progress_bar = FALSE)
      }
    ),
    error = function(e) {
      problems$add_blocking("Couldn't download the Census ", what, " boundaries for ", state, " (",
                            conditionMessage(e), "). Check the internet connection and ",
                            "geography$state, or put ", file, " in the data folder.")
      NULL
    }
  )
  if (is.null(x)) return(NULL)
  x <- sf::st_transform(x, 4326)
  out <- if (layer == "county_boundaries") {
    data.frame(county_fips = x$GEOID, county_name = census_county_names(x$NAME, x$NAMELSAD),
               stringsAsFactors = FALSE)
  } else {
    data.frame(district_id = x$GEOID, stringsAsFactors = FALSE)
  }
  out <- sf::st_sf(out, geometry = sf::st_geometry(x))
  attr(out, "source") <- paste0("the Census ", what, " boundaries for ", state)
  out
}

# Input:  the Census NAME and NAMELSAD columns ("Baltimore", "Baltimore city")
# Output: NAME, except for a city that shares its NAME with a county
#         (Baltimore MD, St. Louis MO, four in Virginia), which keeps its
#         NAMELSAD; county names have to be unique within a state.
#         Used by download_boundaries().
census_county_names <- function(name, full_name) {
  if (is.null(full_name)) return(name)
  shared <- name %in% name[duplicated(name)] & !grepl(" County$", full_name)
  name[shared] <- full_name[shared]
  name
}

# Where a boundary layer came from, for messages
boundary_source <- function(boundaries) {
  src <- attr(boundaries, "source")
  if (is.null(src)) "the boundaries" else src
}

# Picks one display name per county_fips across the data files. Order of
# preference: counties, schools, facilities, cases; within a file, the first
# nonblank name. Every name given can still match name-only rows, if it
# points to one county_fips.
reconcile_county_aliases <- function(layers, problems) {
  metadata <- do.call(rbind, lapply(names(layers), function(layer) {
    x <- layers[[layer]]
    data.frame(county_fips = x$county_fips, county_name = x$county_name,
      layer = rep(layer, nrow(x)), row = seq_len(nrow(x)), stringsAsFactors = FALSE)
  }))
  has_fips <- !is.na(metadata$county_fips) & nzchar(metadata$county_fips)
  has_name <- !is.na(metadata$county_name) & nzchar(metadata$county_name)
  metadata$county_fips[!has_fips] <- NA_character_
  metadata$county_name[!has_name] <- NA_character_
  ids <- unique(metadata$county_fips[has_fips])
  labels <- vapply(ids, function(id) {
    rows <- which(has_fips & has_name & metadata$county_fips == id)
    if (length(rows)) metadata$county_name[rows[1]] else id
  }, character(1))
  aliases <- unique(metadata[has_fips & has_name, c("county_fips", "county_name"), drop = FALSE])
  for (i in which(!has_fips & has_name)) {
    matches <- unique(aliases$county_fips[tolower(aliases$county_name) == tolower(metadata$county_name[i])])
    if (length(matches) > 1L) {
      problems$add_blocking(DATA_FILES[[metadata$layer[i]]]$file, ": row ", metadata$row[i] + 1L,
        " county_name '", metadata$county_name[i], "' matches multiple supplied county_fips: ",
        paste(matches, collapse = ", "),
        " (row 1 is the header). Supply county_fips for this row or reconcile the county names.")
    } else if (length(matches)) {
      metadata$county_fips[i] <- matches
    }
  }
  has_fips <- !is.na(metadata$county_fips)
  metadata$county_name[has_fips] <- labels[match(metadata$county_fips[has_fips], ids)]
  # Rows with a county_name but no county_fips are matched by name, ignoring case.
  name_only <- which(!has_fips & has_name)
  name_keys <- tolower(metadata$county_name[name_only])
  metadata$county_name[name_only] <- metadata$county_name[name_only][match(name_keys, name_keys)]
  named <- !is.na(metadata$county_name)
  keys <- ifelse(has_fips, paste0("fips:", metadata$county_fips),
    paste0("name:", tolower(metadata$county_name)))
  for (name in unique(tolower(metadata$county_name[named]))) {
    rows <- which(named & tolower(metadata$county_name) == name)
    if (length(unique(keys[rows])) > 1L) {
      locations <- vapply(unique(metadata$layer[rows]), function(layer) {
        source_rows <- rows[metadata$layer[rows] == layer]
        paste0(DATA_FILES[[layer]]$file, input_row_details(metadata$row[source_rows]))
      }, character(1))
      problems$add_blocking("County display name '", metadata$county_name[rows[1]],
        "' identifies different supplied counties; affected county_name/county_fips in ",
        paste(locations, collapse = "; "), ". Use distinct county names or supply county boundaries; ",
        "for name-only rows, supply their county_fips.")
    }
  }
  for (layer in names(layers)) {
    rows <- metadata$layer == layer
    layers[[layer]]$county_fips <- metadata$county_fips[rows]
    layers[[layer]]$county_name <- metadata$county_name[rows]
  }
  layers
}

# Row of the county boundaries for each row of a file: by county_fips
# (exact text) where given, otherwise by county_name (ignoring case).
# Rows with neither are NA. Values that match no county are reported.
county_rows <- function(fips, name, bounds, file, problems) {
  src <- boundary_source(bounds)
  rows <- rep(NA_integer_, length(name))
  by_fips <- !is.na(fips)
  if (any(by_fips)) {
    if (all(is.na(bounds$county_fips))) {
      problems$add(file, ": has county_fips, but ", src, " have no county_fips to match it with; found ",
        input_value_details(fips[by_fips]), input_row_details(which(by_fips)),
        ". Add matching county_fips properties to the boundaries, or supply county_name instead of FIPS for these rows.")
    } else {
      rows[by_fips] <- match(fips[by_fips], bounds$county_fips)
      bad <- unique(fips[by_fips & is.na(rows)])
      if (length(bad) > 0) {
        hint <- if (any(nchar(bad) < 5)) " (5 digits: keep leading zeros)" else ""
        problems$add(file, ": ", length(bad), " county_fips value(s) not in ", src, ": ",
          paste(utils::head(bad, 5), collapse = ", "), hint,
          input_row_details(which(by_fips & is.na(rows))),
          ". Use the exact boundary county_fips, including leading zeros; an invalid supplied FIPS does not fall back to the county name.")
      }
    }
  }
  by_name <- !by_fips & !is.na(name)
  if (any(by_name)) {
    rows[by_name] <- match(tolower(name[by_name]), tolower(bounds$county_name))
    bad <- unique(name[by_name & is.na(rows)])
    if (length(bad) > 0) {
      hint <- if (any(tolower(sub(" [Cc]ounty$", "", bad)) %in% tolower(bounds$county_name))) {
        " (leave out \"County\")"
      } else ""
      problems$add(file, ": ", length(bad), " county name(s) not in ", src, ": ",
        paste(utils::head(bad, 5), collapse = ", "), hint,
        input_row_details(which(by_name & is.na(rows))),
        ". Correct county_name to a boundary name, or supply its exact county_fips.")
    }
  }
  rows
}

# counties.csv joined to the county boundaries; every county has a row in
# the result (counties without coverage get NA)
join_counties <- function(bounds, data, problems) {
  rows <- county_rows(data$county_fips, data$county_name, bounds, "counties.csv", problems)
  missing_county <- is.na(data$county_fips) & is.na(data$county_name)
  if (any(missing_county)) {
    problems$add("counties.csv: ", sum(missing_county), " row(s) have neither county_fips nor county_name",
      input_row_details(which(missing_county)), ". Supply at least one county identifier for each coverage observation.")
  }
  dup <- unique(rows[!is.na(rows) & duplicated(rows)])
  if (length(dup) > 0) {
    problems$add("counties.csv: ", length(dup), " county(ies) appear more than once: ",
      paste(utils::head(bounds$county_name[dup], 5), collapse = ", "),
      input_row_details(which(rows %in% dup)),
      ". Keep one county_name/county_fips observation per county for the chosen reporting period and population.")
  }
  data$county_fips <- NULL
  data$county_name <- NULL
  joined <- data[match(seq_len(nrow(bounds)), rows), , drop = FALSE]
  rownames(joined) <- NULL
  out <- cbind(data.frame(county_name = as.character(bounds$county_name),
                          county_fips = as.character(bounds$county_fips),
                          stringsAsFactors = FALSE),
               joined)
  sf::st_sf(out, geometry = sf::st_geometry(bounds))
}

# districts.csv joined to the district boundaries by district_id (exact
# text); districts without coverage get NA
join_districts <- function(bounds, data, problems) {
  src <- boundary_source(bounds)
  b_id <- as.character(bounds$district_id)
  check_unique(b_id, src, "district_id", problems)
  check_unique(data$district_id, "districts.csv", "district_id", problems)
  unmatched <- setdiff(data$district_id[!is.na(data$district_id)], b_id)
  if (length(unmatched) > 0) {
    problems$add("districts.csv: ", length(unmatched), " district_id(s) not in ", src, ": ",
      paste(utils::head(unmatched, 5), collapse = ", "),
      input_row_details(which(data$district_id %in% unmatched)),
      ". Use exact boundary district_id values, preserving leading zeros, and check the district type and boundary vintage.")
  }
  rows <- match(b_id, data$district_id)
  data$district_id <- NULL
  joined <- data[rows, , drop = FALSE]
  rownames(joined) <- NULL
  out <- cbind(data.frame(district_id = b_id, stringsAsFactors = FALSE), joined)
  sf::st_sf(out, geometry = sf::st_geometry(bounds))
}

# county_name (spelled as in the boundaries) and county_fips for each row
# of a file, from its county_fips/county_name columns; for points with
# neither, from the county the point lies in. Rows of a non-point file
# with neither are reported.
add_counties <- function(x, bounds, file, problems) {
  rows <- county_rows(x$county_fips, x$county_name, bounds, file, problems)
  neither <- is.na(x$county_fips) & is.na(x$county_name)
  if (inherits(x, "sf")) {
    find <- neither & !sf::st_is_empty(x)
    if (any(find)) {
      inside <- sf::st_within(x[find, ], bounds)
      rows[find] <- vapply(inside, function(i) if (length(i)) i[1] else NA_integer_, 1L)
    }
  } else if (any(neither)) {
    problems$add(file, ": ", sum(neither), " row(s) have neither county_fips nor county_name",
      input_row_details(which(neither)), ". Supply at least one county identifier for each observation.")
  }
  x$county_name <- as.character(bounds$county_name)[rows]
  x$county_fips <- as.character(bounds$county_fips)[rows]
  x
}

# ---- Values --------------------------------------------------------------

# Coverage text to a number: "92.4" and "92.4%" -> 92.4; suppressed
# ">95" -> 95 + offset, "<5" -> 5 - offset; anything else -> NA
pct_number <- function(x, offset = 1) {
  x <- as.character(x)
  num <- suppressWarnings(as.numeric(sub("%$", "", trimws(sub("^[<>]", "", x)))))
  ifelse(grepl("^\\s*>", x), num + offset, ifelse(grepl("^\\s*<", x), num - offset, num))
}

check_unique <- function(x, file, col, problems, ignore_case = FALSE) {
  keys <- if (ignore_case) tolower(x) else x
  dup <- unique(keys[!is.na(keys) & duplicated(keys)])
  if (length(dup) > 0) {
    rows <- which(!is.na(keys) & keys %in% dup)
    problems$add(file, ": ", length(dup), " ", col, " value(s) appear more than once: ",
      paste(utils::head(unique(x[rows]), 5), collapse = ", "),
      input_row_details(rows, boundaries = !grepl("\\.csv$", file)),
      ". Keep one record per unique ", col, if (ignore_case) " (county names match ignoring case)", ".")
  }
}

# ---- Problem list ----------------------------------------------------------

# Problems found while loading; add_blocking() for ones that stop the
# remaining checks from running; note() for values worth checking that
# don't stop loading
new_problem_list <- function() {
  items <- character(0)
  notes <- character(0)
  blocking <- FALSE
  list(
    add = function(...) items <<- c(items, paste0(...)),
    note = function(...) notes <<- c(notes, paste0(...)),
    add_blocking = function(...) {
      items <<- c(items, paste0(...))
      blocking <<- TRUE
    },
    blocking = function() blocking,
    get = function() items,
    notes = function() notes
  )
}

report_problems <- function(problems, data_dir) {
  items <- problems$get()
  if (length(items) > 0) {
    stop("The data in \"", data_dir, "\" can't be loaded:\n",
         paste0("  - ", items, collapse = "\n"), call. = FALSE)
  }
}

# Prints a warning right away with the notes from new_problem_list().
report_notes <- function(problems, data_dir) {
  items <- problems$notes()
  if (length(items) > 0) {
    warning("The dashboard will start, but check the data in \"", data_dir, "\":\n",
            paste0("  - ", items, collapse = "\n"), call. = FALSE, immediate. = TRUE)
  }
}
