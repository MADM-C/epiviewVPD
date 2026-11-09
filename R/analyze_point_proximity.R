# Runs the proximity analysis for a point and draws the result on the map.
analyze_proximity <- function(lat, lng, popup_title,
                              combined_facilities, healthcare_centers,
                              radius_km, low_vaccine_threshold,
                              values, session) {
  result <- analyze_facility_proximity(combined_facilities(), lat, lng,
                                       radius_km() / 1.609344, low_vaccine_threshold())
  values$clicked_point <- result$center
  values$low_vaccine_facilities_data <- result$low_vaccine_facilities
  add_proximity_result(leaflet::leafletProxy("proximity_map", session), result, popup_title)
  invisible(result)
}
