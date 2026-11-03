# ============================================================
# RUN THE DASHBOARD
# ============================================================

#' Run the dashboard
#'
#' Loads the dashboard's data and settings and starts the Shiny app.
#'
#' @param data_dir Folder that holds the dashboard's data files.
#' @param config Settings file: wording, links, logos and other
#'   text shown in the dashboard. Defaults to the Minnesota measles
#'   settings that come with the package.
#' @param ... Passed on to [shiny::shinyApp()] as `options`, such as
#'   `port` or `launch.browser`.
#'
#' @return A Shiny app object. Calling `run_dashboard()` in the
#'   console launches the dashboard. To deploy, make it the last line
#'   of an `app.R` file.
#' @export
#' @examples
#' \dontrun{
#' run_dashboard(data_dir = "App Data")
#' }
run_dashboard <- function(data_dir = "App Data",
                          config = system.file("config", "measles_mn.R", package = "epiviewVPD"),
                          ...) {
  dashboard_config <- source(config, local = new.env())$value
  app_data <- load_app_data(data_dir)

  shiny::addResourcePath("epiview-assets", system.file("app", "www", package = "epiviewVPD"))

  shiny::shinyApp(
    ui = app_ui(dashboard_config),
    server = app_server(app_data),
    options = list(...)
  )
}
