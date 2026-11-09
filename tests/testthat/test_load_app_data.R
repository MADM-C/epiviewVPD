# load_app_data() on the example data, and the messages it gives for
# broken copies of it (made in a temporary folder).

test_that("the example data loads into every layer", {
  d <- load_app_data(example_data_dir("full"))
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
  base <- load_app_data(example_data_dir("full"))

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
  expect_match(load_error(dir, features = all_features()), "missing.*grades.csv")
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
  edit_csv(dir, "cases.csv", function(x) {
    x$n_cases <- as.numeric(x$n_cases)
    stats::aggregate(n_cases ~ county_name + year, data = x, FUN = sum)
  })
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
  base <- load_app_data(example_data_dir("full"))
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
  skip_if(Sys.getenv("EPIVIEW_TEST_NETWORK") != "true",
          "Set EPIVIEW_TEST_NETWORK=true to run the Census download integration test")
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

test_that("a city sharing its name with a county keeps its full name", {
  expect_equal(
    census_county_names(c("Baltimore", "Baltimore", "Kent"), c("Baltimore County", "Baltimore city", "Kent County")),
    c("Baltimore", "Baltimore city", "Kent")
  )
  expect_equal(census_county_names(c("Kent", "Alexandria"), c("Kent County", "Alexandria city")), c("Kent", "Alexandria"))
  expect_equal(census_county_names("Kent", NULL), "Kent")
})

# A layer with the columns tigris::counties() returns, for a state where a
# city and a county share a name
census_counties_with_shared_name <- function() {
  square <- function(x) sf::st_polygon(list(rbind(c(x, 39), c(x + 1, 39), c(x + 1, 40), c(x, 40), c(x, 39))))
  sf::st_sf(GEOID = c("24005", "24029", "24510"), NAME = c("Baltimore", "Kent", "Baltimore"),
            NAMELSAD = c("Baltimore County", "Kent County", "Baltimore city"),
            geometry = sf::st_sfc(square(-77), square(-76), square(-75), crs = 4326))
}

# Data folder holding the given data frames, one CSV per named argument
census_names_data_dir <- function(...) {
  layers <- list(...)
  dir <- tempfile("census-names-")
  dir.create(dir)
  for (layer in names(layers)) {
    utils::write.csv(layers[[layer]], file.path(dir, paste0(layer, ".csv")), row.names = FALSE, na = "")
  }
  dir
}

census_names_features <- only_features("coverage_map", "cases_map", "school_summary")

test_that("the county download gives a shared name's city and county different names", {
  testthat::local_mocked_bindings(counties = function(...) census_counties_with_shared_name(), .package = "tigris")
  problems <- new_problem_list()
  counties <- download_boundaries("county_boundaries", list(state = "MD"), problems)
  expect_equal(problems$get(), character(0))
  expect_equal(counties$county_name, c("Baltimore", "Kent", "Baltimore city"))
  expect_equal(counties$county_fips, c("24005", "24029", "24510"))
})

test_that("a shared name's city and county stay separate when matched by FIPS", {
  testthat::local_mocked_bindings(counties = function(...) census_counties_with_shared_name(), .package = "tigris")
  dir <- census_names_data_dir(
    counties = data.frame(county_fips = c("24510", "24005", "24029"),
                          county_name = c("Baltimore city", "Baltimore County", "Kent County"),
                          enroll = c(100, 200, 300), full_vax_pct = c("90", "80", "70")),
    cases = data.frame(county_fips = c("24510", "24005"), year = 2024, n_cases = c(3, 5)),
    # the first school has no county and sits inside the city's square
    schools = data.frame(school_id = c("1", "2"), school_name = c("City School", "County School"),
                         county_fips = c(NA, "24005"), latitude = 39.5, longitude = c(-74.5, -76.5),
                         enroll = 50, full_vax_pct = "90"))
  d <- load_app_data(dir, features = census_names_features, geography = list(state = "MD"))
  expect_equal(d$counties$county_name, c("Baltimore", "Kent", "Baltimore city"))
  expect_equal(d$counties$enroll, c(200, 300, 100))
  expect_equal(d$cases$county_name, c("Baltimore city", "Baltimore"))
  expect_equal(d$schools$county_name, c("Baltimore city", "Baltimore"))
  expect_equal(unname(d$schools$county_fips), c("24510", "24005"))
})

test_that("name-only rows find the county under its short name and the city under its full name", {
  testthat::local_mocked_bindings(counties = function(...) census_counties_with_shared_name(), .package = "tigris")
  dir <- census_names_data_dir(
    counties = data.frame(county_name = c("BALTIMORE CITY", "Baltimore", "Kent"), enroll = c(100, 200, 300),
                          full_vax_pct = c("90", "80", "70")),
    cases = data.frame(county_name = c("Baltimore city", "Baltimore"), year = 2024, n_cases = c(3, 5)),
    schools = data.frame(school_id = "1", school_name = "City School", county_name = "Baltimore City",
                         latitude = 39.5, longitude = -74.5, enroll = 50, full_vax_pct = "90"))
  d <- load_app_data(dir, features = census_names_features, geography = list(state = "MD"))
  expect_equal(d$counties$enroll, c(200, 300, 100))
  expect_equal(unname(d$cases$county_fips), c("24510", "24005"))
  expect_equal(unname(d$schools$county_fips), "24510")

  dir <- census_names_data_dir(
    counties = data.frame(county_name = c("Baltimore County", "Kent"), enroll = c(100, 300), full_vax_pct = c("90", "70")),
    cases = data.frame(county_name = "Kent", year = 2024, n_cases = 3),
    schools = data.frame(school_id = "1", school_name = "A School", county_name = "Kent",
                         latitude = 39.5, longitude = -75.5, enroll = 50, full_vax_pct = "90"))
  expect_match(load_error(dir, features = census_names_features, geography = list(state = "MD")),
               "counties.csv: 1 county name\\(s\\) not in the Census county boundaries for MD: Baltimore County \\(leave out \"County\"\\)")
})

test_that("Census downloads have one name per county where a city shares a county's name", {
  skip_if(Sys.getenv("EPIVIEW_TEST_NETWORK") != "true",
          "Set EPIVIEW_TEST_NETWORK=true to run the Census download integration test")
  skip_on_cran()
  skip_if_offline("www2.census.gov")
  problems <- new_problem_list()
  named <- function(state) {
    counties <- download_boundaries("county_boundaries", list(state = state), problems)
    stats::setNames(counties$county_fips, counties$county_name)
  }
  md <- named("MD")
  expect_equal(unname(md[c("Baltimore", "Baltimore city")]), c("24005", "24510"))
  va <- named("VA")
  expect_true(all(c("Fairfax", "Fairfax city", "Franklin", "Franklin city", "Richmond", "Richmond city",
                    "Roanoke", "Roanoke city") %in% names(va)))
  mo <- named("MO")
  expect_equal(unname(mo[c("St. Louis", "St. Louis city")]), c("29189", "29510"))
  for (state_names in list(md, va, mo)) expect_false(anyDuplicated(tolower(names(state_names))) > 0)
  expect_equal(problems$get(), character(0))
})

# Copy of the example data with a marked name in the middle of `file`. The
# marker byte `~` is replaced by `accent` bytes: as.raw(0xF1) is n-tilde in
# Windows-1252, as.raw(c(0xC3, 0xB1)) in UTF-8.
accented_csv_dir <- function(file, name_col, accent, quote = TRUE, prefix = raw(0), eol = "\n") {
  dir <- copy_example()
  path <- file.path(dir, file)
  x <- utils::read.csv(path, colClasses = "character", check.names = FALSE, na.strings = "")
  middle <- ceiling(nrow(x) / 2)
  x[[name_col]][middle] <- "Pe~a Child Care"
  utils::write.table(x, path, sep = ",", row.names = FALSE, na = "", quote = quote, eol = eol)
  bytes <- readBin(path, "raw", file.size(path))
  at <- which(bytes == as.raw(0x7EL))
  stopifnot(length(at) == 1L)
  writeBin(c(prefix, bytes[seq_len(at - 1L)], accent, bytes[-seq_len(at)]), path)
  list(dir = dir, id = x[[1]][middle], enroll = x$enroll[middle])
}

test_that("a Windows-1252 CSV keeps every row and its accented text, with a note", {
  base <- load_app_data(example_data_dir("full"))
  for (quote in c(TRUE, FALSE)) {
    made <- accented_csv_dir("facilities.csv", "facility_name", as.raw(0xF1L), quote = quote)
    expect_warning(d <- load_app_data(made$dir), "facilities.csv: isn't saved as UTF-8")
    expect_equal(nrow(d$facilities), nrow(base$facilities))
    row <- d$facilities[d$facilities$facility_id == made$id, ]
    expect_identical(row$facility_name, "Peña Child Care")
    expect_true(validUTF8(row$facility_name))
    expect_equal(row$enroll, as.numeric(made$enroll))
    expect_identical(row$county_name, base$facilities$county_name[base$facilities$facility_id == made$id])
  }
})

test_that("accented UTF-8 CSVs load with no note", {
  bom <- as.raw(c(0xEF, 0xBB, 0xBF))
  cases <- list(list(prefix = raw(0), eol = "\n"), list(prefix = bom, eol = "\n"),
                list(prefix = bom, eol = "\r\n"), list(prefix = raw(0), eol = "\r\n"))
  base <- load_app_data(example_data_dir("full"))
  for (case in cases) {
    made <- accented_csv_dir("facilities.csv", "facility_name", as.raw(c(0xC3L, 0xB1L)),
                             prefix = case$prefix, eol = case$eol)
    expect_no_warning(d <- load_app_data(made$dir))
    expect_equal(nrow(d$facilities), nrow(base$facilities))
    expect_identical(names(d$facilities), names(base$facilities))
    expect_identical(d$facilities$facility_name[d$facilities$facility_id == made$id], "Peña Child Care")
  }
})

test_that("a CSV that can't be opened gets the loader's clear message", {
  dir <- copy_example()
  path <- file.path(dir, "facilities.csv")
  file.remove(path)
  dir.create(path)
  msg <- suppressWarnings(load_error(dir))
  expect_match(msg, "can't be loaded")
  expect_match(msg, "facilities.csv: can't be read as CSV (cannot open the connection)", fixed = TRUE)
})

test_that("a CSV that isn't text, or is damaged, stops the load", {
  row_text <- function(n) paste0(n, ",Peña,1\n")
  damaged <- list(
    # UTF-16 from a spreadsheet's "Unicode text": null bytes
    utf16 = c(as.raw(c(0xFF, 0xFE)), as.vector(rbind(charToRaw("facility_id,facility_name\n"), as.raw(0x00L)))),
    # Binary that holds no null bytes
    binary = as.raw(c(0x50, 0x4B, 0x03, 0x04, 0x14, 0xE9, 0x06, 0x0A)),
    # A byte Windows-1252 leaves undefined
    undefined = c(charToRaw("facility_id,facility_name\n1,Pe"), as.raw(0x81L), charToRaw("a\n")),
    # UTF-8 with one corrupt byte among many good accented lines
    corrupt_utf8 = c(charToRaw(paste(vapply(1:10, row_text, ""), collapse = "")), as.raw(0xF1L), charToRaw("\n"))
  )
  for (name in names(damaged)) {
    dir <- copy_example()
    writeBin(damaged[[name]], file.path(dir, "facilities.csv"))
    expect_match(load_error(dir), "facilities.csv: can't be read as CSV", info = name)
  }
})
