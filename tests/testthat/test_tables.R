test_that("coverage tables show zeros, unknown rows and schools that didn't report", {
  schools <- data.frame(
    school_id = c("zero", "unknown", "unreported", "other"),
    school_name = c("Zero School", "Unknown School", "Unreported School", "Other School"),
    county_name = c("A", "A", "A", "B"), enroll = c(20, NA, 30, 40),
    full_vax_pct = c("0", NA, "90", "95"),
    reporting_status = c("reported", NA, "not_reported", "reported")
  )
  table <- build_coverage_table(schools = schools, selected_county = "A")
  expect_s3_class(table, "gt_tbl")
  data <- table[["_data"]]
  expect_setequal(data$name, c("Zero School", "Unknown School", "Unreported School"))
  expect_equal(data$full_vax_pct[data$name == "Zero School"], 0)
  expect_true(is.na(data$full_vax_pct[data$name == "Unknown School"]))
  expect_true(is.na(data$full_vax_pct[data$name == "Unreported School"]))
  expect_equal(data$total_enrollment[data$name == "Unreported School"], 30)
  html <- gt::as_raw_html(table)
  expect_match(html, "Unknown / withheld", fixed = TRUE)
  expect_match(html, "Unreported School", fixed = TRUE)
  expect_s3_class(build_coverage_table(schools = schools[0, ]), "gt_tbl")
})

test_that("child care tables handle unknown enrollment and suppressed coverage", {
  facilities <- data.frame(
    facility_name = c("Zero Care", "Suppressed Care", "Unknown Care", "Unreported Care"),
    county_name = "A", full_vax_pct = c("0", ">95", NA, "70"),
    reporting_status = c("reported", "reported", NA, "not_reported")
  )
  table <- build_coverage_table(facilities = facilities, table_type = "childcare", selected_county = "A")
  expect_s3_class(table, "gt_tbl")
  expect_setequal(table[["_data"]]$name, c("Zero Care", "Suppressed Care", "Unknown Care", "Unreported Care"))
  expect_true(is.na(table[["_data"]]$full_vax_pct[table[["_data"]]$name == "Unreported Care"]))
  expect_true(all(is.na(table[["_data"]]$total_enrollment)))
  html <- gt::as_raw_html(table)
  expect_match(html, "95", fixed = TRUE)
  expect_match(html, "Unknown / withheld", fixed = TRUE)
})

test_that("grade tables show one school, with grades in order from kindergarten", {
  grades <- data.frame(school_id = c("A", "A", "A", "B"),
    grade = c("2", "0", "1", "0"), full_vax_pct = c(NA, "0", ">95", "80"))
  table <- grade_level_table(grades, "A")
  expect_s3_class(table, "gt_tbl")
  data <- table[["_data"]]
  expect_equal(as.character(data$grade), c("K", "1", "2"))
  expect_equal(data$full_vax_display[1:2], c("0%", ">95%"))
  expect_false(any(data$full_vax_display == "80%"))
  expect_false(data$full_vax_display[3] %in% c("0", "0%"))
  html <- gt::as_raw_html(table)
  expect_false(grepl("Medical", html, fixed = TRUE))
  expect_s3_class(grade_level_table(grades[0, ], "A"), "gt_tbl")
})

test_that("proximity tables can be built without a Shiny session", {
  facilities <- data.frame(
    facility_name = c("Zero School", "Unknown Care", "Unreported School"),
    facility_type = c("School", "Daycare", "School"),
    full_vax_pct = c("0", NA, "50"), distance_mi = c(0, NA, 1),
    enrollment = c(0, NA, 30), reporting_status = c("reported", NA, "not_reported")
  )
  table <- build_proximity_table(facilities, searched = TRUE)
  expect_s3_class(table, "gt_tbl")
  data <- table[["_data"]]
  expect_equal(data[["School/Child Care Name"]], "Zero School")
  expect_equal(data[["Vaccine Rate"]], "0%")
  expect_equal(data[["Distance from Point"]], "0 mi")
  expect_s3_class(build_proximity_table(facilities, searched = TRUE, interactive = TRUE), "datatables")
  expect_s3_class(build_proximity_table(NULL, searched = FALSE), "gt_tbl")
  expect_s3_class(build_proximity_table(facilities[0, ], searched = TRUE), "gt_tbl")
})

test_that("facility overviews show zeros and tell a school from a child care with the same ID", {
  schools <- data.frame(school_id = "same", school_name = "Zero School", county_name = "A",
    enroll = 20, full_vax_pct = "0")
  facilities <- data.frame(facility_id = "same", facility_name = "Child Care", county_name = "A",
    enroll = 30, full_vax_pct = "80")
  school <- build_facility_overview_table("school:same", schools, facilities)
  care <- build_facility_overview_table("facility:same", schools, facilities)
  expect_s3_class(school, "gt_tbl")
  expect_s3_class(care, "gt_tbl")
  expect_true("0%" %in% school[["_data"]]$Value)
  expect_true("80%" %in% care[["_data"]]$Value)
  expect_false("80%" %in% school[["_data"]]$Value)
  expect_s3_class(build_facility_overview_table("absent", schools, facilities), "gt_tbl")
})
