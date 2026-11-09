# ============================================================
# EXAMPLE DATA
# ============================================================

#' Folder of example data
#'
#' Returns the path to the made-up example data that comes with the
#' package. The files are in the same format [run_dashboard()] reads from
#' `data_dir`, so the dashboard can be tried out, or tested, without real
#' data. Everything in it is invented, including the state itself.
#'
#' @param type `"basic"` for the files the basic dashboard needs (counties,
#'   schools, cases and county boundaries, with only the required columns),
#'   or `"full"` for every file the package can use.
#' @return Path to the example data folder.
#' @export
#' @examples
#' example_data_dir()
#' \dontrun{
#' run_dashboard(data_dir = example_data_dir())
#' }
example_data_dir <- function(type = c("basic", "full")) {
  type <- match.arg(type)
  folder <- if (type == "basic") "example-basic" else "example"
  system.file("extdata", folder, package = "epiviewVPD", mustWork = TRUE)
}
