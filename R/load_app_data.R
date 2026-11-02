# ============================================================
# DATA INITIALIZATION
# ============================================================
# load_app_data() loads every data file in data_dir and returns
# the objects as a named list. run_dashboard() passes this list
# to app_server().
#
# Data Sources Loaded:
# • County-level vaccination coverage
# • School vaccination data
# • Child care vaccination data
# • Grade-level vaccination data
# • School district boundaries and coverage
# • Healthcare center locations (used in proximity analysis)
# ============================================================

load_app_data <- function(data_dir = "App Data") {
  app_data <- new.env()

  load(file.path(data_dir, "county_vaccine_data.RData"), envir = app_data)

  load(file.path(data_dir, "daycare_vaccine_data.RData"), envir = app_data)

  load(file.path(data_dir, "grade_level_vaccine_data.RData"), envir = app_data)

  load(file.path(data_dir, "school_vaccine_data.RData"), envir = app_data)

  load(file.path(data_dir, "district_vaccine_data.RData"), envir = app_data)

  app_data$healthcare_center_data <- readRDS(file.path(data_dir, "mn_healthcare_centers.rds"))

  as.list(app_data)
}
