copy_example <- function() {
  dir <- tempfile("example-data-")
  dir.create(dir)
  file.copy(list.files(example_data_dir("full"), full.names = TRUE), dir)
  dir
}

edit_csv <- function(dir, file, fn) {
  path <- file.path(dir, file)
  x <- utils::read.csv(path, colClasses = "character", check.names = FALSE, na.strings = "")
  utils::write.csv(fn(x), path, row.names = FALSE, na = "")
}

load_error <- function(dir, ...) {
  tryCatch({
    load_app_data(dir, ...)
    ""
  }, error = function(e) conditionMessage(e))
}

only_features <- function(...) {
  features <- default_features()
  features[] <- FALSE
  features[c(...)] <- TRUE
  features
}

feature_data_dir <- function(files, without_coordinates = FALSE) {
  dir <- tempfile("feature-data-")
  dir.create(dir)
  if (length(files)) {
    copied <- file.copy(file.path(example_data_dir("full"), files), dir)
    stopifnot(all(copied))
  }
  if (without_coordinates) {
    for (file in intersect(files, c("schools.csv", "facilities.csv"))) {
      edit_csv(dir, file, function(x) {
        x$latitude <- NULL
        x$longitude <- NULL
        x
      })
    }
  }
  dir
}
