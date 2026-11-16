# Zeros count as measured values; blanks and withheld codes count as unknown.
test_that("the loader keeps measured zeros distinct from unknown values", {
  dir <- copy_example()
  edit_csv(dir, "cases.csv", function(x) {
    x$n_cases[1:3] <- c("0", NA, "*")
    x
  })
  edit_csv(dir, "schools.csv", function(x) {
    x$full_vax[1:3] <- c("0", NA, "*")
    x$full_vax_pct[1:3] <- c("0", NA, "*")
    x
  })
  for (policy in c("unknown", "zero")) {
    data <- load_app_data(dir, redacted_codes = "*", case_data = list(missing_records = policy))
    expect_equal(data$cases$n_cases[1:3], c(0L, NA_integer_, NA_integer_))
    expect_equal(data$schools$full_vax[1:3], c(0, NA, NA))
    expect_equal(data$schools$full_vax_pct[1:3], c("0", NA, NA))
    expect_equal(data$schools$full_vax_pct_num[1:3], c(0, NA, NA))
  }
})

test_that("invalid case counts and years stop the load", {
  for (value in c("-1", "0.5")) {
    dir <- copy_example()
    edit_csv(dir, "cases.csv", function(x) { x$n_cases[1] <- value; x })
    expect_error(load_app_data(dir), "cases.csv.*n_cases")
  }
  dir <- copy_example()
  edit_csv(dir, "cases.csv", function(x) { x$year[1] <- "2020.5"; x })
  expect_error(load_app_data(dir), "cases.csv.*year")
})

test_that("a measured zero doesn't count as not reporting", {
  dir <- copy_example()
  edit_csv(dir, "schools.csv", function(x) {
    x$reporting_status <- NA_character_
    x$reporting_status[1:3] <- c("reported", "not_reported", NA)
    x$full_vax[1:3] <- c("0", "12", NA)
    x$full_vax_pct[1:3] <- c("0", "30", NA)
    x$partial_vax[1:3] <- c("0", "10", NA)
    x$partial_vax_pct[1:3] <- c("0", "25", NA)
    x
  })
  data <- load_app_data(dir)$schools
  expect_equal(data$full_vax_pct[1], "0")
  expect_equal(data$full_vax_pct_num[1], 0)
  expect_equal(data$full_vax[1], 0)
  expect_equal(data$partial_vax[1], 0)
  expect_true(all(is.na(unlist(sf::st_drop_geometry(data)[2, c("full_vax", "full_vax_pct", "full_vax_pct_num", "partial_vax", "partial_vax_pct")]))))
  original <- utils::read.csv(file.path(dir, "schools.csv"))
  expect_equal(data$enroll[2], original$enroll[2])
  expect_true(is.na(data$full_vax_pct_num[3]))
  expect_equal(is_nonresponder(data$school_id[1], data), FALSE)
  expect_equal(is_nonresponder(data$school_id[2], data), TRUE)
})

test_that("an invalid reporting status is named in the error", {
  dir <- copy_example()
  edit_csv(dir, "schools.csv", function(x) { x$reporting_status <- "not reporting"; x })
  expect_error(load_app_data(dir), "schools.csv.*reporting_status")
})

test_that("a county that didn't report loses its coverage numbers but keeps other columns", {
  dir <- copy_example()
  edit_csv(dir, "counties.csv", function(x) {
    x$reporting_status <- NA_character_
    x$reporting_status[1] <- "not_reported"
    x$enroll[1] <- "100"
    x$full_vax[1] <- "90"
    x$full_vax_pct[1] <- "90"
    x$students_of_color_pct[1] <- "12.5"
    x$frl_eligible_pct[1] <- "40"
    x
  })
  source <- utils::read.csv(file.path(dir, "counties.csv"))
  counties <- load_app_data(dir)$counties
  row <- match(source$county_name[1], counties$county_name)
  expect_equal(counties$enroll[row], 100)
  expect_equal(counties$students_of_color_pct[row], 12.5)
  expect_equal(counties$frl_eligible_pct[row], 40)
  expect_true(is.na(counties$full_vax[row]))
  expect_true(is.na(counties$full_vax_pct_num[row]))
})

test_that("the statewide rate is unknown if any county's numbers are unknown", {
  counts <- data.frame(full_vax = c(0, 0), enroll = c(20, 30))
  expect_equal(calc_statewide_k12(counts), 0)
  counts$full_vax <- c(5, 15)
  expect_equal(calc_statewide_k12(counts), 40)
  counts$full_vax[2] <- NA_real_
  expect_true(is.na(calc_statewide_k12(counts)))
  counts$full_vax[2] <- 15
  counts$enroll[2] <- NA_real_
  expect_true(is.na(calc_statewide_k12(counts)))
  expect_true(is.na(calc_statewide_k12(data.frame(full_vax = 0, enroll = 0))))
  counts <- data.frame(full_vax = c(5, 15), enroll = c(20, 30),
                       reporting_status = c("reported", "not_reported"))
  expect_true(is.na(calc_statewide_k12(counts)))
})

test_that("case tables fill missing cells with 0 only when missing_records is zero", {
  cases <- data.frame(
    county = "A", year = c(2020L, 2020L, 2021L),
    age_group = c("0-17", "18+", "0-17"), n_cases = c(0L, NA_integer_, 3L)
  )
  ages <- c("0-17", "18+", "Unknown")
  unknown <- render_cases_gt(cases, "A", ages, years = 2020:2021,
                             settings = list(case_data = list(missing_records = "unknown")))[["_data"]]
  zeros <- render_cases_gt(cases, "A", ages, years = 2020:2021,
                           settings = list(case_data = list(missing_records = "zero")))[["_data"]]
  expect_equal(unknown$`0-17`, c(0, 3))
  expect_true(all(is.na(unknown$`18+`)))
  expect_true(all(is.na(unknown$Unknown)))
  expect_equal(zeros$`0-17`, c(0, 3))
  expect_equal(zeros$`18+`, c(NA, 0))
  expect_equal(zeros$Unknown, c(0, 0))
})

test_that("statewide case tables stay unknown when one county's count is unknown", {
  cases <- data.frame(
    county = c("A", "B", "A", "B"), year = 2020L,
    age_group = c("0-17", "0-17", "18+", "18+"), n_cases = c(0L, 0L, 3L, NA_integer_)
  )
  for (policy in c("unknown", "zero")) {
    wide <- render_cases_gt(cases, "Statewide", c("0-17", "18+"), years = 2020L,
                            settings = list(case_data = list(missing_records = policy)))[["_data"]]
    expect_equal(wide$`0-17`, 0)
    expect_true(is.na(wide$`18+`))
  }
})

# Dropdown choices for a county or district with no child cares or no schools
# (issue #16: the dropdown stopped with "NAs are not allowed in subscripted assignments").
test_that("facility dropdown choices work for areas with no schools or child cares", {
  data <- load_app_data(example_data_dir("full"), features = all_features())
  empty_county <- setdiff(data$counties$county_name, data$facilities$county_name)[1]
  empty_district <- setdiff(data$districts$district_id, data$schools$district_id)[1]
  expect_false(is.na(empty_county))
  expect_false(is.na(empty_district))
  areas <- list(county = empty_county, district = empty_district)
  for (boundary in names(areas)) {
    for (points in c("Schools", "Child Cares", "Schools and Child Cares")) {
      choices <- get_location_choices_data(TRUE, boundary, points,
                                           if (boundary == "district") areas[[boundary]] else NULL,
                                           if (boundary == "county") areas[[boundary]] else NULL,
                                           data$districts, data$counties, data$schools, data$facilities)
      expect_false(anyNA(names(choices)))
      expect_true(all(grepl("^(school|facility):.+", choices)))
      expect_no_error(shiny::selectizeInput("x", "x", choices = c("", choices)))
    }
  }
  county_care <- get_location_choices_data(TRUE, "county", "Child Cares", NULL, empty_county,
                                           data$districts, data$counties, data$schools, data$facilities)
  expect_length(county_care, 0)
})
