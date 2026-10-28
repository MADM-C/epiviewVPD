# ============================================================
# PACKAGE AND DATA INITIALIZATION
# ============================================================
# This script loads all required R packages and data objects
# used throughout the dashboard. It is sourced at the start of
# the application to ensure that dependencies, datasets, and
# shared objects (e.g., color palettes) are available to both
# the UI and server components.
#
# Data Sources Loaded:
# • County-level vaccination coverage
# • School vaccination data
# • Child care vaccination data
# • Grade-level vaccination data
# • Religious and tutoring center locations (used in proximity analysis)
#
# Shared Objects Created:
# • pal_county – color palette used to display county-level
#   MMR vaccination coverage on maps.
# ============================================================

# ==== SETTINGS: change these for your state / disease ====
DATA_DIR <- "App Data"
COVERAGE_BINS <- c(0, 85, 90, 95, 100)
COVERAGE_COLORS <- c("red", "orange", "gold", "darkgreen")

if (!require("pacman")) install.packages("pacman")
library(pacman)
p_load(
  "renv", "shiny", "leaflet", "dplyr", "sf", "readr", "stringr", "readxl", "gt",
  "ggplot2", "DT", "tidygeocoder", "rlang", "maps", "tidyr", "scales", "htmltools"
)

load("App Data/county_vaccine_data.RData")

load("App Data/daycare_vaccine_data.RData")

load("App Data/grade_level_vaccine_data.RData")

load("App Data/school_vaccine_data.RData")

load("App Data/district_vaccine_data.RData")

healthcare_center_data <- readRDS("App Data/mn_healthcare_centers.rds")


# ==== Color Palette ====
pal_county <- colorBin(
  palette = COVERAGE_COLORS,
  bins = COVERAGE_BINS,
  domain = county_map_data$full_vax_pct,
  na.color = "gray"
)
