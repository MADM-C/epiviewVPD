# load_app_data() on the example data, and the messages it gives for
# broken copies of it (made in a temporary folder).

copy_example <- function() {
  dir <- tempfile("example-data-")
  dir.create(dir)
  file.copy(list.files(example_data_dir(), full.names = TRUE), dir)
  dir
}
edit_csv <- function(dir, file, fn) {
  path <- file.path(dir, file)
  x <- utils::read.csv(path, colClasses = "character", check.names = FALSE, na.strings = "")
  utils::write.csv(fn(x), path, row.names = FALSE, na = "")
}
load_error <- function(dir) {
  tryCatch({
    load_app_data(dir)
    ""
  }, error = function(e) conditionMessage(e))
}

test_that("the example data loads into every layer", {
  d <- load_app_data(example_data_dir())
  expect_named(d, c("counties", "schools", "facilities", "grades", "districts", "cases", "healthcare_centers"))
  for (layer in c("counties", "schools", "facilities", "districts", "healthcare_centers")) {
    expect_s3_class(d[[layer]], "sf")
    expect_true(sf::st_crs(d[[layer]]) == sf::st_crs(4326))
  }
  expect_gt(nrow(d$schools), 0)
  expect_type(d$schools$school_id, "character")
  expect_type(d$schools$enroll, "double")
  # child cares without a location get an empty point and no county
  empty <- sf::st_is_empty(d$facilities)
  expect_true(any(empty))
  expect_true(all(is.na(d$facilities$county_name[empty])))
  # every school's county is one of the counties
  expect_true(all(d$schools$county_name %in% d$counties$county_name))
})

test_that("pct_number reads plain and suppressed percentages", {
  expect_equal(pct_number(c("92.4", "92.4%", ">95", "<5", "N/A", NA)), c(92.4, 92.4, 96, 4, NA, NA))
  expect_equal(pct_number(">95", offset = 0), 95)
})

test_that("county names are matched ignoring case, or worked out from coordinates", {
  base <- load_app_data(example_data_dir())

  dir <- copy_example()
  edit_csv(dir, "schools.csv", function(x) { x$county_name <- toupper(x$county_name); x })
  expect_equal(load_app_data(dir)$schools$county_name, base$schools$county_name)

  dir <- copy_example()
  edit_csv(dir, "schools.csv", function(x) { x$county_name <- NULL; x })
  expect_equal(load_app_data(dir)$schools$county_name, base$schools$county_name)
})

test_that("a missing column is named, along with other file-level problems", {
  dir <- copy_example()
  edit_csv(dir, "counties.csv", function(x) { x$full_vax_pct <- NULL; x })
  edit_csv(dir, "schools.csv", function(x) { x$school_name <- NULL; x$enroll <- NULL; x })
  msg <- load_error(dir)
  expect_match(msg, "counties.csv: missing required column full_vax_pct")
  expect_match(msg, "schools.csv: missing required columns school_name, enroll")
})

test_that("a missing file is named", {
  dir <- copy_example()
  file.remove(file.path(dir, "grades.csv"))
  expect_match(load_error(dir), "missing: grades.csv")
})

test_that("broken files are reported together, naming file and column", {
  dir <- copy_example()
  edit_csv(dir, "schools.csv", function(x) {
    x$enroll[1] <- "about 400"
    x$school_id[3] <- x$school_id[2]
    x$latitude[4] <- x$longitude[4] # swapped coordinates go out of range
    x
  })
  edit_csv(dir, "cases.csv", function(x) { x$county_name[1] <- "Nowhere"; x })
  edit_csv(dir, "facilities.csv", function(x) { x$county_name[2] <- paste(x$county_name[2], "County"); x })
  msg <- load_error(dir)
  expect_match(msg, "facilities.csv: 1 county name\\(s\\) not in county_boundaries.geojson: .* County \\(leave out \"County\"\\)")
  expect_match(msg, "schools.csv: column enroll should hold numbers but has \"about 400\"")
  expect_match(msg, "schools.csv: 1 school_id value\\(s\\) appear more than once")
  expect_match(msg, "schools.csv: 1 row\\(s\\) have coordinates outside")
  expect_match(msg, "cases.csv: 1 county name\\(s\\) not in county_boundaries.geojson: Nowhere")
})

test_that("districts need a boundary and points need both coordinates", {
  dir <- copy_example()
  edit_csv(dir, "districts.csv", function(x) { x$district_id[1] <- "no-such-district"; x })
  edit_csv(dir, "facilities.csv", function(x) { i <- which(!is.na(x$latitude))[1]; x$longitude[i] <- NA; x })
  msg <- load_error(dir)
  expect_match(msg, "districts.csv: 1 district_id\\(s\\) not in district_boundaries.geojson: no-such-district")
  expect_match(msg, "facilities.csv: 1 row\\(s\\) have only one of latitude and longitude")
})

test_that("left-out optional columns become blank columns", {
  dir <- copy_example()
  edit_csv(dir, "schools.csv", function(x) { x$school_type <- NULL; x$full_vax <- NULL; x })
  edit_csv(dir, "cases.csv", function(x) { x$age_group <- NULL; x })
  d <- load_app_data(dir)
  expect_true(all(is.na(d$schools$school_type)))
  expect_type(d$schools$school_type, "character")
  expect_true(all(is.na(d$schools$full_vax)))
  expect_type(d$schools$full_vax, "double")
  expect_true(all(is.na(d$cases$age_group)))
})

test_that("the data format guide lists every column the loader knows", {
  guide <- testthat::test_path("..", "..", "vignettes", "data-format.Rmd")
  skip_if_not(file.exists(guide))
  text <- paste(readLines(guide), collapse = "\n")
  for (layer in names(DATA_FILES)) {
    spec <- DATA_FILES[[layer]]
    # the section for this file runs from its heading to the next one
    start <- regexpr(paste0("## `", spec$file, "`"), text, fixed = TRUE)
    expect_gt(start, 0, label = paste("section for", spec$file))
    rest <- substring(text, start + 3)
    section <- sub("\n## .*", "", rest)
    for (col in c(spec$required, spec$optional)) {
      expect_match(section, paste0("`", col, "`"), fixed = TRUE, label = paste(spec$file, col))
    }
  }
})

# Example boundaries with made-up county FIPS codes added
add_fips <- function(dir) {
  path <- file.path(dir, "county_boundaries.geojson")
  b <- sf::st_read(path, quiet = TRUE)
  b$county_fips <- sprintf("99%03d", seq_len(nrow(b)))
  file.remove(path)
  sf::st_write(b, path, quiet = TRUE)
  stats::setNames(b$county_fips, b$county_name)
}

test_that("counties are matched by county_fips first, then by name", {
  base <- load_app_data(example_data_dir())
  dir <- copy_example()
  fips <- add_fips(dir)
  # counties.csv by FIPS only; schools by FIPS with a misspelled name, which is ignored
  edit_csv(dir, "counties.csv", function(x) { x$county_fips <- fips[x$county_name]; x$county_name <- NULL; x })
  edit_csv(dir, "schools.csv", function(x) { x$county_fips <- fips[x$county_name]; x$county_name <- "Misspelled"; x })
  d <- load_app_data(dir)
  expect_equal(d$counties$county_name, base$counties$county_name)
  expect_equal(d$counties$enroll, base$counties$enroll)
  expect_equal(d$schools$county_name, base$schools$county_name)
  expect_equal(unname(d$schools$county_fips), unname(fips[d$schools$county_name]))
})

test_that("unknown FIPS codes are reported, with a hint about leading zeros", {
  dir <- copy_example()
  fips <- add_fips(dir)
  edit_csv(dir, "cases.csv", function(x) { x$county_fips <- fips[x$county_name]; x$county_fips[1] <- "9901"; x })
  expect_match(load_error(dir), "cases.csv: 1 county_fips value\\(s\\) not in county_boundaries.geojson: 9901 \\(5 digits: keep leading zeros\\)")
})

test_that("without boundary files or a state, the message says what to do", {
  dir <- copy_example()
  file.remove(file.path(dir, "county_boundaries.geojson"))
  expect_match(load_error(dir), "county_boundaries.geojson isn't in the data folder, and the settings don't name a state")
})

test_that("Census boundaries download with the columns the loader needs", {
  skip_on_cran()
  skip_if_offline("www2.census.gov")
  problems <- new_problem_list()
  counties <- download_boundaries("county_boundaries", list(state = "DE"), problems)
  districts <- download_boundaries("district_boundaries", list(state = "DE"), problems)
  expect_equal(problems$get(), character(0))
  expect_setequal(counties$county_name, c("Kent", "New Castle", "Sussex"))
  expect_true(all(nchar(counties$county_fips) == 5))
  expect_true(sf::st_crs(counties) == sf::st_crs(4326))
  expect_true(all(nchar(districts$district_id) == 7))
  expect_match(boundary_source(counties), "Census county boundaries for DE")
})
