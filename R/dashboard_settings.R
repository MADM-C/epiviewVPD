# ============================================================
# DASHBOARD SETTINGS
# ============================================================
# A settings file is an R script whose last value is a named list
# (see inst/config/template.R and inst/config/measles_mn.R).
# read_dashboard_settings() reads one, fills in anything it leaves out
# from the template, and checks the values, so a settings file only
# needs the parts that differ from the template.
#
#   - left out: the template's value is used. Named lists (app, notes,
#     labels, ...) are filled in item by item; lists without names (faq,
#     case_studies, ...) and vectors (definitions, data_notes) replace
#     the template's as a whole.
#   - set to NULL: the item is hidden (for `map`, the maps fit the county
#     boundaries; for `suppression`, the data have exact numbers)
#
# Used by run_dashboard(); the result goes to app_ui() and app_server().
# ============================================================

# Input:  none
# Output: the template's settings (inst/config/template.R), the defaults
#         for every setting. Also used as default arguments by the
#         modules that show the notes.
default_settings <- function() {
  template <- system.file("config", "template.R", package = "epiviewVPD")
  source(template, local = new.env())$value
}

# Input:  path to a settings file
# Output: the settings list, with the template's values filled in for
#         anything it leaves out; stops with one message listing every
#         problem in the settings
read_dashboard_settings <- function(path) {
  settings <- source(path, local = new.env())$value
  if (!is.list(settings)) {
    stop("The settings file ", path, " must end with a list of settings.", call. = FALSE)
  }
  defaults <- default_settings()
  warn_unknown_settings(settings, defaults, path)
  settings <- merge_settings(defaults, settings)
  check_settings(settings, path)
}

# Names a settings file may use besides the template's own (see the
# template's comments): map, notes$enrollment
OPTIONAL_SETTINGS <- c("map", "notes$enrollment")

# Input:  settings as written in the file, the template's settings, and
#         the file's path (for the message)
# Output: none; warns about names the dashboard doesn't know (usually a
#         misspelling), which would otherwise be ignored silently
warn_unknown_settings <- function(settings, defaults, path) {
  known <- c(names(defaults), OPTIONAL_SETTINGS)
  for (name in names(defaults)) {
    if (is_named_list(defaults[[name]])) known <- c(known, paste0(name, "$", names(defaults[[name]])))
  }
  given <- names(settings)
  for (name in names(settings)) {
    if (is_named_list(settings[[name]]) && is_named_list(defaults[[name]])) {
      given <- c(given, paste0(name, "$", names(settings[[name]])))
    }
  }
  unknown <- setdiff(given, known)
  if (length(unknown) > 0) {
    warning("The settings file ", path, " has settings the dashboard doesn't know ",
            "(misspelled?); they are ignored: ", paste(unknown, collapse = ", "), call. = FALSE)
  }
}

# Input:  defaults and settings (lists)
# Output: the defaults, with every item the settings give replaced. Named
#         lists (such as `app` or `notes`) are merged item by item; any
#         other value (a vector, or an unnamed list such as `faq`)
#         replaces the default as a whole. An item set to NULL is removed.
merge_settings <- function(defaults, settings) {
  for (name in names(settings)) {
    value <- settings[[name]]
    if (is.null(value)) {
      defaults[name] <- NULL
    } else if (is_named_list(value) && is_named_list(defaults[[name]])) {
      defaults[[name]] <- merge_settings(defaults[[name]], value)
    } else {
      defaults[[name]] <- value
    }
  }
  defaults
}

# TRUE for a non-empty list whose items all have names
is_named_list <- function(x) {
  is.list(x) && length(x) > 0 && !is.null(names(x)) && all(names(x) != "")
}

# Input:  merged settings and the settings file's path (for the message)
# Output: the settings, with `map$center` put in (lng, lat) order; stops
#         with one message listing every problem
check_settings <- function(settings, path) {
  problems <- character(0)
  is_number <- function(x, n = 1) is.numeric(x) && length(x) == n && !anyNA(x)

  # These have to be lists, e.g. case_years = list(min = 2010, ...)
  not_list <- character(0)
  for (name in c("case_years", "proximity", "map", "suppression")) {
    if (!is.null(settings[[name]]) && !is.list(settings[[name]])) {
      problems <- c(problems, paste0(name, " has to be a list, e.g. ", name, " = list(...) as in the template"))
      settings[[name]] <- NULL
      not_list <- c(not_list, name)
    }
  }

  # How withheld values appear in the data; NULL means exact numbers
  # (nothing withheld, no blurred values counted past their number)
  if (is.null(settings$suppression$blurred_offset)) settings$suppression$blurred_offset <- 0
  if (is.null(settings$suppression$redacted_codes)) settings$suppression$redacted_codes <- character(0)
  offset <- settings$suppression$blurred_offset
  if (!is_number(offset) || offset < 0) {
    problems <- c(problems, "suppression$blurred_offset has to be one number, 0 or more (e.g. 1)")
  }
  if (!is.character(settings$suppression$redacted_codes)) {
    problems <- c(problems, "suppression$redacted_codes has to be text, e.g. c(\"*\", \"S\")")
  }

  # Years on the historical cases slider
  years <- settings$case_years
  if ("case_years" %in% not_list) {
    # already reported above
  } else if (!is_number(years$min) || !is_number(years$max) || !is_number(years$selected, 2)) {
    problems <- c(problems, "case_years needs min and max (one year each) and selected (two years), e.g. list(min = 2010, max = 2025, selected = c(2015, 2020))")
  } else if (years$min > years$max || any(years$selected < years$min | years$selected > years$max)) {
    problems <- c(problems, "case_years$selected has to be between case_years$min and case_years$max")
  }

  # Proximity tool's starting coverage threshold (percent)
  threshold <- settings$proximity$default_threshold
  if (!"proximity" %in% not_list && (!is_number(threshold) || threshold < 0 || threshold > 100)) {
    problems <- c(problems, "proximity$default_threshold has to be one number from 0 to 100")
  }

  # Starting view for the maps
  map <- settings$map
  if (!is.null(map)) {
    unknown <- setdiff(names(map), c("center", "zoom", "max_bounds"))
    if (length(unknown) > 0) {
      problems <- c(problems, paste0("map has unknown entries: ", paste(unknown, collapse = ", "),
                                     " (it can have center, zoom and max_bounds)"))
    }
    if (!is.null(map$center) || !is.null(map$zoom)) {
      if (!is_number(map$center, 2) || !is_number(map$zoom)) {
        problems <- c(problems, "map$center (longitude and latitude) and map$zoom go together, e.g. center = c(lng = -98.6, lat = 39.8), zoom = 6")
      } else {
        settings$map$center <- center_lng_lat(map$center)
        if (abs(settings$map$center[2]) > 90 || abs(settings$map$center[1]) > 180) {
          problems <- c(problems, "map$center has to be longitude (-180 to 180) then latitude (-90 to 90); name them to be sure: c(lng = ..., lat = ...)")
        }
      }
    }
    if (!is.null(map$max_bounds) && !is_number(map$max_bounds, 4)) {
      problems <- c(problems, "map$max_bounds has to be four numbers: c(west longitude, south latitude, east longitude, north latitude)")
    }
  }

  if (length(problems) > 0) {
    stop("Problems in the settings file ", path, ":\n",
         paste0("  - ", problems, collapse = "\n"), call. = FALSE)
  }
  settings
}

# Input:  map center as two numbers, either unnamed (longitude first) or
#         named lng/lon/longitude and lat/latitude, in any order
# Output: unnamed c(longitude, latitude)
center_lng_lat <- function(center) {
  nms <- tolower(names(center))
  lng <- which(nms %in% c("lng", "lon", "longitude"))
  lat <- which(nms %in% c("lat", "latitude"))
  if (length(lng) == 1 && length(lat) == 1) center <- c(center[[lng]], center[[lat]])
  unname(center)
}
