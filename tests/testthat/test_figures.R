test_that("case totals keep zeros, unknown counts and missing rows apart", {
  cases <- data.frame(county_name = c("A", "A", "B", "B"), year = 2020,
                       age_group = c("0-4", "5+", "0-4", "5+"),
                       n_cases = c(0, 2, 1, NA_real_))
  counties <- c("A", "B", "C")
  unknown <- list(case_data = list(missing_records = "unknown"))
  totals <- case_totals(cases, counties, 2020, c("0-4", "5+"), settings = unknown)
  expect_equal(totals$n_cases[match(counties, totals$county_name)], c(2, NA, NA))
  sparse <- list(case_data = list(missing_records = "zero"))
  zero <- case_totals(cases, counties, 2020, c("0-4", "5+"), settings = sparse)
  expect_equal(zero$n_cases[match(counties, zero$county_name)], c(2, NA, 0))
  expect_true(is.na(case_totals(cases, counties, 2020, c("0-4", "5+"), by = character(), settings = sparse)$n_cases))
  selected <- case_totals(cases, "A", 2020:2021, "0-4", by = "year", settings = unknown)
  expect_equal(selected$n_cases, c(0, NA_real_))
})

test_that("years with no records are still listed, as unknown or zero per the settings", {
  cases <- data.frame(county_name = "A", year = 2020, age_group = "0-4", n_cases = 3)
  settings <- list(case_age_groups = c("0-4", "5+"), case_data = list(missing_records = "unknown"))
  totals <- case_totals(cases, "A", years = 2020:2021, by = "year", settings = settings)
  expect_equal(totals$year, c(2020, 2021))
  expect_true(all(is.na(totals$n_cases)))
  settings$case_data <- list(missing_records = "zero")
  expect_equal(case_totals(cases, "A", years = 2020:2021, by = "year", settings = settings)$n_cases, c(3, 0))
  attr(cases, "missing_records") <- "zero"
  expect_equal(case_totals(cases, "A", 2020:2021, by = "year")$n_cases, c(3, 0))
  expect_equal(case_totals(cases, "A", 2020:2021, by = "year",
                           settings = list(case_data = list(missing_records = "unknown")))$n_cases,
               c(3, NA_real_))
})

test_that("epi curves show yearly cases and say which counties are covered", {
  cases <- data.frame(county_name = "A", year = c(2020, 2022), n_cases = c(0, NA_real_))
  unknown <- list(case_data = list(missing_records = "unknown"))
  p <- plot_epicurve(cases, "A", settings = unknown)
  expect_s3_class(p, "ggplot")
  expect_equal(p$data$year, 2020:2022)
  expect_equal(p$data$cases, c(0, NA, NA))
  expect_no_error(ggplot2::ggplot_build(p))
  sparse <- plot_epicurve(cases, "A", settings = list(case_data = list(missing_records = "zero")))
  expect_equal(sparse$data$cases, c(0, 0, NA))
  expect_match(plot_epicurve(cases)$labels$title, "Supplied counties")
  expect_match(plot_epicurve(cases, counties = c("A", "B"))$labels$title, "Statewide")
  observed_counties <- data.frame(county_name = "A")
  attr(observed_counties, "universe_complete") <- FALSE
  expect_match(plot_epicurve(cases, counties = observed_counties)$labels$title, "Supplied counties")
  expect_match(gt::as_raw_html(render_cases_gt(cases, counties = observed_counties)), "complete statewide coverage has not been established")
  empty <- cases[FALSE, ]
  p_empty <- plot_epicurve(empty, counties = c("A", "B"), years = 2020:2021, settings = unknown)
  expect_s3_class(p_empty, "ggplot")
  expect_equal(p_empty$data$cases, c(NA_real_, NA_real_))
  expect_no_error(ggplot2::ggplot_build(p_empty))
})

test_that("the case table and epi curve agree for the same selection", {
  cases <- data.frame(county_name = c("A", "A", "B"), year = 2020,
                       age_group = c("0-4", "5+", "0-4"), n_cases = c(0, 2, 1))
  settings <- list(case_age_groups = c("0-4", "5+"), case_data = list(missing_records = "unknown"))
  table <- render_cases_gt(cases, counties = c("A", "B"), settings = settings,
                            years = 2020:2021)[["_data"]]
  plot <- plot_epicurve(cases, counties = c("A", "B"), settings = settings, years = 2020:2021)
  expect_equal(table$`0-4`, c(1, NA_real_))
  expect_true(all(is.na(table$`5+`)))
  expect_true(all(is.na(plot$data$cases)))
  expect_match(gt::as_raw_html(render_cases_gt(cases, counties = c("A", "B"),
                                               settings = settings, years = 2020:2021)), "Unknown")
})

test_that("grade charts show zeros and use the configured colors for blurred values", {
  grades <- data.frame(school_id = "A", grade = c(0, 1, 2, 3),
                        full_vax_pct = c("0", ">95", "*", "90"),
                        reporting_status = c("reported", "reported", "reported", "not_reported"))
  bins <- list(list(min = 0, background = "red", color = "white"),
                 list(min = 95, background = "green", color = "black"))
  p <- grade_level_plot(grades, "A", settings = list(coverage_bins = bins))
  expect_equal(p$data$full_num, c(0, 95, NA, NA))
  expect_equal(as.character(p$data$grade), c("K", "1", "2", "3"))
  expect_equal(p$data$full_label[1:2], c("0%", ">95%"))
  expect_equal(p$data$full_color[1:2], c("red", "green"))
  expect_no_error(ggplot2::ggplot_build(p))
  grades$full_vax_pct <- NA_character_
  unknown <- grade_level_plot(grades, "A")
  expect_s3_class(unknown, "ggplot")
  expect_true(all(is.na(unknown$data$full_num)))
  expect_no_error(ggplot2::ggplot_build(unknown))
  expect_no_error(ggplot2::ggplot_build(grade_level_plot(grades[FALSE, ], "A")))
})

test_that("plot functions reject bad data with clear errors", {
  expect_error(plot_epicurve(data.frame(year = 2020, n_cases = 1)), "county_name")
  expect_error(plot_epicurve(data.frame(county_name = "A", year = 2020, n_cases = -1)), "nonnegative")
  expect_error(plot_epicurve(data.frame(county_name = "A", year = 2020, n_cases = 1.5)), "whole counts")
  expect_error(grade_level_plot(data.frame(school_id = "A", grade = 0), "A"), "full_vax_pct")
  expect_error(grade_level_plot(data.frame(school_id = "A", grade = 15, full_vax_pct = 50), "A"), "kindergarten")
})
