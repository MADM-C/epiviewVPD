# Checks on each data file's values, run before the files are joined.
input_row_details <- function(rows, boundaries = FALSE) {
  if (!length(rows)) return("")
  shown <- utils::head(rows, 5L)
  paste0(" (", if (boundaries) "features " else "rows ",
         paste(shown + if (boundaries) 0L else 1L, collapse = ", "),
         if (length(rows) > 5L) ", ...",
         if (!boundaries) "; row 1 is the header", ")")
}

input_value_details <- function(values) {
  values <- as.character(values)
  values[is.na(values) | !nzchar(trimws(values))] <- "<blank>"
  values <- unique(values)
  paste0(paste(encodeString(utils::head(values, 5L), quote = '"'), collapse = ", "),
         if (length(values) > 5L) ", ...")
}

input_problem <- function(problems, file, column, rows, values, rule, guidance,
                          boundaries = FALSE, blocking = FALSE) {
  if (!length(rows)) return(invisible())
  add <- if (blocking) problems$add_blocking else problems$add
  add(file, ": ", column, " ", rule, "; found ", input_value_details(values[rows]),
      input_row_details(rows, boundaries), ". ", guidance)
}

validate_csv_structure <- function(path, file, problems) {
  fields <- tryCatch(utils::count.fields(path, sep = ",", quote = '"',
                                        comment.char = "", blank.lines.skip = TRUE),
                     error = function(e) NULL)
  if (is.null(fields)) return(TRUE) # The CSV reader reports this error.
  # count.fields gives NA for the earlier lines of a multiline quoted field.
  fields <- fields[!is.na(fields)]
  if (!length(fields)) return(TRUE)
  bad <- which(fields != fields[1L])
  if (!length(bad)) return(TRUE)
  problems$add_blocking(file, ": CSV fields do not match the header's ", fields[1L],
    " column(s); found ", input_value_details(fields[bad]), " fields",
    input_row_details(bad - 1L),
    ". Use one comma-separated field per header, quote text containing commas, close every quoted field, and write counts as 1250 rather than 1,250.")
  FALSE
}

validate_input_headers <- function(x, file, problems) {
  columns <- names(x)
  empty <- which(is.na(columns) | !nzchar(trimws(columns)))
  repeated <- unique(columns[duplicated(columns)])
  if (length(empty)) problems$add_blocking(file,
    ": column names cannot be blank (header columns ", paste(empty, collapse = ", "),
    "). Supply the documented, case-sensitive column names in the first row.")
  if (length(repeated)) problems$add_blocking(file, ": column names must be unique; repeated ",
    input_value_details(repeated), ". Keep one column for each documented field and rename or remove duplicate headers.")
  !length(empty) && !length(repeated)
}

# Allowed text format for coverage values, in loaded data and grade plots.
# A fraction may be written .5 or 0.5; "." and "5." are not allowed.
valid_coverage_format <- function(x) {
  grepl("^[<>]?\\s*([0-9]+(\\.[0-9]+)?|\\.[0-9]+)%?$", x)
}

validate_input_values <- function(x, layer, spec, problems) {
  file <- spec$file
  boundaries <- isTRUE(spec$boundaries)
  keys <- switch(layer,
    schools = c("school_id", "school_name"), facilities = c("facility_id", "facility_name"),
    grades = c("school_id", "grade"), districts = c("district_id", "district_name"),
    healthcare_centers = "name", county_boundaries = "county_name",
    district_boundaries = "district_id", character())
  for (column in intersect(keys, names(x))) {
    bad <- which(is.na(x[[column]]) | !nzchar(trimws(x[[column]])))
    input_problem(problems, file, column, bad, x[[column]], "cannot be blank",
      "Supply a nonblank value for this required identifier or display name.", boundaries)
  }
  for (column in intersect(spec$numbers, names(x))) {
    values <- x[[column]]
    percentage <- grepl("_pct$", column)
    bad <- !is.na(values) & (!is.finite(values) | values < 0 |
      if (percentage) values > 100 else values != floor(values))
    if (layer == "cases") bad <- bad | (!is.na(values) & values > .Machine$integer.max)
    rule <- if (percentage) "must contain finite percentages from 0 to 100 or blank unknown values" else
      "must contain nonnegative whole numbers or blank unknown values"
    guidance <- if (percentage) "Use numeric percentages from 0 to 100 without a % suffix; leave unknown values blank." else
      "Use finite, nonnegative whole counts without thousands separators; leave unknown values blank."
    if (layer == "cases") guidance <- paste0(guidance, " Values cannot exceed 2147483647.")
    input_problem(problems, file, column, which(bad), values, rule, guidance)
  }
  # Coverage percentages; demographic percentages are checked above as numbers.
  coverage <- intersect(setdiff(grep("_pct$", c(spec$required, spec$optional), value = TRUE), spec$numbers), names(x))
  for (column in coverage) {
    values <- trimws(x[[column]])
    valid_format <- valid_coverage_format(values)
    number <- suppressWarnings(as.numeric(sub("%$", "", sub("^[<>]\\s*", "", values))))
    impossible_bound <- (grepl("^>", values) & number >= 100) | (grepl("^<", values) & number <= 0)
    bad <- which(!is.na(values) & (!valid_format | !is.finite(number) | number < 0 | number > 100 | impossible_bound))
    input_problem(problems, file, column, bad, values,
      "must contain percentages from 0 to 100, a bound such as >95 or <5, or blank unknown values",
      "Use a number such as 92.4 (an optional % suffix is allowed), or configure a legitimate withheld code in suppression$redacted_codes.")
  }
  if (layer == "cases" && "year" %in% names(x)) {
    input_problem(problems, file, "year", which(is.na(x$year)), x$year, "cannot be blank",
      "Supply the observation's nonnegative whole calendar year; do not use a withholding code for year.")
  }
  if (layer == "grades" && "grade" %in% names(x)) {
    grade <- trimws(x$grade)
    bad <- which(!is.na(grade) & !grade %in% c("K", "0", as.character(1:12)))
    input_problem(problems, file, "grade", bad, x$grade,
      "must use K or 0 for kindergarten and 1 through 12 for other grades",
      "Replace unsupported grade labels and remove overall-school rows from grades.csv.")
  }
  invisible()
}

validate_input_references <- function(raw, loaded, problems) {
  grades <- raw$grades
  if ("grades" %in% loaded) {
    orphan <- which(!is.na(grades$school_id) & !grades$school_id %in% raw$schools$school_id)
    input_problem(problems, "grades.csv", "school_id", orphan, grades$school_id,
      "must match a school_id in schools.csv",
      "Correct the school identifier or supply its school row in schools.csv; IDs match exactly, including leading zeros.")
    grade_key <- trimws(grades$grade)
    grade_key[grade_key == "0"] <- "K"
    keys <- data.frame(school_id = grades$school_id, grade = grade_key)
    duplicate <- which((duplicated(keys) | duplicated(keys, fromLast = TRUE)) &
      !is.na(keys$school_id) & !is.na(keys$grade))
    input_problem(problems, "grades.csv", "school_id/grade", duplicate,
      paste0("school_id=", grades$school_id, ", grade=", grades$grade),
      "records must be unique",
      "Keep one observation per school and grade; K and 0 both identify kindergarten, so use only one for each school.")
  }
  district_bounds_loaded <- "district_boundaries" %in% loaded
  district_metadata_loaded <- "districts" %in% loaded
  if (district_bounds_loaded || district_metadata_loaded) {
    ids <- if (district_bounds_loaded) raw$district_boundaries$district_id else raw$districts$district_id
    source <- if (district_bounds_loaded) boundary_source(raw$district_boundaries) else "districts.csv"
    # A district_id with no match gives a note (report_notes(), load_app_data.R);
    # the school loads with no linked district.
    bad <- which(!is.na(raw$schools$district_id) & !raw$schools$district_id %in% ids)
    if (length(bad)) problems$note("schools.csv: ", length(bad), " school(s) have a district_id not in ", source,
      "; found ", input_value_details(raw$schools$district_id[bad]), input_row_details(bad),
      ". These schools stay in the dashboard with no linked district. If one should have a district, correct its exact district ID, preserving leading zeros.")
  }
  invisible()
}

validate_boundary_geometry <- function(x, file, problems) {
  guidance <- "Export valid, nonempty Polygon or MultiPolygon boundaries with the correct CRS; repair the source geometry before loading."
  if (!nrow(x)) {
    problems$add_blocking(file, ": geometry has no boundary features. ", guidance)
    return(FALSE)
  }
  tryCatch({
    geometry <- sf::st_geometry(x)
    type <- as.character(sf::st_geometry_type(geometry))
    wrong_type <- which(!type %in% c("POLYGON", "MULTIPOLYGON"))
    input_problem(problems, file, "geometry", wrong_type, type,
      "must use Polygon or MultiPolygon", guidance, boundaries = TRUE, blocking = TRUE)
    empty <- which(sf::st_is_empty(geometry))
    input_problem(problems, file, "geometry", empty, rep("empty geometry", nrow(x)),
      "cannot be empty", guidance, boundaries = TRUE, blocking = TRUE)
    usable <- setdiff(seq_len(nrow(x)), union(wrong_type, empty))
    if (length(usable)) {
      reason <- sf::st_is_valid(geometry[usable], reason = TRUE)
      invalid <- usable[is.na(reason) | reason != "Valid Geometry"]
      details <- rep(NA_character_, nrow(x)); details[usable] <- reason
      input_problem(problems, file, "geometry", invalid, details,
        "must contain valid polygons", guidance, boundaries = TRUE, blocking = TRUE)
      finite <- vapply(geometry[usable], function(g) {
        coordinates <- sf::st_coordinates(g)
        nrow(coordinates) > 0L && all(is.finite(coordinates[, c("X", "Y"), drop = FALSE]))
      }, logical(1))
      input_problem(problems, file, "geometry", usable[!finite], rep("nonfinite coordinates", nrow(x)),
        "must contain finite coordinates", guidance, boundaries = TRUE, blocking = TRUE)
    }
    !length(wrong_type) && !length(empty) && (!length(usable) || (!length(invalid) && all(finite)))
  }, error = function(e) {
    problems$add_blocking(file, ": geometry cannot be used as county/district boundaries (",
      conditionMessage(e), "). ", guidance)
    FALSE
  })
}
