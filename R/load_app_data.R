# ============================================================
# LOAD THE DASHBOARD'S DATA
# ============================================================
# load_app_data() reads the data folder (CSV files plus GeoJSON
# boundaries, see DATA_FILES below) and returns the app data, one object
# per layer, with the same column names for the same thing in every
# layer:
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
# Values are read as given. The loader only builds geometry, matches
# county names to the county boundaries, and adds full_vax_pct_num (the
# coverage as a number, for colors and sorting). It checks the files and
# stops with one message listing every problem it found. Only a file that
# can't be read or lacks a required column stops it before the other
# checks have run.
# ============================================================

# Files in the data folder, and the columns each must have. Optional
# columns may be left out: the loader adds them with blank values, so the
# dashboard treats a left-out column like one with every cell blank.
# (county_name in schools.csv/facilities.csv is worked out from the
# coordinates instead.)
DATA_FILES <- list(
  counties = list(
    file = "counties.csv",
    required = c("county_name", "enroll", "full_vax_pct"),
    optional = c("full_vax", "students_of_color_pct", "frl_eligible_pct"),
    numbers = c("enroll", "full_vax", "students_of_color_pct", "frl_eligible_pct")
  ),
  county_boundaries = list(
    file = "county_boundaries.geojson",
    required = "county_name"
  ),
  schools = list(
    file = "schools.csv",
    required = c("school_id", "school_name", "latitude", "longitude", "enroll", "full_vax_pct"),
    optional = c("full_vax", "partial_vax", "partial_vax_pct", "medical_pct", "nonmedical_pct",
                 "school_type", "grade_range", "address", "county_name", "district_id",
                 "contact_info", "home_languages"),
    numbers = c("enroll", "full_vax", "partial_vax")
  ),
  facilities = list(
    file = "facilities.csv",
    required = c("facility_id", "facility_name", "latitude", "longitude", "enroll", "full_vax_pct"),
    optional = c("full_vax", "enroll_eligible", "county_name"),
    numbers = c("enroll", "full_vax", "enroll_eligible")
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
    required = "district_id"
  ),
  cases = list(
    file = "cases.csv",
    required = c("county_name", "year", "n_cases"),
    optional = "age_group",
    numbers = c("year", "n_cases")
  ),
  healthcare_centers = list(
    file = "healthcare_centers.csv",
    required = c("name", "latitude", "longitude")
  )
)

# Input:  data_dir = folder with the files in DATA_FILES;
#         suppressed_offset = how far past its number a suppressed
#         percentage (">95", "<5") is counted in full_vax_pct_num
# Output: named list of app data objects (see top of file)
load_app_data <- function(data_dir, suppressed_offset = 1) {
  if (!dir.exists(data_dir)) {
    stop("The data folder \"", data_dir, "\" doesn't exist.", call. = FALSE)
  }
  files <- vapply(DATA_FILES, `[[`, "", "file")
  missing <- files[!file.exists(file.path(data_dir, files))]
  if (length(missing) > 0) {
    stop("The data folder \"", data_dir, "\" is missing: ",
         paste(missing, collapse = ", "), call. = FALSE)
  }

  problems <- new_problem_list()
  raw <- lapply(names(DATA_FILES), function(layer) read_data_file(data_dir, layer, problems))
  names(raw) <- names(DATA_FILES)
  # Unreadable files or missing columns: the checks below can't run
  if (problems$blocking()) report_problems(problems, data_dir)

  # --- counties: boundaries with coverage joined by county_name ---
  counties <- join_to_boundaries(raw$county_boundaries, raw$counties, "county_name", problems)
  county_names <- counties$county_name

  # --- points ---
  schools <- as_points(raw$schools, "schools.csv", problems, allow_empty = FALSE)
  facilities <- as_points(raw$facilities, "facilities.csv", problems, allow_empty = TRUE)
  healthcare_centers <- as_points(raw$healthcare_centers, "healthcare_centers.csv", problems, allow_empty = FALSE)

  schools <- add_county_names(schools, counties, "schools.csv", problems)
  facilities <- add_county_names(facilities, counties, "facilities.csv", problems)

  # --- districts: boundaries with coverage joined by district_id ---
  districts <- join_to_boundaries(raw$district_boundaries, raw$districts, "district_id", problems)

  # --- cases ---
  cases <- raw$cases
  cases$county_name <- match_county_names(cases$county_name, county_names, "cases.csv", problems)
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
read_data_file <- function(data_dir, layer, problems) {
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
  }
  missing <- setdiff(spec$required, names(x))
  if (length(missing) > 0) {
    problems$add_blocking(spec$file, ": missing required column", if (length(missing) > 1) "s", " ",
                          paste(missing, collapse = ", "))
  }
  for (col in spec$required) {
    if (col %in% names(x) && !col %in% c("latitude", "longitude") && !col %in% spec$numbers) {
      x[[col]] <- as.character(x[[col]])
    }
  }
  for (col in intersect(spec$numbers, names(x))) {
    x[[col]] <- as_number(x[[col]], spec$file, col, problems)
  }
  # Left-out optional columns become blank columns
  for (col in setdiff(spec$optional, c(names(x), "county_name"))) {
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
                 if (length(bad) > 3) paste0(" and ", length(bad) - 3, " more"))
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

# Boundaries (sf with a `key` column) with the data rows joined on `key`.
# Keys are matched exactly for districts; county names ignoring case,
# keeping the boundaries' spelling. Every data row needs a boundary;
# boundaries without data get NA coverage.
join_to_boundaries <- function(boundaries, data, key, problems) {
  bfile <- if (key == "county_name") "county_boundaries.geojson" else "district_boundaries.geojson"
  dfile <- if (key == "county_name") "counties.csv" else "districts.csv"
  b_key <- as.character(boundaries[[key]])
  d_key <- data[[key]]
  check_unique(b_key, bfile, key, problems)
  check_unique(d_key, dfile, key, problems)
  if (key == "county_name") {
    d_key <- match_county_names(d_key, b_key, dfile, problems)
  } else {
    unmatched <- setdiff(d_key[!is.na(d_key)], b_key)
    if (length(unmatched) > 0) {
      problems$add(dfile, ": ", length(unmatched), " ", key, "(s) not in ", bfile, ": ",
                   paste(utils::head(unmatched, 5), collapse = ", "))
    }
  }
  data[[key]] <- NULL
  rows <- match(b_key, d_key)
  joined <- data[rows, , drop = FALSE]
  rownames(joined) <- NULL
  out <- cbind(stats::setNames(data.frame(b_key, stringsAsFactors = FALSE), key), joined)
  sf::st_sf(out, geometry = sf::st_geometry(boundaries))
}

# ---- Counties ------------------------------------------------------------

# County names spelled as in the county boundaries (matched ignoring
# case). Names that aren't counties are reported.
match_county_names <- function(x, county_names, file, problems) {
  lookup <- stats::setNames(county_names, tolower(county_names))
  unmatched <- setdiff(unique(tolower(x[!is.na(x)])), names(lookup))
  if (length(unmatched) > 0) {
    shown <- unique(x[tolower(x) %in% unmatched])
    hint <- if (any(sub(" county$", "", unmatched) %in% names(lookup))) " (leave out \"County\")" else ""
    problems$add(file, ": ", length(unmatched), " county name(s) not in county_boundaries.geojson: ",
                 paste(utils::head(shown, 5), collapse = ", "), hint)
  }
  unname(lookup[tolower(x)])
}

# county_name for points: from the column when the file has one, otherwise
# from the county each point lies in
add_county_names <- function(points, counties, file, problems) {
  if ("county_name" %in% names(points)) {
    points$county_name <- match_county_names(points$county_name, counties$county_name, file, problems)
  } else {
    inside <- sf::st_within(points, counties)
    points$county_name <- vapply(inside, function(i) if (length(i)) counties$county_name[i[1]] else NA_character_, "")
  }
  points
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
