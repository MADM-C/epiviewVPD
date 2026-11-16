# Maps and charts without the dashboard

You can build each map, chart, and table from the dashboard in R, without
opening the dashboard, and save it as a file for a report or a website.

## Load the data

This uses the made-up example. Your own data is covered
[below](#use-your-own-data).

```r
library(epiviewVPD)
data <- load_app_data(example_data_dir())
```

## Build a map, chart, or table

Each one displays when you run it:

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

Run `?build_cases_map` (or any function name) to see its options. To list
every function, run `help(package = "epiviewVPD")`.

## Save to a file

Maps and tables save as web pages (`.html`) that open in any browser. Charts
save as images (`.png`). A saved map also makes a folder next to it (for
example `coverage-map_files`); keep the two together, or the map won't show.
Saving to a file that already exists stops with an error; add
`overwrite = TRUE` to replace it.

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

Use the `app_data` folder and `my_settings.R` file from
[Run the dashboard with your data](3-own-data.md). Copy this as it is. It
reads your settings and passes on the ones that change how your files are
read: your state, withheld-value codes, and age groups.

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

Then build what you need as above. Add `settings = settings` to the map and
chart functions so they use your colors and labels:

```r
build_coverage_map(data$counties, settings = settings)
plot_epicurve(data$cases, counties = data$counties, settings = settings)
```

For child cares, grade-level charts, district maps, and proximity search, see
[Build these visualizations in R](5-adding-more.md#build-these-visualizations-in-r).
