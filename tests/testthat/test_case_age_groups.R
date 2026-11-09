# Case age groups from the settings or the data (R/case_age_groups.R)

# Column headings of a case table, as shown
case_table_headings <- function(...) {
  html <- gt::as_raw_html(render_cases_gt(...))
  heads <- regmatches(html, gregexpr("<th[^>]*scope=\"col\"[^>]*>[^<]*</th>", html))[[1]]
  gsub("<[^>]+>", "", heads)
}

test_that("without a settings list, the data's groups are sorted by their first number", {
  values <- c("50+", "Unknown", "5-11", NA, "0-4", "", "12-19", "5-11")
  expect_equal(case_age_groups(NULL, values), c("0-4", "5-11", "12-19", "50+", "Unknown"))
  expect_equal(case_age_groups(NULL, c("65+", "18-64", "5-17", "0-4")), c("0-4", "5-17", "18-64", "65+"))
  expect_equal(case_age_groups(NULL, c(NA, "")), character(0))
})

test_that("a settings list sets the groups and their order", {
  expect_equal(case_age_groups(c("Unknown", "18+", "0-17"), c("0-17", "18+")), c("Unknown", "18+", "0-17"))
})

test_that("spaces around a group don't make it a different group", {
  expect_equal(case_age_groups(NULL, c(" 0-4 ", "0-4", "5-11 ")), c("0-4", "5-11"))
})

test_that("column headings add 'Years' only to plain number ranges", {
  expect_equal(
    age_group_labels(c("0-4", "50+", "7", "Unknown", "6 months", "1 year", "65 and older", "Under 5", "<1", "Pre-K")),
    c("0\u20134 Years", "50+ Years", "7 Years", "Unknown", "6 months", "1 year", "65 and older", "Under 5", "<1", "Pre-K")
  )
})

test_that("case tables show missing age groups as unknown when missing_records is unknown", {
  cases <- data.frame(
    county = "A", year = c(2020L, 2020L, 2021L), n_cases = c(2L, 1L, 4L),
    age_group = c("0-17", "18+", "0-17")
  )
  wide <- render_cases_gt(cases, "A", c("0-17", "18+", "Unknown"),
                         settings = list(case_data = list(missing_records = "unknown")))[["_data"]]
  expect_equal(names(wide), c("county", "year", "0-17", "18+", "Unknown"))
  expect_equal(wide$`18+`, c(1, NA))
  expect_true(all(is.na(wide$Unknown)))
  expect_equal(case_table_headings(cases, "A", c("0-17", "18+")), c("County", "Year", "0\u201317 Years", "18+ Years"))
})

test_that("cases without an age group get their own column", {
  cases <- data.frame(county = "A", year = 2020L, n_cases = c(2L, 3L), age_group = c("0-17", NA))
  wide <- render_cases_gt(cases, "A", c("0-17", "18+"),
                         settings = list(case_data = list(missing_records = "unknown")))[["_data"]]
  expect_equal(unname(unlist(wide[1, 3:5])), c(2, NA, 3))
  expect_equal(case_table_headings(cases, "A", c("0-17", "18+")), c("County", "Year", "0\u201317 Years", "18+ Years", "Age not given"))
  # no age groups at all: one "Cases" column
  cases_no_age <- data.frame(county = "A", year = 2020L, n_cases = 5L, age_group = NA_character_)
  expect_equal(unname(unlist(render_cases_gt(cases_no_age, "A", character(0))[["_data"]][1, 3])), 5)
  expect_equal(case_table_headings(cases_no_age, "A", character(0)), c("County", "Year", "Cases"))
})

test_that("a group named like the no-age column doesn't clash with it", {
  cases <- data.frame(county = "A", year = 2020L, n_cases = c(1L, 2L), age_group = c("Age not given", NA))
  wide <- render_cases_gt(cases, "A", "Age not given")[["_data"]]
  expect_equal(unname(unlist(wide[1, 3:4])), c(1, 2))
})

test_that("cases.csv groups not in the settings stop the loader, naming value and rows", {
  dir <- tempfile("example-data-")
  dir.create(dir)
  file.copy(list.files(example_data_dir("full"), full.names = TRUE), dir)
  path <- file.path(dir, "cases.csv")
  x <- utils::read.csv(path, colClasses = "character", na.strings = "")
  x$age_group[c(2, 5)] <- "5-9"
  utils::write.csv(x, path, row.names = FALSE, na = "")
  groups <- c("0-4", "5-11", "12-19", "20-49", "50+", "Unknown")
  msg <- tryCatch({
    load_app_data(dir, case_age_groups = groups)
    ""
  }, error = function(e) conditionMessage(e))
  expect_match(msg, "cases.csv: 2 row\\(s\\) have an age_group that isn't in the settings' case_age_groups: \"5-9\" \\(rows 3, 6;")
  # without a settings list, any group is fine
  expect_true("5-9" %in% load_app_data(dir)$cases$age_group)
  # spaces around a value are trimmed before the check
  x$age_group[c(2, 5)] <- " 0-4 "
  utils::write.csv(x, path, row.names = FALSE, na = "")
  d <- load_app_data(dir, case_age_groups = groups)
  expect_false(any(grepl("^ | $", d$cases$age_group[!is.na(d$cases$age_group)])))
})

test_that("bad case_age_groups settings are reported", {
  path <- tempfile(fileext = ".R")
  on.exit(unlink(path))
  writeLines("list(case_age_groups = c('0-4', '0-4'))", path)
  expect_error(read_dashboard_settings(path), "case_age_groups has to be NULL or the age groups as text, each once")
  writeLines("list(case_age_groups = character(0))", path)
  expect_error(read_dashboard_settings(path), "case_age_groups has to be NULL")
})
