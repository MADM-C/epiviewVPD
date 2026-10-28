# Server function for proximity analysis results table
# This function creates a DataTable displaying facilities that meet proximity and vaccination criteria
# The table updates automatically when map interactions change the analysis results
# Parameters:
#   proximity_map_values: list of reactive values from proximityMapServer containing:
#     - low_vaccine_facilities_data(): reactive returning filtered facility data,
#       including distance_mi (miles from search point) computed by analyze_proximity()
#     - clicked_point(): reactive returning last clicked map coordinates
#   output: Shiny output object for rendering the DataTable
#   input: Shiny input object (currently unused but required for server function signature)
proximityTableServer <- function(proximity_map_values, output, input) {
  output$low_vaccine_table <- renderDataTable(
    {
      facilities_data <- proximity_map_values$low_vaccine_facilities_data()
      clicked_point <- proximity_map_values$clicked_point()
      
      # Filter out religious centers from table data
      if (!is.null(facilities_data) && nrow(facilities_data) > 0) {
        facilities_data <- facilities_data[facilities_data$facility_type %in% c("School", "Daycare"), ]
      }
      
      if (is.null(facilities_data) || nrow(facilities_data) == 0) {
        if (!is.null(clicked_point)) {
          # User has searched but no facilities meet criteria
          empty_df <- data.frame(
            message = "No facilities below threshold found in selected area",
            type = "",
            vaccine_rate = "",
            distance = "",
            enrollment = "",
            stringsAsFactors = FALSE
          )
        } else {
          # User hasn't performed any search yet
          empty_df <- data.frame(
            message = "Click on the map to search for low-vaccine facilities",
            type = "",
            vaccine_rate = "",
            distance = "",
            enrollment = "",
            contact_info = "",
            stringsAsFactors = FALSE
          )
        }
        return(empty_df)
      }
      
      # Format enrollment for display (handle missing values)
      enrollment_text <- ifelse(is.na(facilities_data$enrollment),
                                "Not Available",
                                format(facilities_data$enrollment, big.mark = ",")
      )
      
      # Create result table with standardized column names for internal use
      result_table <- data.frame(
        facility_name = facilities_data$facility_name,
        type = ifelse(facilities_data$facility_type == "Daycare",
                      "Child Care",
                      facilities_data$facility_type),
        vaccine_rate =
          facilities_data |>
          mutate(full_vax_pct = ifelse(full_vax_pct == "0" & partial_vax_pct == "0",
                                       "Not Available",
                                       full_vax_pct)) |>
          select(full_vax_pct),
        distance = facilities_data$distance_mi,
        enrollment = enrollment_text,
        stringsAsFactors = FALSE
        )
      
      return(result_table)
    },
    # DataTable configuration options
    extensions = "Buttons",
    options = list(
      pageLength = 10,
      scrollY = "400px",
      scrollCollapse = TRUE,
      searching = TRUE,
      ordering = TRUE,
      order = list(list(2, "asc")),
      dom = "Bfrtip",
      buttons = list(
        list(extend = "csv", filename = "low_vaccine_facilities"),
        list(extend = "excel", filename = "low_vaccine_facilities"),
        list(extend = "pdf", filename = "low_vaccine_facilities")
      ),
      columnDefs = list(list(
        targets = 3,
        render = JS(
          "function(data, type, row, meta) {",
          "  return (type === 'display' && data != null && data !== '') ?",
          "    data + ' mi' : data;",
          "}"
        )
      ))
    ),
    colnames = c("School/Child Care Name",
                 "Type",
                 "Vaccine Rate",
                 "Distance from Point",
                 "Enrollment"),
    rownames = FALSE,
    server = FALSE
  )
}