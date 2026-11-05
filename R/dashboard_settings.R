# ============================================================
# DASHBOARD SETTINGS
# ============================================================
# A settings file is an R script whose last value is a named list
# (see inst/config/measles_mn.R). read_dashboard_settings() reads one
# and fills in anything it leaves out from DEFAULT_SETTINGS, so a
# settings file only needs the parts that differ.
#
# Used by run_dashboard(); the result goes to app_ui() and app_server().
# ============================================================

# Neutral defaults for the settings that aren't required.
#   app$ga_id    Google Analytics ID; NULL adds no tracking
#   notes        footnotes about the data (NULL leaves a note out)
#     enrollment           note on how enrollment was counted; when set,
#                          enrollment labels get a "*"
#     nonreporting_school  shown for a school that didn't report coverage
#     nonreporting_table   source note under the school coverage tables
#   map          starting view for the maps, e.g.
#                list(center = c(lng, lat), zoom = 6,
#                     max_bounds = c(lng1, lat1, lng2, lat2));
#                NULL fits the maps to the county boundaries
DEFAULT_SETTINGS <- list(
  app = list(ga_id = NULL),
  notes = list(
    enrollment = NULL,
    nonreporting_school = "MMR vaccination coverage is unavailable for schools that did not report coverage data.",
    nonreporting_table = "Schools that did not report MMR vaccination coverage are not displayed."
  ),
  map = NULL
)

# Input:  path to a settings file
# Output: the settings list, with defaults filled in
read_dashboard_settings <- function(path) {
  settings <- source(path, local = new.env())$value
  if (!is.list(settings)) {
    stop("The settings file ", path, " must end with a list of settings.", call. = FALSE)
  }
  utils::modifyList(DEFAULT_SETTINGS, settings)
}
