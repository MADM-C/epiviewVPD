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
# Values are read as given. The loader only builds geometry, finds each
# row's county in the boundaries (by county_fips, else county_name, else
# the coordinates), and adds full_vax_pct_num (the coverage as a number,
# for colors and sorting). It checks the files and
# stops with one message listing every problem it found. Only a file that
# can't be read or lacks a required column stops it before the other
# checks have run.
# ============================================================

# Files in the data folder, and the columns each must have. Optional
# columns may be left out: the loader adds them with blank values, so the
# dashboard treats a left-out column like one with every cell blank.
# county = TRUE: each row needs a county, by county_fips or county_name
# (for points, the coordinates do if both are blank).
# boundaries = TRUE: optional file; downloaded from the Census if missing.
DATA_FILES <- list(
  counties = list(
    file = "counties.csv",
    required = c("enroll", "full_vax_pct"),
    optional = c("county_fips", "county_name", "full_vax", "students_of_color_pct", "frl_eligible_pct"),
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
                 "contact_info", "home_languages"),
    numbers = c("enroll", "full_vax", "partial_vax"),
    county = TRUE
  ),
  facilities = list(
    file = "facilities.csv",
    required = c("facility_id", "facility_name", "latitude", "longitude", "enroll", "full_vax_pct"),
    optional = c("full_vax", "enroll_eligible", "county_fips", "county_name"),
    numbers = c("enroll", "full_vax", "enroll_eligible"),
    county = TRUE
  ),
  grades = list(
    file = "grades.csv",
    required = c("school_id", "grade", "enroll", "full_vax_pct"),
    optional = c("full_vax", "partial_vax_pct", "medical_pct", "nonmedical_pct"),
    numbers = c("enroll", "full_vax")
  ),
  districts = list(
    file = "districts.csv",
    required = c("district_id", "district_name", "enroll", "full_vax_pct"),
    optional = "full_vax",
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
#         boundaries), district_type, year
# Output: named list of app data objects (see top of file)
load_app_data <- function(data_dir, suppressed_offset = 1, redacted_codes = character(0),
                          geography = list(state = NULL, district_type = "unified", year = NULL)) {
  if (!dir.exists(data_dir)) {
    stop("The data folder \"", data_dir, "\" doesn't exist.", call. = FALSE)
  }
  files <- vapply(DATA_FILES, `[[`, "", "file")
  needed <- !vapply(DATA_FILES, function(spec) isTRUE(spec$boundaries), TRUE)
  missing <- files[needed & !file.exists(file.path(data_dir, files))]
  if (length(missing) > 0) {
    stop("The data folder \"", data_dir, "\" is missing: ",
         paste(missing, collapse = ", "), call. = FALSE)
  }

  problems <- new_problem_list()
  raw <- lapply(names(DATA_FILES), function(layer) {
    spec <- DATA_FILES[[layer]]
    if (isTRUE(spec$boundaries) && !file.exists(file.path(data_dir, spec$file))) {
      download_boundaries(layer, geography, problems)
    } else {
      read_data_file(data_dir, layer, problems, redacted_codes)
    }
  })
  names(raw) <- names(DATA_FILES)
  for (layer in names(DATA_FILES)) {
    if (isTRUE(DATA_FILES[[layer]]$county) && !is.null(raw[[layer]]) &&
        all(is.na(raw[[layer]]$county_fips)) && all(is.na(raw[[layer]]$county_name)) &&
        !layer %in% c("schools", "facilities")) {
      problems$add_blocking(DATA_FILES[[layer]]$file, ": needs a county_fips or county_name column")
    }
  }
  # Unreadable files, missing columns or boundaries: the checks below can't run
  if (problems$blocking()) report_problems(problems, data_dir)
  county_bounds <- raw$county_boundaries
  check_unique(county_bounds$county_name, boundary_source(county_bounds), "county_name", problems)
  if (!all(is.na(county_bounds$county_fips))) {
    check_unique(county_bounds$county_fips, boundary_source(county_bounds), "county_fips", problems)
  }

  # --- counties: boundaries with coverage joined by county ---
  counties <- join_counties(county_bounds, raw$counties, problems)

  # --- points ---
  schools <- as_points(raw$schools, "schools.csv", problems, allow_empty = FALSE)
  facilities <- as_points(raw$facilities, "facilities.csv", problems, allow_empty = TRUE)
  healthcare_centers <- as_points(raw$healthcare_centers, "healthcare_centers.csv", problems, allow_empty = FALSE)

  schools <- add_counties(schools, county_bounds, "schools.csv", problems)
  facilities <- add_counties(facilities, county_bounds, "facilities.csv", problems)

  # --- districts: boundaries with coverage joined by district_id ---
  districts <- join_districts(raw$district_boundaries, raw$districts, problems)

  # --- cases ---
  cases <- add_counties(raw$cases, county_bounds, "cases.csv", problems)
  cases$year <- as.integer(cases$year)
  cases$n_cases <- as.integer(cases$n_cases)

  # --- grades ---
  grades <- raw$grades

  # --- IDs ---
  check_unique(schools$school_id, "schools.csv", "school_id", problems)
  check_unique(facilities$facility_id, "facilities.csv", "facility_id", problems)

  # --- coverage as a number, for colors and sorting ---
  for (x in c("counties", "schools", "facilities", "districts")) {
    obj <- get(x)
    obj$full_vax_pct_num <- pct_number(obj$full_vax_pct, suppressed_offset)
    assign(x, obj)
  }

  report_problems(problems, data_dir)

  list(
    counties = counties,
    schools = schools,
    facilities = facilities,
    grades = grades,
    districts = districts,
    cases = cases,
    healthcare_centers = healthcare_centers
  )
}

# ---- Reading ---------------------------------------------------------------

# Reads one file of DATA_FILES: CSV as text (IDs keep leading zeros, blank
# cells are NA), GeoJSON as sf in EPSG:4326. Checks the required columns
# and turns the `numbers` columns into numbers.
read_data_file <- function(data_dir, layer, problems, redacted_codes = character(0)) {
  spec <- DATA_FILES[[layer]]
  path <- file.path(data_dir, spec$file)
  if (grepl("\\.geojson$", spec$file)) {
    x <- tryCatch(sf::st_read(path, quiet = TRUE), error = function(e) {
      problems$add_blocking(spec$file, ": can't be read as GeoJSON (", conditionMessage(e), ")")
      NULL
    })
    if (is.null(x)) return(NULL)
    if (is.na(sf::st_crs(x))) sf::st_crs(x) <- 4326
    if (!isTRUE(sf::st_crs(x) == sf::st_crs(4326))) x <- sf::st_transform(x, 4326)
    sf::st_geometry(x) <- "geometry"
    attr(x, "source") <- spec$file
  } else {
    x <- tryCatch(
      utils::read.csv(path, colClasses = "character", na.strings = "", check.names = FALSE,
                      strip.white = TRUE, encoding = "UTF-8", fileEncoding = "UTF-8"),
      error = function(e) {
        problems$add_blocking(spec$file, ": can't be read as CSV (", conditionMessage(e), ")")
        NULL
      }
    )
    if (is.null(x)) return(NULL)
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
                          paste(missing, collapse = ", "))
  }
  for (col in c(spec$required, spec$optional)) {
    if (col %in% names(x) && !col %in% c("latitude", "longitude") && !col %in% spec$numbers) {
      x[[col]] <- as.character(x[[col]])
    }
  }
  for (col in intersect(spec$numbers, names(x))) {
    x[[col]] <- as_number(x[[col]], spec$file, col, problems)
  }
  # Left-out optional columns become blank columns
  for (col in setdiff(spec$optional, names(x))) {
    x[[col]] <- if (col %in% spec$numbers) rep(NA_real_, nrow(x)) else rep(NA_character_, nrow(x))
  }
  x
}

# Text to numbers; cells that aren't numbers are reported
as_number <- function(x, file, col, problems) {
  num <- suppressWarnings(as.numeric(x))
  bad <- unique(x[!is.na(x) & is.na(num)])
  if (length(bad) > 0) {
    problems$add(file, ": column ", col, " should hold numbers but has ",
                 paste0("\"", utils::head(bad, 3), "\"", collapse = ", "),
                 if (length(bad) > 3) paste0(" and ", length(bad) - 3, " more"),
                 " (if a value marks withheld data, list it in the settings' suppression$redacted_codes)")
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
  if (any(half)) problems$add(file, ": ", sum(half), " row(s) have only one of latitude and longitude")
  if (!allow_empty && any(blank)) problems$add(file, ": ", sum(blank), " row(s) have no latitude/longitude")
  out_of_range <- !is.na(lat) & !is.na(lon) & (abs(lat) > 90 | abs(lon) > 180)
  if (any(out_of_range)) {
    problems$add(file, ": ", sum(out_of_range), " row(s) have coordinates outside -90..90 / -180..180",
                 " (latitude and longitude swapped?)")
  }
  geometry <- sf::st_sfc(
    lapply(seq_along(lat), function(i) {
      if (is.na(lat[i]) || is.na(lon[i])) sf::st_point() else sf::st_point(c(lon[i], lat[i]))
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
    data.frame(county_fips = x$GEOID, county_name = x$NAME, stringsAsFactors = FALSE)
  } else {
    data.frame(district_id = x$GEOID, stringsAsFactors = FALSE)
  }
  out <- sf::st_sf(out, geometry = sf::st_geometry(x))
  attr(out, "source") <- paste0("the Census ", what, " boundaries for ", state)
  out
}

# Where a boundary layer came from, for messages
boundary_source <- function(boundaries) {
  src <- attr(boundaries, "source")
  if (is.null(src)) "the boundaries" else src
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
      problems$add(file, ": has county_fips, but ", src, " have no county_fips to match it with")
    } else {
      rows[by_fips] <- match(fips[by_fips], bounds$county_fips)
      bad <- unique(fips[by_fips & is.na(rows)])
      if (length(bad) > 0) {
        hint <- if (any(nchar(bad) < 5)) " (5 digits: keep leading zeros)" else ""
        problems$add(file, ": ", length(bad), " county_fips value(s) not in ", src, ": ",
                     paste(utils::head(bad, 5), collapse = ", "), hint)
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
                   paste(utils::head(bad, 5), collapse = ", "), hint)
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
    problems$add("counties.csv: ", sum(missing_county), " row(s) have neither county_fips nor county_name")
  }
  dup <- unique(rows[!is.na(rows) & duplicated(rows)])
  if (length(dup) > 0) {
    problems$add("counties.csv: ", length(dup), " county(ies) appear more than once: ",
                 paste(utils::head(bounds$county_name[dup], 5), collapse = ", "))
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
                 paste(utils::head(unmatched, 5), collapse = ", "))
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
    problems$add(file, ": ", sum(neither), " row(s) have neither county_fips nor county_name")
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

check_unique <- function(x, file, col, problems) {
  dup <- unique(x[!is.na(x) & duplicated(x)])
  if (length(dup) > 0) {
    problems$add(file, ": ", length(dup), " ", col, " value(s) appear more than once: ",
                 paste(utils::head(dup, 5), collapse = ", "))
  }
}

# ---- Problem list ----------------------------------------------------------

# Problems found while loading; add_blocking() for ones that stop the
# remaining checks from running
new_problem_list <- function() {
  items <- character(0)
  blocking <- FALSE
  list(
    add = function(...) items <<- c(items, paste0(...)),
    add_blocking = function(...) {
      items <<- c(items, paste0(...))
      blocking <<- TRUE
    },
    blocking = function() blocking,
    get = function() items
  )
}

report_problems <- function(problems, data_dir) {
  items <- problems$get()
  if (length(items) > 0) {
    stop("The data in \"", data_dir, "\" can't be loaded:\n",
         paste0("  - ", items, collapse = "\n"), call. = FALSE)
  }
}
