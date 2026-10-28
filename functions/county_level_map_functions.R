# ====================================================
# FUNCTIONS TO EXECUTE COUNTY LEVEL MAP MODULE
# ====================================================

# ==== Create main County/District map on dashboard tab ====

county_district_map_dashboard <- function(map_data) {
  
  # pull name of data set to determine if county or district
  map_data_name <- deparse(substitute(map_data))
  
  # assign the boundary view
  if (str_detect(map_data_name, regex("county", ignore_case = TRUE))) {
    boundary_view <- "County"
  } else {
    boundary_view <- "District"
  }

  # ----------- MN SPECIFIC THINGS THAT SHOULD BE STANDARDIZED IN DATA PIPELINE -------------
  # Need to designate the district layer id (county or district ID)
  # Right now, MN uses county_lower as the layer id - we should consider switching to the FIPS code

  # MN-specific code to define a layer_id variable

  if (boundary_view == "County"){
    
    map_data$layer_id <- map_data$county_lower
    map_data$name <- map_data$county_name
    map_data$enrollment <- map_data$total_enrollment
    map_data$full_vax_pct <- map_data$full_vax_pct
    
  } else {
    
    map_data$layer_id <- map_data$join_key
    map_data$name <- map_data$PREFNAME
    map_data$enrollment <- map_data$enroll
    map_data$full_vax_pct <- map_data$full_vax_pct_num
    
  }
  # ------------------------------------------------------------------------------------------
  
  # Check for demographic columns - can use this for step-down version of map
  has_soc <- "students_of_color" %in% colnames(map_data)
  has_frl <- "frl_eligible" %in% colnames(map_data)
  
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
    
    # Append Students of Color if present
    if (has_soc) {
      soc_txt <- if (is.na(row$students_of_color) || is.na(row$enrollment) || row$enrollment == 0) {
        "Data Not Available"
      } else {
        paste0(scales::comma(row$students_of_color), " (", round(100 * row$students_of_color / row$enrollment, 1), "%)")
      }
      label_str <- paste0(label_str, "<br>Students of Color (K–12): ", soc_txt)
    }
    
    # Append Free/Reduced Lunch if present
    if (has_frl) {
      frl_txt <- if (is.na(row$frl_eligible) || is.na(row$enrollment) || row$enrollment == 0) {
        "Data Not Available"
      } else {
        paste0(scales::comma(row$frl_eligible), " (", round(100 * row$frl_eligible / row$enrollment, 1), "%)")
      }
      label_str <- paste0(label_str, "<br>Free/Reduced Lunch Eligible (K–12): ", frl_txt)
    }
    
    htmltools::HTML(label_str)
  })

  # -----------------------------------------------------------------------------------------
  # ==== Constructing the Map ====

  # define view coordinates for leaflet map ----

  state_map <- maps::map("state", region = target_state, plot = FALSE)
  center_lng <- mean(state_map$x, na.rm = TRUE)
  center_lat <- mean(state_map$y, na.rm = TRUE)

  map <- leaflet(map_data, options = leafletOptions(minZoom = 5, maxZoom = 9)) |>
    setView(lng = -94.5, lat = 46.5, zoom = 6) |>
    setMaxBounds(-105, 40, -84, 52) |>
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

highlight_selected <- function(map_data, selected_lower) {
  
  # pull name of data set to determine if county or district
  map_data_name <- deparse(substitute(map_data))
  
  # assign the boundary view
  if (str_detect(map_data_name, regex("county", ignore_case = TRUE))) {
    boundary_view <- "County"
  } else {
    boundary_view <- "District"
  }
  
  # ----------- MN SPECIFIC THINGS THAT SHOULD BE STANDARDIZED IN DATA PIPELINE -------------
  
  if (boundary_view == "County") {
    map_data$layer_id <- map_data$county_lower
  } else {
    map_data$layer_id <- map_data$join_key
  }
  # -----------------------------------------------------------------------------------------
  
  selected_shape <- map_data |> 
    dplyr::filter(layer_id == selected_lower)
  
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


