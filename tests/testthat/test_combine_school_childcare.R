test_that("combines schools and daycares with standardized columns", {
  out <- combineSchoolDaycareData(make_schools(), make_daycares())
  expect_equal(nrow(out), 4)
  expect_equal(
    names(out),
    c("facility_name", "facility_type", "full_vax_pct", "partial_vax_pct",
      "enrollment", "contact_info", "geometry")
  )
  expect_equal(out$facility_type, c("School", "School", "Daycare", "Daycare"))
})

test_that("drops rows with missing or empty names", {
  schools <- make_schools()
  schools$school_name <- c(NA, "Roosevelt High")
  daycares <- make_daycares()
  daycares$daycare_name <- c("", "Sunshine Kids")
  out <- combineSchoolDaycareData(schools, daycares)
  expect_equal(out$facility_name, c("Roosevelt High", "Sunshine Kids"))
})

test_that("returns NULL when neither input has usable rows", {
  expect_null(combineSchoolDaycareData(NULL, NULL))
  expect_null(combineSchoolDaycareData(make_schools()[0, ], make_daycares()[0, ]))
})

test_that("daycares get N/A partial_vax_pct and empty contact_info", {
  out <- combineSchoolDaycareData(make_schools(), make_daycares())
  daycare_rows <- out[out$facility_type == "Daycare", ]
  expect_equal(daycare_rows$partial_vax_pct, c("N/A", "N/A"))
  expect_equal(daycare_rows$contact_info, c("", ""))
})

test_that("daycares alone get an empty contact_info column", {
  out <- combineSchoolDaycareData(NULL, make_daycares())
  expect_equal(out$facility_type, c("Daycare", "Daycare"))
  expect_equal(out$contact_info, c("", ""))
})

test_that("fills empty geometry when only one dataset has it", {
  daycares <- st_drop_geometry(make_daycares())
  out <- combineSchoolDaycareData(make_schools(), daycares)
  expect_equal(nrow(out), 4)
  expect_equal(st_is_empty(out$geometry), c(FALSE, FALSE, TRUE, TRUE))
  expect_true(st_crs(out$geometry) == st_crs(4326))
})