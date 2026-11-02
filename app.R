# Development entry point: RStudio's "Run App" button and
# shiny::runApp() use this file to start the dashboard from the
# source code in R/, without installing the package.
# Expects the data files in "App Data/".
pkgload::load_all(".", export_all = FALSE, helpers = FALSE, quiet = TRUE)
run_dashboard(data_dir = "App Data")
