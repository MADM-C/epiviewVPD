# Visualizations without the interactive dashboard

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
dir.create("outputs")

cases_chart <- plot_epicurve(data$cases, counties = data$counties)
save_figure(cases_chart, "outputs/cases.png")

coverage_map <- build_coverage_map(data$counties)
save_map(coverage_map, "outputs/coverage-map.html")

coverage_table <- build_coverage_table(schools = data$schools, table_type = "school")
save_table(coverage_table, "outputs/school-coverage.html")
```

## Use your own data

Use the `app_data` folder and `my_settings.R` file in the [Dashboard
guide](3-own-data.md). The following code reads the settings and passes the
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

For child cares, grade-level, school district, and proximity map
visualizations, see [Build additional visualizations in
R](5-adding-more.md#build-additional-visualizations-in-r) in the Adding more
guide.
