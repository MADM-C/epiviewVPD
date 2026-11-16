# ====================================================
# Helper Functions for Grade Details Module
# ====================================================

# ============================================================
# HELPER: parse a vax percentage string to a numeric value, for bar
# lengths. A blurred value (">95", "<5") is drawn at its number; "87.3"
# and "87.3%" give 87.3. Returns NA for redacted / unparseable values.
# ============================================================

parse_vax_num <- function(x) {
  suppressWarnings(as.numeric(sub("%$", "", trimws(sub("^\\s*[<>]", "", x)))))
}

# ============================================================
# HELPER: derive a bar fill color from a coverage value. Blurred values
# are colored by the number they count as (pct_number(), load_app_data.R),
# so ">95" counts as 96 (green) and ">80" as 81 (red).
# ============================================================
# bands = coverage color bands (coverage_bands.R).
coverage_color <- function(value_raw, value_num, bands = coverage_bands()) {
  value_num <- ifelse(grepl("^\\s*[<>]", value_raw), pct_number(value_raw, bands$blurred_offset), value_num)
  coverage_band_color(value_num, bands)
}
