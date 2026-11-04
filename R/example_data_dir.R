# ============================================================
# EXAMPLE DATA
# ============================================================

#' Folder of example data
#'
#' Returns the path to the made-up example data that comes with the
#' package (inst/extdata/example). The files are in the same format
#' [run_dashboard()] reads from `data_dir`, so the dashboard can be
#' tried out, or tested, without real data. Everything in it is
#' invented, including the state itself: its counties, school districts,
#' boundaries, schools, child cares, healthcare centers and numbers.
#'
#' @return Path to the example data folder.
#' @export
#' @examples
#' example_data_dir()
#' \dontrun{
#' run_dashboard(data_dir = example_data_dir())
#' }
example_data_dir <- function() {
  system.file("extdata", "example", package = "epiviewVPD", mustWork = TRUE)
}
