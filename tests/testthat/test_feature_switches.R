# Which outputs are on, and which data files they need
BASIC_FEATURES <- c("coverage_map", "cases_map", "facility_map", "school_summary",
                    "cases_summary", "epicurve", "about")

test_that("the basic dashboard is on by default and the template agrees", {
  on <- function(features) names(features)[unlist(features)]
  expect_setequal(on(default_features()), BASIC_FEATURES)
  expect_setequal(on(default_settings()$features), BASIC_FEATURES)
  expect_true(all(unlist(all_features())))
  expect_true(all(unlist(read_dashboard_settings(
    system.file("config", "measles_mn.R", package = "epiviewVPD"))$features)))
})

test_that("the basic dashboard needs only counties, schools, cases and boundaries", {
  expect_setequal(required_data_layers(), c("counties", "county_boundaries", "schools", "cases"))
  expect_setequal(list.files(example_data_dir()),
                  c("counties.csv", "schools.csv", "cases.csv", "county_boundaries.geojson"))
  expect_s3_class(run_dashboard(data_dir = example_data_dir()), "shiny.appobj")
})

test_that("load_app_data without features uses the files in the folder", {
  basic <- load_app_data(example_data_dir())
  expect_gt(nrow(basic$schools), 0)
  expect_equal(nrow(basic$grades), 0)
  full <- load_app_data(example_data_dir("full"))
  expect_gt(nrow(full$grades), 0)
  expect_gt(nrow(full$facilities), 0)
  expect_error(load_app_data(tempfile("no-such-folder-")), "doesn't exist")
})

test_that("partial feature settings keep the other switches at their defaults", {
  s <- prepare_dashboard_settings(list(features = list(epicurve = FALSE, grade_plot = TRUE)))
  expect_false(s$features$epicurve)
  expect_true(s$features$grade_plot)
  expect_true(s$features$coverage_map)
  expect_false(s$features$grade_table)
  expect_named(s$features, c(
    "coverage_map", "cases_map", "facility_map", "facility_overview",
    "grade_plot", "grade_table", "school_summary", "childcare_summary",
    "cases_summary", "epicurve", "proximity_map", "proximity_table",
    "about", "resources"
  ))
})

test_that("feature switches reject ambiguous or misspelled values", {
  for (value in list(NA, 1, "false", c(TRUE, FALSE), NULL)) {
    expect_error(prepare_dashboard_settings(list(features = list(epicurve = value))),
                 "features")
  }
  expect_error(normalize_features(list(epicurv = FALSE)), "Unknown feature switch.*epicurv")
  expect_error(normalize_features(list(FALSE)), "named list")
  expect_error(normalize_features(list(epicurve = FALSE, epicurve = TRUE)), "named list")
})

test_that("missing_records defaults to zero, can be set to unknown and rejects other values", {
  expect_equal(prepare_dashboard_settings()$case_data$missing_records, "zero")
  expect_equal(prepare_dashboard_settings(list(case_data = list(missing_records = "unknown")))$case_data$missing_records,
               "unknown")
  for (value in list("", "zeros", NA, TRUE, c("zero", "unknown"))) {
    expect_error(prepare_dashboard_settings(list(case_data = list(missing_records = value))),
                 "case_data\\$missing_records")
  }
})

test_that("each output needs only the files it uses", {
  required <- list(
    coverage_map = c("counties.csv", "county_boundaries.geojson"),
    cases_map = c("cases.csv", "county_boundaries.geojson"),
    facility_map = c("schools.csv", "county_boundaries.geojson"),
    facility_overview = "schools.csv",
    grade_plot = c("schools.csv", "grades.csv"),
    grade_table = c("schools.csv", "grades.csv"),
    school_summary = "schools.csv",
    childcare_summary = "facilities.csv",
    cases_summary = "cases.csv",
    epicurve = "cases.csv",
    proximity_map = c("schools.csv", "county_boundaries.geojson"),
    proximity_table = "schools.csv",
    about = character(),
    resources = character()
  )
  coordinate_free <- c("facility_overview", "grade_plot", "grade_table", "school_summary", "childcare_summary")
  for (feature in names(required)) {
    dir <- feature_data_dir(required[[feature]], feature %in% coordinate_free)
    data <- NULL
    expect_no_error(data <- load_app_data(dir, features = only_features(feature)))
    expect_type(data, "list")
    expect_named(data, c("counties", "schools", "facilities", "grades", "districts", "cases", "healthcare_centers"),
                 info = feature)
  }
})

test_that("turned-off outputs need no files and ignore broken ones", {
  dir <- feature_data_dir("cases.csv")
  writeLines("this is not valid GeoJSON", file.path(dir, "county_boundaries.geojson"))
  writeLines("unexpected\nmalformed", file.path(dir, "schools.csv"))
  data <- load_app_data(dir, features = only_features("epicurve"))
  expect_gt(nrow(data$cases), 0)
  expect_equal(nrow(data$schools), 0)
  expect_equal(nrow(data$districts), 0)
  expect_equal(nrow(data$healthcare_centers), 0)
  empty <- load_app_data(feature_data_dir(character()), features = only_features())
  expect_true(all(vapply(empty, nrow, 0L) == 0L))
  for (features in list(only_features(), only_features("about"), only_features("resources"))) {
    no_folder <- load_app_data(tempfile("no-data-needed-"), features = features)
    expect_true(all(vapply(no_folder, nrow, 0L) == 0L))
  }
})

test_that("turned-on outputs name the data files they are missing", {
  dir <- feature_data_dir(character())
  expect_error(load_app_data(dir, features = only_features("cases_summary")), "cases.csv")
  expect_error(load_app_data(dir, features = only_features("school_summary")), "schools.csv")
  expect_error(load_app_data(dir, features = only_features("childcare_summary")), "facilities.csv")
  expect_error(load_app_data(dir, features = only_features("grade_table")), "grades.csv|schools.csv")
  expect_error(load_app_data(dir, features = only_features("facility_overview")), "schools.csv.*facilities.csv|facilities.csv.*schools.csv")
})

test_that("point outputs work with schools alone or child cares alone", {
  for (feature in c("facility_map", "facility_overview", "proximity_map", "proximity_table")) {
    for (source in c("schools.csv", "facilities.csv")) {
      files <- c(source, if (feature %in% c("facility_map", "proximity_map")) "county_boundaries.geojson")
      data <- load_app_data(feature_data_dir(files), features = only_features(feature))
      layer <- if (source == "schools.csv") "schools" else "facilities"
      expect_gt(nrow(data[[layer]]), 0)
      expect_equal(nrow(data$districts), 0)
      expect_equal(nrow(data$healthcare_centers), 0)
    }
  }
})
