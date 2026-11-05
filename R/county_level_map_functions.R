# ====================================================
# FUNCTIONS TO EXECUTE COUNTY LEVEL MAP MODULE
# ====================================================

# ==== County map colors ====
# Coverage cutoffs (%) and the color for each band on the county map.
COVERAGE_BINS <- c(0, 85, 90, 95, 100)
COVERAGE_COLORS <- c("red", "orange", "gold", "darkgreen")

# Builds the color palette for the county/district map.
# Used by app_server() and inst/reports/dashboard_report.Rmd.
county_palette <- function(domain) {
  colorBin(
    palette = COVERAGE_COLORS,
    bins = COVERAGE_BINS,
    domain = domain,
    na.color = "gray"
  )
}

# ==== Create main County/District map on dashboard tab ====

# Polygon layer ids on the county map: lower-case county names for
# counties, district_id for districts. countyMapServer() turns a clicked
# id back into a county name or district.
map_layer_ids <- function(map_data, boundary) {
  if (boundary == "county") tolower(map_data$county_name) else map_data$district_id
}

# Input:  map_data = counties or districts from the standard app data
#         (load_app_data.R); boundary = "county" or "district";
#         map_view = starting view (map_view.R), by default one that fits map_data
# Output: leaflet map shaded by coverage
# Used by countyMapServer() and inst/reports/dashboard_report.Rmd.
county_district_map_dashboard <- function(map_data, pal_county, boundary = c("county", "district"),
                                          map_view = map_view_from_counties(map_data)) {
  boundary <- match.arg(boundary)
  boundary_view <- if (boundary == "county") "County" else "District"

  # ----------- Layer ID, name, enrollment, and coverage for the selected boundary -------------

  map_data$layer_id <- map_layer_ids(map_data, boundary)
  map_data$name <- if (boundary == "county") map_data$county_name else map_data$district_name
  map_data$enrollment <- map_data$enroll
  # Coverage as a number (suppressed values like ">95" counted past their
  # number, see load_app_data()), for the colors and the label
  map_data$full_vax_pct <- map_data$full_vax_pct_num
  # ------------------------------------------------------------------------------------------

  # Check for demographic columns - can use this for step-down version of map
  has_soc <- "students_of_color_pct" %in% colnames(map_data)
  has_frl <- "frl_eligible_pct" %in% colnames(map_data)

  # Pre-construct HTML labels row-by-row before passing to leaflet
  map_data$map_label <- lapply(1:nrow(map_data), function(i) {
    row <- map_data[i, ]

    # Header label
    header <- if (boundary_view == "County"){
      paste(row$name, "County")
    }  else {
      row$name
    }

    # Enrollment text
    enroll_txt <- if (is.na(row$enrollment)) {
      "Data Not Available"
    } else {
      as.character(scales::comma(row$enrollment))
    }

    # Base HTML string
    label_str <- paste0(
      header, "<br>",
      "2-dose MMR Coverage (K–12): ", row$full_vax_pct, "%<br>",
      "Enrollment (K–12): ", enroll_txt
    )

    # Demographics are given as percentages (of the enrollment they were
    # counted against), so they're shown as they are
    pct_txt <- function(x) if (is.na(x)) "Data Not Available" else paste0(round(x, 1), "%")
    if (has_soc) {
      label_str <- paste0(label_str, "<br>Students of Color (K–12): ", pct_txt(row$students_of_color_pct))
    }
    if (has_frl) {
      label_str <- paste0(label_str, "<br>Free/Reduced Lunch Eligible (K–12): ", pct_txt(row$frl_eligible_pct))
    }

    htmltools::HTML(label_str)
  })

  # -----------------------------------------------------------------------------------------
  # ==== Constructing the Map ====

  map <-leaflet(map_data, options = leafletOptions(minZoom = 5, maxZoom = 9)) |>
    apply_map_view(map_view) |>
    addProviderTiles("Esri.WorldTopoMap") |>
    addPolygons(
      fillColor = ~ pal_county(full_vax_pct),
      fillOpacity = 0.7,
      color = "white",
      weight = 1,
      layerId = ~layer_id,
      label = ~map_label
    ) |>
    addLegend("bottomright",
              pal = pal_county,
              values = map_data$full_vax_pct,
              title = paste0(ifelse(boundary_view == "County","County", "District"), " MMR (%)"), opacity = 0.7
    )
  return(map)
}

# ==== Highlight selected county or district in orange ====

# Input:  map_data and boundary as for county_district_map_dashboard();
#         selected_id = a layer id from map_layer_ids()
highlight_selected <- function(map_data, selected_id, boundary = c("county", "district")) {
  boundary <- match.arg(boundary)
  selected_shape <- map_data[map_layer_ids(map_data, boundary) %in% selected_id, ]

  leafletProxy("county_map") %>%
    clearGroup("highlight") %>%
    addPolygons(
      data = selected_shape,
      fill = FALSE,
      color = "orange",
      weight = 4,
      opacity = 1,
      group = "highlight"
    )
}
