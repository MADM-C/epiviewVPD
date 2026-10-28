make_schools <- function() {
  st_as_sf(
    data.frame(
      school_name = c("Lincoln Elementary", "Roosevelt High"),
      full_vax_pct = c("95.0", "88.5"),
      partial_vax_pct = c("2.0", "4.1"),
      total_enrollment = c(400, 1200),
      contact_info = c("555-0100", ""),
      lng = c(-93.27, -93.25),
      lat = c(44.98, 44.95)
    ),
    coords = c("lng", "lat"), crs = 4326
  )
}

make_daycares <- function() {
  st_as_sf(
    data.frame(
      daycare_name = c("Little Sprouts", "Sunshine Kids"),
      full_vax_pct = c("90.0", "0"),
      total_enroll = c(40, 25),
      lng = c(-93.30, -93.22),
      lat = c(45.00, 44.97)
    ),
    coords = c("lng", "lat"), crs = 4326
  )
}