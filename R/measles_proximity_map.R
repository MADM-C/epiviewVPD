# Function to create the proximity map module
# This function handles the interactive map, combining school and daycare facilities,
# overlaying religious centers, and analyzing nearby low-vaccine facilities.
# Parameters:
#   school_data: reactive expression returning school data
#   daycare_data: reactive expression returning daycare data
#   county_map_data: reactive expression returning county boundary data
#   output: Shiny output object
#   input: Shiny input object
#   session: Shiny session object
# Returns: list of reactive values and functions for use by other modules
# Depends on analyze_proximity.R and map_markers.R being sourced
proximityMapServer <- function(school_data, daycare_data, county_map_data,
                               healthcare_center_data, school_district_data = NULL,
                               output, input, session) {
  # Reactive expression to combine and clean facility data
  # Automatically updates when underlying school or daycare data changes
  combined_facilities <- reactive({
    tryCatch(
      {
        df <- combineSchoolDaycareData(school_data(), daycare_data())
        if (!is.null(df) && nrow(df) > 0 && "geometry" %in% names(df)) {
          coords <- sf::st_coordinates(df$geometry)
          valid <- !is.na(coords[, 1]) & !is.na(coords[, 2])
          df <- df[valid, ]
        }
        df
      },
      error = function(e) {
        warning(paste("Error combining data:", e$message))
        return(NULL)
      }
    )
  })
  
  # Reactive expression for healthcare centers (reference layer only, not included in analysis)
  healthcare_centers <- reactive({
    req(healthcare_center_data())
    healthcare_center_data() %>%
      dplyr::rename(healthcare_name = name) %>%
      dplyr::select(dplyr::any_of(c("healthcare_name", "geometry")))
  })
  
  # Reactive values to store user interactions and analysis results
  values <- reactiveValues(
    clicked_point = NULL, # Stores last clicked map coordinates
    low_vaccine_facilities_data = NULL # Stores facilities below vaccine threshold
  )
  
  # Convert search radius from miles to kilometers
  # Required because distance calculations use metric system
  radius_km <- reactive({
    req(input$radius_miles)
    input$radius_miles * 1.60934
  })
  
  # Get user-selected vaccine threshold percentage
  low_vaccine_threshold <- reactive({
    req(input$vaccine_threshold)
    input$vaccine_threshold
  })
  
  # Update facility dropdown when data changes
  # Only schools and daycares are included in the dropdown (religious/tutoring/healthcare centers excluded)
  observe({
    facilities <- combined_facilities()
    if (!is.null(facilities) && nrow(facilities) > 0) {
      # Clean names
      display_names <- trimws(facilities$facility_name)
      
      # Build choices (IDs = row numbers, labels = names)
      choices <- setNames(seq_len(nrow(facilities)), display_names)
      
      # Remove bad labels
      bad <- is.na(names(choices)) |
        names(choices) == "" |
        toupper(names(choices)) %in% c("NA", "NULL") |
        grepl("^na\\s*-\\s*na$", names(choices), ignore.case = TRUE)
      choices <- choices[!bad]
      
      # Sort alphabetically
      choices <- choices[order(tolower(names(choices)))]
      
      updateSelectizeInput(session, "selected_facility",
                           choices = choices,
                           selected = "",
                           server = TRUE,
                           options = list(
                             placeholder = "Type a School/Child Care name...",
                             maxOptions = length(choices)
                           )
      )
    }
  })
  
  # Handle facility selection from dropdown
  observeEvent(input$selected_facility, {
    if (input$selected_facility != "") {
      facilities <- combined_facilities()
      selected <- facilities[as.numeric(input$selected_facility), ]
      if ("geometry" %in% names(selected)) {
        coords <- sf::st_coordinates(selected$geometry)
        analyze_proximity(
          lat = coords[2],
          lng = coords[1],
          popup_title = paste("Selected:", selected$facility_name),
          combined_facilities = combined_facilities,
          healthcare_centers = healthcare_centers,
          radius_km = radius_km,
          low_vaccine_threshold = low_vaccine_threshold,
          values = values,
          session = session
        )
      }
    }
  })
  
  # Allow User to imput a specific address
  observeEvent(input$search_address_btn, {
    req(input$address_input) # Ensure input is not empty
    
    # Create a progress notification while geocoding
    id <- showNotification("Searching address...", duration = NULL, closeButton = FALSE)
    on.exit(removeNotification(id), add = TRUE)
    
    # Geocode the address using OpenStreetMap (OSM)
    tryCatch(
      {
        geo_result <- tidygeocoder::geo(
          address = input$address_input,
          method = "osm",
          full_results = FALSE
        )
        
        # Check if valid coordinates
        if (!is.null(geo_result) && nrow(geo_result) > 0 && !is.na(geo_result$lat) && !is.na(geo_result$long)) {
          # Extract coordinates
          search_lat <- geo_result$lat
          search_lng <- geo_result$long
          
          # Call existing analysis function
          analyze_proximity(
            lat = search_lat,
            lng = search_lng,
            popup_title = paste0("Address: ", input$address_input),
            combined_facilities = combined_facilities,
            healthcare_centers = healthcare_centers,
            radius_km = radius_km,
            low_vaccine_threshold = low_vaccine_threshold,
            values = values,
            session = session
          )
        } else {
          showNotification("Address not found. Please try being more specific (add city/zip).", type = "error")
        }
      },
      error = function(e) {
        showNotification(paste("Geocoding failed:", e$message), type = "error")
      }
    )
  })
  
  # Render the main leaflet map
  output$proximity_map <- renderLeaflet({
    facilities <- combined_facilities()
    county_data <- county_map_data()
    healthcare <- healthcare_centers()
    
    map <- leaflet(options = leafletOptions(minZoom = 5, maxZoom = 20)) %>%
      setView(lng = -94.5, lat = 46.5, zoom = 6) %>%
      addProviderTiles("Esri.WorldTopoMap")
    
    if (!is.null(county_data)) map <- map %>% addPolygons(data = county_data, color = "black", weight = 1)
    
    map <- map %>% add_facility_markers(facilities)
    
    # Add healthcare centers as a separate layer (green) with only name tooltip
    map <- map %>% add_healthcare_markers(healthcare)
    
    # Add school district boundaries
    if (!is.null(school_district_data)) {
      map <- map %>%
        addPolygons(
          data = school_district_data,
          fill = FALSE,
          color = "#2c7bb6",
          weight = 1.5,
          opacity = 0.8,
          group = "School Districts",
          label = ~PREFNAME,
          labelOptions = labelOptions(direction = "auto", textsize = "12px", opacity = 0.85)
        )
    }
    
    map <- map %>%
      addLayersControl(
        overlayGroups = c("School/Child Care Markers", "Healthcare Centers", "School Districts"),
        options = layersControlOptions(collapsed = FALSE)
      ) %>%
      hideGroup("Healthcare Centers") %>%
      hideGroup("School Districts")
    
    return(map)
  })
  
  # Handle map click events for manual point selection
  observeEvent(input$proximity_map_click, {
    click <- input$proximity_map_click
    analyze_proximity(
      lat = click$lat,
      lng = click$lng,
      popup_title = "Manual Search Point",
      combined_facilities = combined_facilities,
      healthcare_centers = healthcare_centers,
      radius_km = radius_km,
      low_vaccine_threshold = low_vaccine_threshold,
      values = values,
      session = session
    )
  })
  
  # Re-run analysis when search parameters change
  observeEvent(list(input$radius_miles, input$vaccine_threshold), {
    if (!is.null(values$clicked_point)) {
      analyze_proximity(
        lat = values$clicked_point$lat,
        lng = values$clicked_point$lng,
        popup_title = "Manual Search Point",
        combined_facilities = combined_facilities,
        healthcare_centers = healthcare_centers,
        radius_km = radius_km,
        low_vaccine_threshold = low_vaccine_threshold,
        values = values,
        session = session
      )
    }
  })
  
  # Return reactive values and functions for use by other modules
  return(list(
    clicked_point = reactive(values$clicked_point),
    radius_km = radius_km,
    low_vaccine_threshold = low_vaccine_threshold,
    low_vaccine_facilities_data = reactive(values$low_vaccine_facilities_data)
  ))
}