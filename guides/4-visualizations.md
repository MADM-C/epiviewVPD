# Visualizations Without the Interactive Dashboard

Users can build static maps, charts, and tables in R without opening the
interactive dashboard, and save them as standalone files. This option serves as
a good alternative to the dashboard if the user is only interested in specific
visualizations or lacks the ability to host the dashboard.

## Load data

The following examples use the included artificial data:

```r
library(epiviewVPD)
data <- load_app_data(example_data_dir())
```

See [Use your own data](#use-your-own-data) below for instructions on loading
your own files.

## Build visualizations

Run a visualization function to display its output:

```r
# County coverage map
build_coverage_map(data$counties)

# Map of historical cases
build_cases_map(data$cases, data$counties)

# Map of the schools in one county
build_facility_map(
  schools = data$schools,
  counties = data$counties,
  selected_county = data$counties$county_name[1],
  point_type = "Schools"
)

# Cases by year, statewide
plot_epicurve(data$cases, counties = data$counties)

# Case summary table, statewide
render_cases_gt(data$cases, counties = data$counties)

# School coverage table
build_coverage_table(schools = data$schools, table_type = "school")
```

For function arguments and additional options, use the function’s help page
(e.g. `?build_cases_map`). To list the package’s documented functions, run:

```r
help(package = "epiviewVPD")
```

## Save visualizations

Maps and tables save as HTML files; charts are saved as PNG files. A saved map
also creates a companion folder, such as `coverage-map_files`. Keep the HTML
file and companion folder together so the map displays correctly.

Saving to an existing file produces an error. Add `overwrite = TRUE` to replace
it.

```r
dir.create("outputs", showWarnings = FALSE)

cases_chart <- plot_epicurve(data$cases, counties = data$counties)
save_figure(cases_chart, "outputs/cases.png")

coverage_map <- build_coverage_map(data$counties)
save_map(coverage_map, "outputs/coverage-map.html")

coverage_table <- build_coverage_table(schools = data$schools, table_type = "school")
save_table(coverage_table, "outputs/school-coverage.html")
```

## Use your own data

Use the `app_data` folder and `my_settings.R` file described in [Use your own
data](../README.md#use-your-own-data) in the README. The following code reads the settings and passes the
relevant values to `load_app_data()`:

```r
library(epiviewVPD)
settings <- read_dashboard_settings("my_settings.R")

data <- load_app_data(
  "app_data",
  geography = settings$geography,
  case_data = settings$case_data,
  case_age_groups = settings$case_age_groups,
  suppressed_offset = settings$suppression$blurred_offset,
  redacted_codes = settings$suppression$redacted_codes
)
```

Build visualizations using the loaded data. Add `settings = settings` to map
and chart functions to apply the color and labels from your settings file:

```r
build_coverage_map(data$counties, settings = settings)
plot_epicurve(data$cases, counties = data$counties, settings = settings)
```

## Build additional visualizations

These examples use the full artificial data. To use your own data, load it as
in [Use your own data](#use-your-own-data).

```r
library(epiviewVPD)
data <- load_app_data(example_data_dir("full"))
one_school <- data$schools$school_id[1]

# Grade-level chart and table for one school
grade_level_plot(data$grades, one_school)
grade_level_table(data$grades, one_school)

# Details for one school
build_facility_overview_table(
  paste0("school:", one_school),
  schools = data$schools, facilities = data$facilities,
  counties = data$counties, districts = data$districts
)

# Map with schools and child cares
build_facility_map(
  schools = data$schools, facilities = data$facilities,
  counties = data$counties, districts = data$districts
)

# District coverage map
build_coverage_map(data$districts, boundary = "district")

# Child care coverage table
build_coverage_table(facilities = data$facilities, table_type = "childcare")

# Schools and child care programs below 90% coverage within 5 miles of
# one child care program
center <- data$facilities[data$facilities$facility_id == "247677", ]
location <- sf::st_coordinates(center)[1, ]
nearby <- analyze_facility_proximity(
  data, lat = location[["Y"]], lng = location[["X"]],
  radius_miles = 5, threshold = 90
)
build_proximity_map(
  schools = data$schools, facilities = data$facilities,
  counties = data$counties, healthcare_centers = data$healthcare_centers,
  result = nearby
)
build_proximity_table(nearby$low_vaccine_facilities, searched = TRUE)
```

To save a map as PNG, or a table as PNG or PDF, you also need Chrome and:

```r
install.packages(c("webshot2", "chromote"))
```
