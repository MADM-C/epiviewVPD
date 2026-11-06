# Coverage cutoffs and colors from the settings (R/coverage_bands.R)

test_that("default bands match the original 85/90/95 cutoffs", {
  bands <- coverage_bands()
  expect_equal(bands$min, c(0, 85, 90, 95))
  expect_equal(bands$label, c("Below 85%", "85% to <90%", "90% to <95%", "95% and above"))
  expect_equal(
    coverage_band_color(c(0, 84.9, 85, 89.9, 90, 94.9, 95, 100, NA, -1), bands),
    c("red", "red", "orange", "orange", "gold", "gold", "darkgreen", "darkgreen", "gray", "gray")
  )
})

test_that("changing the cutoffs changes the colors and the legend text", {
  bands <- coverage_bands(list(
    list(min = 0, background = "purple"),
    list(min = 92.5, background = "blue", label = "Close to the goal"),
    list(min = 97, background = "green")
  ))
  expect_equal(bands$label, c("Below 92.5%", "Close to the goal", "97% and above"))
  expect_equal(coverage_band_labels(c(0, 0.001, 100)), c("Below 0.001%", "0.001% to <100%", "100% and above"))
  expect_equal(bands$color, rep("#000", 3))
  expect_equal(coverage_band_color(c(92, 92.5, 96.9, 97), bands), c("purple", "blue", "blue", "green"))
  # every place that colors coverage uses the same bands
  expect_equal(mmr_colors(c(92, 99), c("92", ">96"), bands), c("purple", "green"))
  expect_equal(coverage_color(c("92", ">96"), c(92, NA), bands), c("purple", "green"))
})

test_that("the settings file's bands are kept, not replaced by defaults", {
  path <- tempfile(fileext = ".R")
  on.exit(unlink(path))
  writeLines("list(coverage_bins = list(list(min = 0, background = 'black'), list(min = 50, background = 'white')))", path)
  settings <- read_dashboard_settings(path)
  expect_equal(coverage_bands(settings$coverage_bins)$min, c(0, 50))
})

test_that("blurred values are colored by the settings' blurred_offset", {
  bins <- list(list(min = 0, background = "red"), list(min = 95, background = "green"))
  # ">94" counts as 95 with offset 1, as 94 with offset 0
  expect_equal(mmr_colors(NA, ">94", coverage_bands(bins, blurred_offset = 1)), "green")
  expect_equal(mmr_colors(NA, ">94", coverage_bands(bins, blurred_offset = 0)), "red")
  expect_equal(coverage_color(">94", NA, coverage_bands(bins, blurred_offset = 0)), "red")
})

test_that("bad bands in a settings file are reported with the other problems", {
  path <- tempfile(fileext = ".R")
  on.exit(unlink(path))
  writeLines("list(coverage_bins = list(list(min = 10, background = 'red')))", path)
  expect_error(read_dashboard_settings(path), "coverage_bins: the first band must start at min = 0")
})

test_that("malformed bands stop with a clear message", {
  expect_error(coverage_bands(list(list(min = 5, background = "red"))), "start at min = 0")
  expect_error(coverage_bands(list(list(min = 0, background = "red"), list(min = 0, background = "blue"))), "go up")
  expect_error(coverage_bands(list(list(min = 0), list(min = 90, background = "blue"))), "background color")
  expect_error(coverage_bands(list(list(min = "x", background = "red"))), "min in band 1 has to be one number")
  expect_error(coverage_bands(list(min = 0, background = "red")), "list of bands")
  expect_error(coverage_bands(list(list(min = 0, background = "redd"))), "background in band 1 isn't a color")
  expect_error(coverage_bands(list(list(min = 0, background = "red", color = "whyte"))), "color in band 1 isn't a color")
  expect_error(coverage_bands(list(list(min = 0, background = c("red", "blue")))), "background in band 1 has to be one")
  expect_error(coverage_bands(list(list(min = 0, background = "red"), list(min = "90", background = "blue"))), "min in band 2 has to be one number")
  expect_equal(coverage_bands(list(list(min = 0, background = "#C62828")))$background, "#C62828")
})
