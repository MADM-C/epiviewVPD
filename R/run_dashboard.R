# ============================================================
# RUN THE DASHBOARD
# ============================================================

#' Run the dashboard
#'
#' Loads the dashboard's data and settings and starts the Shiny app.
#'
#' @param data_dir Folder that holds the dashboard's data files.
#' @param config Settings file: wording, links, logos, case studies,
#'   footnotes and map view. Defaults to the neutral template that comes
#'   with the package (`system.file("config", "template.R", package =
#'   "epiviewVPD")`), which names no state or organization; copy and edit
#'   it to make your own. Logo and case study files it names are looked
#'   for next to the settings file. The Minnesota settings are a filled-in
#'   example: `system.file("config", "measles_mn.R", package = "epiviewVPD")`.
#' @param ... Passed on to [shiny::shinyApp()] as `options`, such as
#'   `port` or `launch.browser`.
#'
#' @return A Shiny app object. Calling `run_dashboard()` in the
#'   console launches the dashboard. To deploy, make it the last line
#'   of an `app.R` file.
#' @export
#' @examples
#' \dontrun{
#' run_dashboard(data_dir = "app_data", config = "my_settings.R")
#' }
run_dashboard <- function(data_dir = "app_data",
                          config = system.file("config", "template.R", package = "epiviewVPD"),
                          ...) {
  if (!file.exists(config)) {
    stop("The settings file \"", config, "\" doesn't exist.", call. = FALSE)
  }
  shiny::addResourcePath("epiview-assets", system.file("app", "www", package = "epiviewVPD"))
  dashboard_config <- read_dashboard_settings(config) |>
    prepare_settings_files(dirname(normalizePath(config)))
  app_data <- load_app_data(
    data_dir,
    suppressed_offset = dashboard_config$suppression$blurred_offset,
    redacted_codes = dashboard_config$suppression$redacted_codes,
    geography = dashboard_config$geography,
    case_age_groups = dashboard_config$case_age_groups,
    features = dashboard_config$features,
    case_data = dashboard_config$case_data
  )

  shiny::shinyApp(
    ui = app_ui(dashboard_config, app_data),
    server = app_server(app_data, dashboard_config),
    options = list(...)
  )
}
