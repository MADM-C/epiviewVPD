# Tests for reading and checking settings files (R/dashboard_settings.R)
# and the maps' starting view (R/map_view.R).

# Writes `code` (the text of a settings file) to a temporary file and
# returns its path
settings_file <- function(code) {
  path <- tempfile(fileext = ".R")
  writeLines(code, path)
  path
}

test_that("the template and the Minnesota settings pass the checks", {
  expect_no_error(read_dashboard_settings(system.file("config", "template.R", package = "epiviewVPD")))
  expect_no_error(read_dashboard_settings(system.file("config", "measles_mn.R", package = "epiviewVPD")))
})

test_that("settings left out get the template's values", {
  s <- read_dashboard_settings(settings_file('list(app = list(title = "My dashboard"))'))
  template <- default_settings()
  expect_equal(s$app$title, "My dashboard")
  expect_equal(s$case_years, template$case_years)
  expect_equal(s$proximity, template$proximity)
  expect_equal(s$labels, template$labels)
  expect_equal(s$text$about_body, template$text$about_body)
  expect_equal(s$notes, template$notes)
})

test_that("one note left out keeps the template's wording; NULL hides it", {
  s <- read_dashboard_settings(settings_file(
    'list(notes = list(nonreporting_school = "Own wording.", redacted = NULL))'
  ))
  expect_equal(s$notes$nonreporting_school, "Own wording.")
  expect_null(s$notes$redacted)
  expect_equal(s$notes$nonreporting_table, default_settings()$notes$nonreporting_table)
})

test_that("lists without names, such as faq, replace the template's as a whole", {
  s <- read_dashboard_settings(settings_file(
    'list(faq = list(list(question = "Q?", answer = "A.")))'
  ))
  expect_length(s$faq, 1)
  expect_equal(s$faq[[1]]$question, "Q?")
})

test_that("a file that doesn't end in a list stops with a message", {
  expect_error(read_dashboard_settings(settings_file("1 + 1")), "must end with a list")
})

test_that("case_years and proximity are checked", {
  expect_error(
    read_dashboard_settings(settings_file("list(case_years = list(min = 2010, max = 2025, selected = c(2005, 2020)))")),
    "case_years\\$selected"
  )
  expect_error(
    read_dashboard_settings(settings_file("list(case_years = list(min = 2010, max = NULL))")),
    "case_years needs"
  )
  expect_error(
    read_dashboard_settings(settings_file("list(proximity = list(default_threshold = 150))")),
    "default_threshold"
  )
})

test_that("map center and zoom go together, and every problem is listed", {
  err <- expect_error(read_dashboard_settings(settings_file(
    "list(map = list(center = c(-94, 46), bounds = 1), proximity = list(default_threshold = -1))"
  )))
  expect_match(conditionMessage(err), "center .* and map\\$zoom go together")
  expect_match(conditionMessage(err), "unknown entries: bounds")
  expect_match(conditionMessage(err), "default_threshold")
  expect_error(read_dashboard_settings(settings_file("list(map = list(zoom = 7))")), "go together")
  expect_error(read_dashboard_settings(settings_file("list(map = list(max_bounds = c(1, 2)))")), "max_bounds")
})

test_that("a named map center is put in longitude, latitude order", {
  s <- read_dashboard_settings(settings_file("list(map = list(center = c(lat = 46.5, lng = -94.5), zoom = 6))"))
  expect_equal(s$map$center, c(-94.5, 46.5))
  s <- read_dashboard_settings(settings_file("list(map = list(center = c(-94.5, 46.5), zoom = 6))"))
  expect_equal(s$map$center, c(-94.5, 46.5))
})

test_that("max_bounds alone keeps the fit to the counties", {
  counties <- sf::st_sf(
    county_name = "A",
    geometry = sf::st_sfc(sf::st_polygon(list(rbind(c(-95, 45), c(-93, 45), c(-93, 47), c(-95, 47), c(-95, 45)))), crs = 4326)
  )
  view <- dashboard_map_view(list(max_bounds = c(-100, 40, -90, 50)), counties)
  expect_equal(unname(view$bounds), c(-95, 45, -93, 47))
  expect_equal(view$max_bounds, c(-100, 40, -90, 50))
  expect_null(view$center)

  view <- dashboard_map_view(NULL, counties)
  expect_equal(unname(view$bounds), c(-95, 45, -93, 47))

  view <- dashboard_map_view(list(center = c(-94, 46), zoom = 6), counties)
  expect_equal(view$center, c(-94, 46))
  expect_null(view$max_bounds)
})

test_that("suppression = NULL means exact numbers; bad values are named", {
  s <- read_dashboard_settings(settings_file("list(suppression = NULL)"))
  expect_equal(s$suppression$blurred_offset, 0)
  expect_equal(s$suppression$redacted_codes, character(0))
  s <- read_dashboard_settings(settings_file("list(suppression = list(blurred_offset = NULL))"))
  expect_equal(s$suppression$blurred_offset, 0)
  expect_error(
    read_dashboard_settings(settings_file('list(suppression = list(blurred_offset = "1"))')),
    "blurred_offset has to be one number"
  )
  expect_error(
    read_dashboard_settings(settings_file("list(suppression = list(redacted_codes = 99))")),
    "redacted_codes has to be text"
  )
})

test_that("settings that have to be lists say so", {
  expect_error(
    read_dashboard_settings(settings_file("list(case_years = c(min = 2010, max = 2020))")),
    "case_years has to be a list"
  )
})

test_that("map centers named longitude/latitude work; out-of-range ones are caught", {
  s <- read_dashboard_settings(settings_file("list(map = list(center = c(latitude = 46.5, longitude = -94.5), zoom = 6))"))
  expect_equal(s$map$center, c(-94.5, 46.5))
  expect_error(
    read_dashboard_settings(settings_file("list(map = list(center = c(-94.5, 146.5), zoom = 6))")),
    "longitude .* then latitude"
  )
})

test_that("misspelled settings give a warning; the shipped settings give none", {
  expect_warning(
    read_dashboard_settings(settings_file('list(case_year = 1, notes = list(nonreportng_school = "x"))')),
    "case_year, notes\\$nonreportng_school"
  )
  expect_no_warning(read_dashboard_settings(system.file("config", "template.R", package = "epiviewVPD")))
  expect_no_warning(read_dashboard_settings(system.file("config", "measles_mn.R", package = "epiviewVPD")))
  expect_no_warning(read_dashboard_settings(settings_file(
    'list(map = NULL, notes = list(enrollment = "As of Oct 1."))'
  )))
})

test_that("the suppression settings reach the loaded data", {
  # blurred_offset: how far past its number a ">95" counts
  one <- load_app_data(example_data_dir(), suppressed_offset = 1)$districts
  two <- load_app_data(example_data_dir(), suppressed_offset = 2)$districts
  blurred <- grepl("^>", one$full_vax_pct)
  expect_true(any(blurred))
  expect_equal(two$full_vax_pct_num[blurred], one$full_vax_pct_num[blurred] + 1)

  # redacted_codes: a code such as "*" is read as blank
  dir <- file.path(tempfile(), "data")
  dir.create(dir, recursive = TRUE)
  file.copy(list.files(example_data_dir(), full.names = TRUE), dir)
  schools <- utils::read.csv(file.path(dir, "schools.csv"), colClasses = "character")
  schools$full_vax[1] <- "*"
  utils::write.csv(schools, file.path(dir, "schools.csv"), row.names = FALSE)
  expect_error(load_app_data(dir), "redacted_codes")
  loaded <- load_app_data(dir, redacted_codes = "*")$schools
  expect_true(is.na(loaded$full_vax[loaded$school_id == schools$school_id[1]]))
})
