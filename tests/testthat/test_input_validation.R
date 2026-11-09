validation_school <- function() {
  data.frame(school_id = "S1", school_name = "Example School", enroll = 100,
             full_vax_pct = "95", county_name = "Example", stringsAsFactors = FALSE)
}

validation_directory <- function(...) {
  directory <- tempfile("input-validation-")
  dir.create(directory)
  inputs <- list(...)
  for (file in names(inputs)) {
    if (inherits(inputs[[file]], "sf")) {
      sf::st_write(inputs[[file]], file.path(directory, file), quiet = TRUE)
    } else utils::write.csv(inputs[[file]], file.path(directory, file), row.names = FALSE, na = "")
  }
  directory
}

validation_boundary <- function() {
  sf::st_sf(county_name = "Example", geometry = sf::st_sfc(sf::st_polygon(list(
    matrix(c(-1, -1, 1, -1, 1, 1, -1, 1, -1, -1), ncol = 2, byrow = TRUE)
  )), crs = 4326))
}

test_that("data errors name the file, column, value and row, and say how to fix them", {
  directory <- copy_example()
  edit_csv(directory, "schools.csv", function(x) {
    x$full_vax_pct[1] <- "ninety"
    x$enroll[2] <- "-3.5"
    x$school_name[3] <- NA
    x
  })
  edit_csv(directory, "counties.csv", function(x) { x$students_of_color_pct[1] <- "101"; x })
  edit_csv(directory, "cases.csv", function(x) { x$year[1] <- NA; x$n_cases[2] <- "Inf"; x })
  message <- load_error(directory)
  expect_match(message, 'schools.csv: full_vax_pct.*"ninety".*rows 2')
  expect_match(message, 'schools.csv: enroll.*"-3.5".*rows 3')
  expect_match(message, 'schools.csv: school_name cannot be blank.*rows 4')
  expect_match(message, 'counties.csv: students_of_color_pct.*"101".*rows 2')
  expect_match(message, 'cases.csv: year cannot be blank.*rows 2')
  expect_match(message, 'cases.csv: n_cases.*"Inf".*rows 3')
  expect_match(message, "row 1 is the header", fixed = TRUE)
  expect_match(message, "suppression$redacted_codes", fixed = TRUE)
  expect_match(message, "Supply a nonblank value", fixed = TRUE)
})

test_that("bad coverage values are caught when the data loads", {
  for (value in c("ninety", "101", "-1", "95%%", ">=95", "Inf", ">100", "<0", "N/A")) {
    school <- validation_school(); school$full_vax_pct <- value
    directory <- validation_directory(schools.csv = school)
    message <- load_error(directory, features = only_features("school_summary"))
    expect_match(message, "schools.csv: full_vax_pct", fixed = TRUE, info = value)
    expect_match(message, input_value_details(value), fixed = TRUE, info = value)
    expect_match(message, "rows 2; row 1 is the header", fixed = TRUE, info = value)
    expect_match(message, "percentages from 0 to 100", fixed = TRUE, info = value)
  }
  school <- validation_school(); school$medical_pct <- "invalid exemption"
  directory <- validation_directory(schools.csv = school)
  expect_match(load_error(directory, features = only_features("school_summary")),
               "schools.csv: medical_pct.*invalid exemption")
})

test_that("enrollment must be a whole count and demographic percentages must be in range", {
  for (value in c("-1", "1.5", "Inf", "NaN", "1,250")) {
    school <- validation_school(); school$enroll <- value
    directory <- validation_directory(schools.csv = school)
    message <- load_error(directory, features = only_features("school_summary"))
    expect_match(message, "schools.csv: (column )?enroll", info = value)
    expect_match(message, "rows 2", fixed = TRUE, info = value)
    expect_match(message, "whole counts|unformatted numbers", info = value)
  }
  for (value in c("-1", "101", "Inf", "85%")) {
    county <- data.frame(county_name = "Example", enroll = 100, full_vax_pct = "95",
                         students_of_color_pct = value)
    directory <- validation_directory(schools.csv = validation_school(), counties.csv = county)
    message <- load_error(directory, features = only_features("facility_overview"))
    expect_match(message, "counties.csv: (column )?students_of_color_pct", info = value)
    expect_match(message, "rows 2", fixed = TRUE, info = value)
  }
})

test_that("IDs and names can't be blank in any layer", {
  directory <- copy_example()
  fields <- list(schools.csv = c("school_id", "school_name"),
    facilities.csv = c("facility_id", "facility_name"), grades.csv = c("school_id", "grade"),
    districts.csv = c("district_id", "district_name"), healthcare_centers.csv = "name")
  for (file in names(fields)) {
    columns <- fields[[file]]
    edit_csv(directory, file, function(x) { for (column in columns) x[[column]][1] <- "   "; x })
  }
  message <- load_error(directory)
  for (file in names(fields)) for (column in fields[[file]]) {
    expect_match(message, paste0(file, ": ", column, " cannot be blank"), fixed = TRUE)
  }
  boundary <- validation_boundary(); boundary$county_name <- " "
  directory <- validation_directory(schools.csv = transform(validation_school(), latitude = 0, longitude = 0),
                                    county_boundaries.geojson = boundary)
  expect_match(load_error(directory, features = only_features("facility_map")),
    "county_boundaries.geojson: county_name cannot be blank.*features 1")
})

test_that("grade errors name bad labels, unknown schools and duplicate kindergarten rows", {
  grades <- data.frame(school_id = c("S1", "S1", "S1", "NO-SCHOOL"),
                      grade = c("K", "0", "banana", "2"), enroll = 10, full_vax_pct = "90")
  directory <- validation_directory(schools.csv = validation_school(), grades.csv = grades)
  message <- load_error(directory, features = only_features("grade_plot"))
  expect_match(message, 'grades.csv: grade.*"banana".*rows 4')
  expect_match(message, 'grades.csv: school_id.*"NO-SCHOOL".*rows 5')
  expect_match(message, "Correct the school identifier", fixed = TRUE)
  expect_match(message, "grades.csv: school_id/grade records must be unique", fixed = TRUE)
  expect_match(message, "rows 2, 3", fixed = TRUE)
  expect_match(message, "K and 0 both identify kindergarten", fixed = TRUE)

  grades <- data.frame(school_id = "S1", grade = c(" K ", " 1 "), enroll = 10, full_vax_pct = "90")
  directory <- validation_directory(schools.csv = validation_school(), grades.csv = grades)
  data <- load_app_data(directory, features = only_features("grade_table"))
  expect_identical(data$grades$grade, c("K", "1"))
  expect_false(anyNA(grade_level_table(data$grades, "S1")[["_data"]]$grade))
})

test_that("school district IDs are checked against whichever district data is present", {
  school <- validation_school(); school$district_id <- "BAD-ID"
  district <- data.frame(district_id = "0001", district_name = "Example District", enroll = 100, full_vax_pct = "95")
  directory <- validation_directory(schools.csv = school, districts.csv = district)
  expect_warning(data <- load_app_data(directory, features = only_features("school_summary")),
    'schools.csv: 1 school\\(s\\) have a district_id not in districts.csv.*"BAD-ID".*rows 2.*preserving leading zeros')
  expect_identical(data$schools$district_id, "BAD-ID")

  boundary <- validation_boundary(); boundary$district_id <- "0001"; boundary$county_name <- NULL
  school$latitude <- school$longitude <- 0
  directory <- validation_directory(schools.csv = school, county_boundaries.geojson = validation_boundary(),
                                    district_boundaries.geojson = boundary)
  expect_warning(load_app_data(directory, features = only_features("facility_map")),
    "schools.csv: 1 school(s) have a district_id not in district_boundaries.geojson", fixed = TRUE)

  directory <- validation_directory(schools.csv = school)
  expect_equal(load_error(directory, features = only_features("school_summary")), "")
  school$district_id <- NA_character_
  directory <- validation_directory(schools.csv = school, districts.csv = district)
  expect_equal(load_error(directory, features = only_features("school_summary")), "")
})

test_that("bad boundary shapes stop the load and say to repair the source", {
  school <- transform(validation_school(), latitude = 0, longitude = 0)
  point <- sf::st_sf(county_name = "Example", geometry = sf::st_sfc(sf::st_point(c(0, 0)), crs = 4326))
  empty <- sf::st_sf(county_name = "Example", geometry = sf::st_sfc(sf::st_polygon(), crs = 4326))
  bowtie <- sf::st_sf(county_name = "Example", geometry = sf::st_sfc(sf::st_polygon(list(
    matrix(c(-1, -1, 1, 1, -1, 1, 1, -1, -1, -1), ncol = 2, byrow = TRUE)
  )), crs = 4326))
  for (boundary in list(point, empty, bowtie)) {
    directory <- validation_directory(schools.csv = school, county_boundaries.geojson = boundary)
    message <- load_error(directory, features = only_features("facility_map"))
    expect_match(message, "county_boundaries.geojson: geometry", fixed = TRUE)
    expect_match(message, "features 1", fixed = TRUE)
    expect_match(message, "repair the source geometry", fixed = TRUE)
    expect_false(grepl("Don't know how to get polygon data", message, fixed = TRUE))
  }
})

test_that("bad coordinates are reported as written in the file", {
  school <- transform(validation_school(), latitude = "Inf", longitude = "0")
  directory <- validation_directory(schools.csv = school, county_boundaries.geojson = validation_boundary())
  message <- load_error(directory, features = only_features("facility_map"))
  expect_match(message, "schools.csv: 1 row(s) have coordinates outside", fixed = TRUE)
  expect_match(message, "latitude=Inf, longitude=0", fixed = TRUE)
  expect_match(message, "rows 2", fixed = TRUE)
  expect_match(message, "finite WGS84 decimal degrees", fixed = TRUE)
  school$longitude <- NA_character_
  directory <- validation_directory(schools.csv = school)
  message <- load_error(directory, features = only_features("proximity_table"))
  expect_match(message, "only one of latitude and longitude", fixed = TRUE)
  expect_match(message, "latitude=Inf, longitude=NA", fixed = TRUE)
})

test_that("valid zeros, blanks, redacted values and not-reported rows all load", {
  school <- validation_school()[rep(1, 6), ]; school$school_id <- paste0("S", 1:6)
  school$full_vax_pct <- c("0", NA, "*", ">95", "<5%", "unknown placeholder")
  school$full_vax <- c(0, NA, NA, NA, NA, -999)
  school$reporting_status <- c(rep("reported", 5), "not_reported")
  school$enroll <- 100
  grades <- data.frame(school_id = "S6", grade = c("K", "1"), enroll = c(10, 11),
    full_vax_pct = c("0", "ignored text"), full_vax = c(0, "ignored count"),
    reporting_status = c("reported", "not_reported"))
  county <- data.frame(county_name = "Example", enroll = 100, full_vax_pct = "ignored coverage",
    students_of_color_pct = 0, reporting_status = "not_reported")
  directory <- validation_directory(schools.csv = school, grades.csv = grades, counties.csv = county)
  data <- load_app_data(directory, features = only_features("school_summary", "grade_table", "facility_overview"),
                        redacted_codes = "*")
  expect_equal(data$schools$full_vax_pct_num, c(0, NA, NA, 96, 4, NA))
  expect_equal(data$schools$enroll, rep(100, 6))
  expect_true(is.na(data$schools$full_vax[6]))
  expect_equal(data$grades$full_vax_pct_num, c(0, NA))
  expect_equal(data$grades$enroll, c(10, 11))
  expect_equal(data$counties$students_of_color_pct, 0)
  edit_csv(directory, "schools.csv", function(x) { x$enroll[6] <- -1; x })
  expect_match(load_error(directory, features = only_features("school_summary"), redacted_codes = "*"),
    "schools.csv: enroll.*-1.*rows 7")
})

test_that("badly shaped CSVs and repeated column names get clear errors", {
  directory <- validation_directory(schools.csv = validation_school())
  path <- file.path(directory, "schools.csv")
  writeLines(c('school_id,school_name,enroll,full_vax_pct,county_name',
               'S1,Example,1,250,95,Example'), path)
  message <- load_error(directory, features = only_features("school_summary"))
  expect_match(message, "schools.csv: CSV fields do not match the header's 5 column(s)", fixed = TRUE)
  expect_match(message, "rows 2", fixed = TRUE)
  expect_match(message, "quote text containing commas", fixed = TRUE)
  writeLines(c('school_id,school_name,enroll,enroll,full_vax_pct,county_name',
               'S1,Example,100,100,95,Example'), path)
  expect_match(load_error(directory, features = only_features("school_summary")),
    'schools.csv: column names must be unique; repeated "enroll"', fixed = TRUE)
  writeLines(c('school_id,school_name,enroll,full_vax_pct,county_name',
               'S1,"Example, with a comma', 'and a newline",100,95,Example'), path)
  expect_equal(load_error(directory, features = only_features("school_summary")), "")
  writeLines(c('school_id,school_name,enroll,full_vax_pct,county_name',
               'S1,"Unclosed name,100,95,Example'), path)
  message <- load_error(directory, features = only_features("school_summary"))
  expect_match(message, "schools.csv: CSV fields", fixed = TRUE)
  expect_match(message, "close every quoted field", fixed = TRUE)
})

test_that("broken unused files are ignored, and a location outside every county loads with no county", {
  cases <- data.frame(county_name = "Example", year = 2024, n_cases = 0)
  directory <- validation_directory(cases.csv = cases)
  writeLines("malformed unused coverage", file.path(directory, "schools.csv"))
  writeLines("malformed unused geometry", file.path(directory, "county_boundaries.geojson"))
  expect_equal(load_error(directory, features = only_features("cases_summary")), "")
  school <- transform(validation_school(), county_name = NA_character_, latitude = 10, longitude = 10)
  directory <- validation_directory(schools.csv = school, county_boundaries.geojson = validation_boundary())
  data <- load_app_data(directory, features = only_features("facility_map"))
  expect_true(is.na(data$schools$county_name))
})
