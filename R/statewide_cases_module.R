# ============================================================
# STATEWIDE HISTORICAL MEASLES CASES
# ============================================================
#
# This map is shown when the user selects "Historical Measles
# Cases" in the dashboard. It displays Minnesota counties with
# circle markers representing the number of reported measles
# cases within the selected year range and age group.
#
# Circle sizes scale with case counts, allowing quick visual
# comparison across counties.
# ============================================================

StatewideCasesServer <- function(input, output, session, measles_cases, mn_counties) {

output$statewide_map <- renderLeaflet({
  # ---- filter cases ----
  filtered_cases <- measles_cases |>
    dplyr::filter(
      year >= input$year_range[1],
      year <= input$year_range[2],
      dplyr::case_when(
        input$case_age_group == "All Ages" ~ TRUE,
        TRUE ~ age_group == input$case_age_group
      )
    ) |>
    dplyr::group_by(county) |>
    dplyr::summarise(
      n_cases = sum(n_cases, na.rm = TRUE),
      .groups = "drop"
    ) |>
    dplyr::left_join(
      mn_counties,
      by = c("county" = "county_lower")
    ) |>
    sf::st_as_sf() |>
    dplyr::mutate(
      centroid = sf::st_centroid(geometry)
    ) |>
    sf::st_set_geometry("centroid")
  
  # ---- build map ----
  map <- leaflet(
    mn_counties,
    options = leafletOptions(minZoom = 5, maxZoom = 9)
  ) |>
    setView(lng = -94.5, lat = 46.5, zoom = 6) |>
    setMaxBounds(-105, 40, -84, 52) |>
    addProviderTiles("Esri.WorldTopoMap") |>
    # county boundaries
    addPolygons(
      fillColor = "#f5f5f5",
      fillOpacity = 0.3,
      color = "#bdbdbd",
      weight = 1,
      label = ~county_name,
      labelOptions = labelOptions(
        direction = "auto",
        textsize = "13px",
        opacity = 0.9
      )
    )
  
  # ---- add case circles safely ----
  if (nrow(filtered_cases) > 0) {
    map <- map |>
      addCircleMarkers(
        data = filtered_cases,
        radius = ~ pmin(10, sqrt(n_cases) * 2),
        fillColor = "purple",
        color = "black",
        stroke = TRUE,
        fillOpacity = 0.85,
        popup = ~ paste0(
          "County: ", county_name,
          "<br>Cases: ", n_cases
        ),
        label = ~ paste0(
          county_name,
          " County: ",
          n_cases,
          " case",
          ifelse(n_cases == 1, "", "s")
        )
      ) |>
      # ===== OLD CLEAN LEGEND =====
    addControl(
      html = HTML("
<div style='padding:6px 8px;
            background:rgba(255,255,255,0.85);
            border:1px solid #aaa;
            border-radius:4px;
            box-shadow:0 1px 4px rgba(0,0,0,0.2);
            font-size:12px;
            max-width:170px;'>

  <b style='font-size:13px;'>Measles Cases</b><br>

  <svg width='150' height='90'>
    <circle cx='10' cy='10' r='2' fill='purple' stroke='black'></circle>
    <text x='25' y='14'>1 case</text>

    <circle cx='10' cy='30' r='4' fill='purple' stroke='black'></circle>
    <text x='25' y='34'>~4 cases</text>

    <circle cx='10' cy='50' r='7' fill='purple' stroke='black'></circle>
    <text x='25' y='54'>~12 cases</text>

    <circle cx='10' cy='70' r='10' fill='purple' stroke='black'></circle>
    <text x='25' y='74'>30+ cases</text>
  </svg>

</div>
"),
      position = "topright"
    )
  }
  
  map
  })
}