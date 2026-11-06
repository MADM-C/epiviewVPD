# ============================================================
# COVERAGE COLOR BANDS
# ============================================================
# The coverage cutoffs and colors used everywhere coverage is colored:
# the county/district map, the school and child care dots, the grade
# bars, the summary tables, both reports, and the legends and color key.
#
# Settings `coverage_bins` (inst/config/template.R): one entry per band,
# lowest first.
#   min         lowest coverage (%) in the band; the first band starts at 0
#   background  the band's color
#   color       text color on the band's badge in the color key
#               (optional, default black)
#   label       legend text (optional; written from the cutoffs when left
#               out, e.g. "Below 85%", "85% to <90%", "95% and above")
# Left out of a state's settings file, the template's bands are used
# (default_settings(), dashboard_settings.R).
#
# A blurred value (">95", "<5") is colored by the number it counts as:
# its number plus or minus settings suppression$blurred_offset
# (pct_number(), load_app_data.R).
# ============================================================

# Color for missing, redacted or unreadable coverage
MISSING_COVERAGE_COLOR <- "gray"

# Input:  bins = settings coverage_bins, NULL for the template's;
#         blurred_offset = settings suppression$blurred_offset;
#         a result of coverage_bands() is returned as is
# Output: list of class "coverage_bands": min, background, color and
#         label (one value per band, lowest first) and blurred_offset
# Used by app_ui(), app_server(), check_settings() and both reports
# (inst/reports).
coverage_bands <- function(bins = NULL, blurred_offset = 1) {
  if (inherits(bins, "coverage_bands")) return(bins)
  if (is.null(bins)) bins <- default_settings()$coverage_bins

  problem <- function(...) {
    stop("Settings coverage_bins: ", ..., call. = FALSE)
  }
  if (!is.list(bins) || length(bins) == 0 || !all(vapply(bins, is.list, logical(1)))) {
    problem("must be a list of bands, each a list(min = , background = ).")
  }
  # One value per band and field; NA where a band leaves the field out
  field <- function(name, type = "character") {
    vapply(seq_along(bins), function(i) {
      v <- bins[[i]][[name]]
      if (is.null(v)) return(if (type == "number") NA_real_ else NA_character_)
      ok <- length(v) == 1 && !is.na(v) &&
        (if (type == "number") is.numeric(v) else is.character(v))
      if (!ok) {
        problem(name, " in band ", i, " has to be one ",
                if (type == "number") "number, e.g. min = 90" else "text value, e.g. \"red\"", ".")
      }
      if (type == "number") as.numeric(v) else v
    }, if (type == "number") numeric(1) else character(1))
  }
  # Colors R and the browser can use: names such as "red" or "#C62828"
  check_colors <- function(x, name) {
    for (i in which(!is.na(x))) {
      ok <- tryCatch({ grDevices::col2rgb(x[i]); TRUE }, error = function(e) FALSE)
      if (!ok) problem(name, " in band ", i, " isn't a color: \"", x[i], "\" (use a name such as \"red\" or a code such as \"#C62828\").")
    }
  }

  min <- field("min", "number")
  background <- field("background")
  color <- field("color")
  if (anyNA(min)) problem("every band needs a number for min (band ", which(is.na(min))[1], ").")
  if (anyNA(background)) problem("every band needs a background color (band ", which(is.na(background))[1], ").")
  check_colors(background, "background")
  check_colors(color, "color")
  color[is.na(color)] <- "#000"
  if (min[1] != 0) problem("the first band must start at min = 0.")
  if (any(diff(min) <= 0)) problem("min must go up from one band to the next.")
  if (any(min > 100)) problem("min can't be above 100.")

  label <- field("label")
  label[is.na(label)] <- coverage_band_labels(min)[is.na(label)]

  structure(
    list(
      min = min,
      background = background,
      color = color,
      label = label,
      blurred_offset = blurred_offset
    ),
    class = "coverage_bands"
  )
}

# Legend text written from the cutoffs: "Below 85%", "85% to <90%",
# "95% and above"
coverage_band_labels <- function(min) {
  n <- length(min)
  pct <- paste0(vapply(min, format, character(1), scientific = FALSE, drop0trailing = TRUE), "%")
  if (n == 1) return("All values")
  c(
    paste("Below", pct[2]),
    if (n > 2) paste0(pct[2:(n - 1)], " to <", pct[3:n]),
    paste(pct[n], "and above")
  )
}

# Input:  value = coverage numbers (%); bands from coverage_bands()
# Output: one color per value; MISSING_COVERAGE_COLOR for NA or below 0
coverage_band_color <- function(value, bands = coverage_bands()) {
  value <- suppressWarnings(as.numeric(value))
  band <- findInterval(value, bands$min)
  out <- rep(MISSING_COVERAGE_COLOR, length(value))
  ok <- !is.na(value) & band > 0
  out[ok] <- bands$background[band[ok]]
  out
}

# Adds the coverage legend to a leaflet map.
# Input:  map; bands from coverage_bands(); title; missing_label = text for
#         the gray "no data" entry, NULL leaves it out
# Used by county_district_map_dashboard() and subMapServer().
add_coverage_legend <- function(map, bands, title, missing_label = NULL, opacity = 0.9) {
  colors <- bands$background
  labels <- htmltools::htmlEscape(bands$label)
  if (!is.null(missing_label)) {
    colors <- c(colors, MISSING_COVERAGE_COLOR)
    labels <- c(labels, missing_label)
  }
  leaflet::addLegend(map, "bottomright", colors = colors, labels = labels,
                     title = title, opacity = opacity)
}
