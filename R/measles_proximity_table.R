# Server for the proximity results table.
proximityTableServer <- function(proximity_map_values, output, input) {
  output$low_vaccine_table <- DT::renderDataTable({
    build_proximity_table(proximity_map_values$low_vaccine_facilities_data(),
      searched = !is.null(proximity_map_values$clicked_point()), interactive = TRUE)
  }, server = FALSE)
}